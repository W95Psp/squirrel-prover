(** State in proof mode.
  * TODO goals do not belong here *)

module Goal = struct
  type t = Trace of TraceSequent.t | Equiv of EquivSequent.t
  let get_env = function
    | Trace j -> TraceSequent.get_env j
    | Equiv j -> EquivSequent.get_env j
  let pp ch = function
    | Trace j -> TraceSequent.pp ch j
    | Equiv j -> EquivSequent.pp ch j
  let pp_init ch = function
    | Trace j ->
        assert (TraceSequent.get_env j = Vars.empty_env) ;
        Term.pp ch (TraceSequent.get_conclusion j)
    | Equiv j -> EquivSequent.pp_init ch j
end

type named_goal = string * Goal.t

let goals : named_goal list ref = ref []
let current_goal : named_goal option ref = ref None
let subgoals : Goal.t list ref = ref []
let goals_proved = ref []

type prover_mode = InputDescr | GoalMode | ProofMode | WaitQed

type gm_input =
  | Gm_goal of string * Goal.t
  | Gm_proof



type option_name =
  | Oracle_for_symbol of string

type option_val =
  | Oracle_formula of Term.formula

type option_def = option_name * option_val

let option_defs : option_def list ref= ref []

type proof_state = { goals : named_goal list;
                     current_goal : named_goal option;
                     subgoals : Goal.t list;
                     goals_proved : named_goal list;
                     option_defs : option_def list;
                     prover_mode : prover_mode;
                   }

let proof_states_history : proof_state list ref = ref []

let reset () =
    proof_states_history := [];
    goals := [];
    current_goal := None;
    subgoals := [];
    goals_proved := [];
    option_defs := []

let save_state mode =
  proof_states_history :=
    {goals = !goals;
     current_goal = !current_goal;
     subgoals = !subgoals;
     goals_proved = !goals_proved;
     option_defs = !option_defs;
     prover_mode = mode} :: (!proof_states_history)

let rec reset_state n =
  match (!proof_states_history,n) with
  | [],_ -> InputDescr
  | p::q,0 ->
    proof_states_history := q;
    goals := p.goals;
    current_goal := p.current_goal;
    subgoals := p.subgoals;
    goals_proved := p.goals_proved;
    option_defs := p.option_defs;
    p.prover_mode
  | _::q, n -> proof_states_history := q; reset_state (n-1)


(** Options Management **)

exception Option_already_defined

let get_option opt_name =
  try Some (List.assoc opt_name !option_defs)
  with Not_found -> None

let add_option ((opt_name,opt_val):option_def) =
  if List.mem_assoc opt_name !option_defs then
    raise Option_already_defined
  else
    option_defs := (opt_name,opt_val) :: (!option_defs)

(** Tactic expressions and their evaluation *)

let tsubst_of_goal j =
  let aux : Vars.evar -> Theory.esubst =
    (fun (Vars.EVar v) ->
       match Vars.sort v with
       | Sorts.Boolean -> assert false
       | _ -> Theory.ESubst (Vars.name v,Term.Var v)
      )
      in
  List.map aux
    (Vars.to_list (Goal.get_env j))

exception ParseError of string

let parse_formula fact =
  match !subgoals with
    | [] -> raise @@ ParseError "Cannot parse fact without a goal"
    | j :: _ ->
        Theory.convert
          (tsubst_of_goal j)
          fact
          Sorts.Boolean


type 'a tac_infos = {
  maker : TacticsArgs.parser_arg list -> 'a Tactics.tac ;
  help : string
}

type 'a table = (string, 'a tac_infos) Hashtbl.t

(** Basic tactic tables, without registration *)

module type Table_sig = sig
  type judgment
  val table : judgment table
  val get : string -> TacticsArgs.parser_arg list -> judgment Tactics.tac
  val to_goal : judgment -> Goal.t
  val from_trace : TraceSequent.t -> judgment
  val from_equiv : Goal.t -> judgment
end

module TraceTable : Table_sig with type judgment = TraceSequent.t = struct
  type judgment = TraceSequent.t
  let table = Hashtbl.create 97
  let get id =
    try (Hashtbl.find table id).maker with
      | Not_found -> raise @@ Tactics.Tactic_hard_failure
             (Tactics.Failure (Printf.sprintf "unknown tactic %S" id))
  let to_goal j = Goal.Trace j
  let from_trace j = j
  let from_equiv e = assert false
end

module EquivTable : Table_sig with type judgment = Goal.t = struct
  type judgment = Goal.t
  let table = Hashtbl.create 97
  let get id =
    try (Hashtbl.find table id).maker with
      | Not_found -> raise @@ Tactics.Tactic_hard_failure
             (Tactics.Failure (Printf.sprintf "unknown tactic %S" id))
  let to_goal j = j
  let from_trace j = Goal.Trace j
  let from_equiv j = j
end

(** Functor building AST evaluators for our judgment types. *)
module Make_AST (T : Table_sig) :
  (Tactics.AST_sig with type arg = TacticsArgs.parser_arg with type judgment = T.judgment)
= Tactics.AST(struct

  type arg = TacticsArgs.parser_arg

  type judgment = T.judgment

  let pp_arg ppf = function
    | TacticsArgs.Int_parsed i -> Fmt.int ppf i
    | TacticsArgs.String_name s -> Fmt.string ppf s
    | TacticsArgs.Theory th -> Theory.pp ppf th

  let simpl () =
    let tsimpl = TraceTable.get "simpl" [] in
    let esimpl = EquivTable.get "simpl" [] in
      fun s sk fk ->
        match T.to_goal s with
          | Goal.Trace t ->
              let sk l fk = sk (List.map T.from_trace l) fk in
              tsimpl t sk fk
          | Goal.Equiv e ->
              let sk l fk = sk (List.map T.from_equiv l) fk in
              esimpl (Goal.Equiv e) sk fk

  let simpl = Lazy.from_fun simpl

  let eval_abstract mods id args : judgment Tactics.tac =
    match mods with
      | "nosimpl"::_ -> T.get id args
      | [] -> Tactics.andthen (T.get id args) (Lazy.force simpl)
      | _ -> assert false

  let pp_abstract ~pp_args s args ppf =
    match s,args with
      | "apply",[TacticsArgs.String_name id] ->
          Fmt.pf ppf "apply %s" id
      | "apply", TacticsArgs.String_name id :: l ->
          let l = List.map (function TacticsArgs.Theory t -> t | _ -> assert false) l in
          Fmt.pf ppf "apply %s to %a" id (Utils.pp_list Theory.pp) l
      | _ -> raise Not_found

end)

module TraceAST = Make_AST(TraceTable)

module EquivAST = Make_AST(EquivTable)

(** Signature for tactic table with registration capabilities.
  * Registering macros relies on previous AST modules,
  * hence the definition in multiple steps. *)
module type Tactics_sig = sig

  type judgment

  type tac = judgment Tactics.tac

  val register_general :
    string -> ?help:string -> (TacticsArgs.parser_arg list -> tac) -> unit

  val register_macro :
    string -> ?modifiers:string list -> ?help:string ->
    TacticsArgs.parser_arg Tactics.ast -> unit


  val register : string -> ?help:string -> (judgment -> judgment list) -> unit

  val register_typed : string -> ?help:string ->
    ('a TacticsArgs.arg -> judgment -> judgment list) ->
    'a TacticsArgs.sort  -> unit

  val register_orelse :
    string -> ?help:string -> string list -> unit

  val get : string -> TacticsArgs.parser_arg list -> tac

  val pp : Format.formatter -> string -> unit
  val pps : Format.formatter -> unit -> unit

end

module Prover_tactics
  (M : Table_sig)
  (AST : Tactics.AST_sig
           with type judgment = M.judgment
           with type arg = TacticsArgs.parser_arg) :
  Tactics_sig with type judgment = M.judgment =
struct

  include M

  type tac = judgment Tactics.tac

  let register_general id ?(help="") f =
    assert (not (Hashtbl.mem table id)) ;
    Hashtbl.add table id { maker = f ; help = help}

  let rec convert_argsb parser_args tactic_typess j =
    let env =
      match M.to_goal j with
      | Goal.Trace t -> TraceSequent.get_env t
      | Goal.Equiv e -> EquivSequent.get_env e
    in
    let tsubst = Theory.subst_of_env env in
    let open TacticsArgs in
    match parser_args, tactic_typess with
    | (Theory p::q, Sort Timestamp :: s) ->
      let aux = convert_argsb q s j in
      Arg (Timestamp (Theory.convert tsubst p Sorts.Timestamp)) :: aux
    | (Theory p::q, Sort Message :: s) ->
      let aux = convert_argsb q s j in
      Arg (Message (Theory.convert tsubst p Sorts.Message)) :: aux
    | (Theory p::q, Sort Boolean :: s) ->
      let aux = convert_argsb q s j in
      Arg (Boolean (Theory.convert tsubst p Sorts.Boolean)) :: aux
    | (Theory (Var p)::q, Sort String :: s) ->
      let aux = convert_argsb q s j in
      Arg (String p) :: aux
    | (Theory t::q, Sort String :: s) -> raise Theory.(Conv (String_expected t))
    | (Theory (Var p)::q, Sort Index :: s) ->
      let aux = convert_argsb q s j in
      Arg (Index (Theory.conv_index tsubst (Var p))) :: aux
    | [], [] -> []
    | _ -> failwith "not implemented"



  let rec convert_args parser_args tactic_type j =
    let env =
      match M.to_goal j with
      | Goal.Trace t -> TraceSequent.get_env t
      | Goal.Equiv e -> EquivSequent.get_env e
    in
    let tsubst = Theory.subst_of_env env in
    let open TacticsArgs in
    match parser_args, tactic_type with
    | [Theory p], Sort Timestamp ->
      Arg (Timestamp (Theory.convert tsubst p Sorts.Timestamp))
    | [Theory p], Sort Message ->
      Arg (Message (Theory.convert tsubst p Sorts.Message))
    | [Theory p], Sort Boolean ->
      Arg (Boolean (Theory.convert tsubst p Sorts.Boolean))
    | [Theory (Var p)], Sort String ->
      Arg (String p)
    | [Int_parsed i], Sort Int ->
      Arg (Int i)
    | [Theory t], Sort String -> raise Theory.(Conv (String_expected t))
    | [Theory t], Sort Int -> raise Theory.(Conv (Int_expected t))
    | [Theory (Var p)], Sort Index ->
      Arg (Index (Theory.conv_index tsubst (Var p)))
    | [th1], Sort (Pair (s1, Opt s2)) ->
      let Arg arg1 = convert_args [th1] (Sort s1) j in
      let Arg arg2 = convert_args [] (Sort (Opt s2)) j in
      Arg (Pair (arg1, arg2))
    | [th1], Sort (Pair (Opt s1, s2)) ->
      let Arg arg1 = convert_args [] (Sort (Opt s1)) j in
      let Arg arg2 = convert_args [th1] (Sort (s2)) j in
      Arg (Pair (arg1, arg2))
    | th1::q, Sort (Pair (s1, s2)) ->
      let Arg arg1 = convert_args [th1] (Sort s1) j in
      let Arg arg2 = convert_args q (Sort s2) j in
      Arg (Pair (arg1, arg2))
    | [], Sort (Opt a) ->
      Arg (Opt (a, None))
    | [th], Sort (Opt a) ->
      let Arg arg = convert_args [th] (Sort a) j in
      Arg (Opt
             (a,
              (Some (cast a arg))
             )
          )
    | [], _ -> raise Theory.(Conv (Tactic_type "more arguments expected"))
    | p, _ -> raise Theory.(Conv (Tactic_type "too many arguments"))


  let register id ?(help="") f =
    register_general id ~help:help
      (function
        | [] ->
          fun s sk fk -> begin match f s with
              | subgoals -> sk subgoals fk
              | exception Tactics.Tactic_soft_failure e -> fk e
            end
        | _ -> Tactics.hard_failure (Tactics.Failure "no argument allowed"))

  let register_typed id  ?(help="") f sort =
    register_general id ~help:help
      (fun args s sk fk ->
         match convert_args args (TacticsArgs.Sort sort) s with
         | TacticsArgs.Arg (th)  ->
           begin
             try
               let th = TacticsArgs.cast sort th in
               begin
                 match f (th) s with
                 | subgoals -> sk subgoals fk
                 | exception Tactics.Tactic_soft_failure e -> fk e
               end
             with TacticsArgs.Uncastable ->
               Tactics.hard_failure (Tactics.Failure "ill-formed arguments")
           end
         | exception Theory.(Conv e) -> fk (Tactics.Cannot_convert e)
      )

  let register_orelse id ?(help="") ids =
    register_general id
      ~help:help
      (fun args s sk fk -> AST.eval ["nosimpl"]
          (Tactics.OrElse
             (List.map (fun id -> Tactics.Abstract (id,args) ) ids)
          )
          s sk fk)

  let register_formula id ?(help="") f =
    register_general id ~help:help
      (fun args j sk fk -> match args with
         | [Theory x] ->
           begin match parse_formula x with
             | x -> f x j sk fk
             | exception Theory.Conv e ->
               fk (Tactics.Cannot_convert e)
           end
         | _ ->
           raise @@ Tactics.Tactic_hard_failure
             (Tactics.Failure "formula argument expected"))

  let register_macro id ?(modifiers=["nosimpl"]) ?(help="") m =
    register_general id ~help:help
      (fun args s sk fk ->
         if args = [] then AST.eval modifiers m s sk fk else
           raise @@ Tactics.Tactic_hard_failure
             (Tactics.Failure "this tactic does not take arguments"))

  let pp fmt id =
    let help_text =
      try (Hashtbl.find table id).help with
      | Not_found -> raise @@ Tactics.Tactic_hard_failure
          (Tactics.Failure (Printf.sprintf "unknown tactic %S" id))
    in
    Fmt.pf fmt  "@.@[<v 0>- %a - @[ %s @]@]@."
      Fmt.(styled `Bold (styled `Magenta Utils.ident))
      id help_text

  let pps fmt () =
    let helps =
      Hashtbl.fold (fun name tac acc -> (name, tac.help)::acc) table []
      |> List.sort (fun (n1,_) (n2,_) -> compare n1 n2)
    in
    List.iter (fun (name, help) ->
        if help <> "" then
          Fmt.pf fmt "@.@[<v 0>- %a - @[ %s @]@]@."
            Fmt.(styled `Bold (styled `Magenta Utils.ident))
            name
            help) helps

end

module rec TraceTactics : Tactics_sig with type judgment = TraceSequent.t =
  Prover_tactics(TraceTable)(TraceAST)

module rec EquivTactics : Tactics_sig with type judgment = Goal.t =
  Prover_tactics(EquivTable)(EquivAST)

let pp_ast fmt t = TraceAST.pp fmt t

let get_trace_help tac_name =
  if tac_name = "" then
    Printer.prt `Result "%a" TraceTactics.pps ()
  else
    Printer.prt `Result "%a." TraceTactics.pp tac_name;
  Tactics.id

let get_equiv_help tac_name =
  if tac_name = "" then
    Printer.prt `Result "%a" EquivTactics.pps ()
  else
    Printer.prt `Result "%a." EquivTactics.pp tac_name;
  Tactics.id

let () =

  TraceTactics.register_general "admit"
    ~help:"Closes the current goal.\
           \n Usage: admit."
    (fun _ _ sk fk -> sk [] fk) ;

  TraceTactics.register_general "help"
    ~help:"Display all available commands.\n Usage: help."
    (function
      | [] -> get_trace_help ""
      | [String_name tac_name]-> get_trace_help tac_name
      | _ ->  raise @@ Tactics.Tactic_hard_failure
          (Tactics.Failure"improper arguments")) ;

  EquivTactics.register_general "help"
    ~help:"Display all available commands.\n Usage: help."
    (function
      | [] -> get_equiv_help ""
      | [String_name tac_name]-> get_equiv_help tac_name
      | _ ->  raise @@ Tactics.Tactic_hard_failure
          (Tactics.Failure"improper arguments")) ;

  TraceTactics.register_general "id" ~help:"Identity.\n Usage: identity." (fun _ -> Tactics.id)

let get_goal_formula gname =
  match
    List.filter (fun (name,_) -> name = gname) !goals_proved
  with
    | [(_,Goal.Trace f)] ->
        assert (TraceSequent.get_env f = Vars.empty_env) ;
        TraceSequent.get_conclusion f, TraceSequent.system f
    | [] -> raise @@ Tactics.Tactic_hard_failure
        (Tactics.Failure "No proved goal with given name")
    | _ -> assert false

(** Declare Goals And Proofs *)

let make_trace_goal ~system f  =
  Goal.Trace (TraceSequent.init ~system (Theory.convert [] f Sorts.Boolean))

let make_equiv_goal env (l : [`Message of 'a | `Formula of 'b] list) =
  let env =
    List.fold_left
      (fun env (x, Sorts.ESort s) ->
         assert (not (Vars.mem env x)) ;
         fst (Vars.make_fresh env s x))
      Vars.empty_env env
  in
  let subst = Theory.subst_of_env env in
  let convert = function
    | `Formula f ->
        EquivSequent.Formula (Theory.convert subst f Sorts.Boolean)
    | `Message m ->
        EquivSequent.Message (Theory.convert subst m Sorts.Message)
  in
  Goal.Equiv (EquivSequent.init Action.(SimplePair default_system_name)
                env (List.map convert l))


let make_equiv_goal_process system_1 system_2 =
  let env = ref Vars.empty_env in
  let ts = Vars.make_fresh_and_update env Sorts.Timestamp "t" in
  let term = Term.Macro(Term.frame_macro,[],Term.Var ts) in
  let system =
    match system_1, system_2 with
    | Action.Left id1, Action.Right id2 when id1 = id2 ->
      Action.SimplePair id1
    | _ -> Action.Pair (system_1, system_2)
  in
  Goal.Equiv (EquivSequent.init system !env [(EquivSequent.Message term)])

type parsed_input =
  | ParsedInputDescr
  | ParsedQed
  | ParsedTactic of TacticsArgs.parser_arg Tactics.ast
  | ParsedUndo of int
  | ParsedGoal of gm_input
  | EOF

let add_new_goal g = goals := g :: !goals

let unnamed_goal () = "unnamedgoal"^(string_of_int (List.length (!goals_proved)))

let add_proved_goal (gname,j) =
  if List.exists (fun (name,_) -> name = gname) !goals_proved then
    raise @@ ParseError "A formula with this name alread exists"
  else
    goals_proved := (gname,j) :: !goals_proved

let define_oracle_tag_formula h f =
  let formula = Theory.convert [] f Sorts.Boolean in
    (match formula with
     |  Term.ForAll ([Vars.EVar uvarm;Vars.EVar uvarkey],f) ->
       (
         match Vars.sort uvarm,Vars.sort uvarkey with
         | Sorts.(Message, Message) ->
           add_option (Oracle_for_symbol h, Oracle_formula formula)
         | _ ->  raise @@ ParseError "The tag formula must be of \
                           the form forall (m:message,sk:message)"
       )
     | _ ->  raise @@ ParseError "The tag formula must be of \
                           the form forall (m:message,sk:message)"
    )


let get_oracle_tag_formula h =
  match get_option (Oracle_for_symbol h) with
  | Some (Oracle_formula f) -> f
  | None -> Term.False

let is_proof_completed () = !subgoals = []

let complete_proof () =
  assert (is_proof_completed ());
  try
    add_proved_goal (Utils.opt_get !current_goal);
    current_goal := None;
    subgoals := []
  with Not_found ->
    raise @@ Tactics.Tactic_hard_failure
      (Tactics.Failure "Cannot complete proof \
               with empty current goal")

let pp_goal ppf () = match !current_goal, !subgoals with
  | None,[] -> assert false
  | Some _, [] -> Fmt.pf ppf "@[<v 0>[goal> No subgoals remaining.@]@."
  | Some _, j :: _ ->
    Fmt.pf ppf "@[<v 0>[goal> Focused goal (1/%d):@;%a@;@]@."
      (List.length !subgoals)
      Goal.pp j
  | _ -> assert false

(** [eval_tactic_focus tac] applies [tac] to the focused goal.
  * @return [true] if there are no subgoals remaining. *)
let eval_tactic_focus tac = match !subgoals with
  | [] -> assert false
  | Goal.Trace judge :: ejs' ->
    let new_j = TraceAST.eval_judgment tac judge in
    subgoals := List.map (fun j -> Goal.Trace j) new_j @ ejs';
    is_proof_completed ()
  | Goal.Equiv judge :: ejs' ->
    let new_j = EquivAST.eval_judgment tac (Goal.Equiv judge) in
    subgoals := new_j @ ejs';
    is_proof_completed ()

let cycle i l =
  let rec cyc acc i = function
    | [] -> raise @@ Tactics.Tactic_hard_failure
        (Tactics.Failure "Cycle error.")
    | a :: l ->
      if i = 1 then l @ (List.rev (a :: acc))
      else cyc (a :: acc) (i - 1) l in
  if i = 0 then l else
  if i < 0 then cyc [] (List.length l + i) l
  else cyc [] i l

let eval_tactic utac = match utac with
  | Tactics.Abstract ("cycle",[TacticsArgs.Int_parsed i]) -> subgoals := cycle i !subgoals; false
  | _ -> eval_tactic_focus utac

let start_proof () = match !current_goal, !goals with
  | None, (gname,goal) :: _ ->
    assert (!subgoals = []);
    current_goal := Some (gname,goal);
    subgoals := [goal];
    None
  | Some _,_ ->
    Some "Cannot start a new proof (current proof is not done)."

  | _, [] ->
    Some "Cannot start a new proof (no goal remaining to prove)."

let current_goal () = !current_goal
