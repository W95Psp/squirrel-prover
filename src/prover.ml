module Sv = Vars.Sv

(*------------------ Prover ----------------------------------*)
(** {2 Prover state}
    The term "goal" refers to two things below:

    - A toplevel goal declaration (i.e. a lemma)
      which is represented (with some redundancy) by a [Goal.statement]
      and a [Goal.t] which is the associated sequent that has to be
      proved, i.e. the root of the required proof tree.

    - A sequent that has to be proved (i.e. a node in a proof tree)
      which is represented by a [Goal.t].

    For now we use the adjectives toplevel and inner to distinguish
    the two kinds of goals. *)
type state = {
  goals        : ProverLib.pending_proof list;
  table        : Symbols.table; 
  current_goal : ProverLib.pending_proof option;
  subgoals     : Goal.t list;
  bullets      : Bullets.path;
  prover_mode  : ProverLib.prover_mode;
}

(* GoalMode is always the initial prover_mode *)
let init () : state = 
{ goals         = [];
  table         = TConfig.reset_params Symbols.builtins_table;
  current_goal  = None;
  bullets       = Bullets.empty_path;
  subgoals      = [];
  prover_mode   = GoalMode;
}

let get_table (ps:state) : Symbols.table =
  ps.table

let get_mode (ps:state) : ProverLib.prover_mode =
  ps.prover_mode

let get_subgoals (ps:state) : Goal.t list =
  ps.subgoals

let set_table (ps:state) (table: Symbols.table) : state =
  { ps with table }

let set_param (ps:state) (sp: Config.p_set_param) : state =
  { ps with table = TConfig.set_param sp ps.table }

let add_hint (ps:state) (h: Hint.p_hint) : state =
  let table = 
    match h with
    | Hint.Hint_rewrite id -> 
        ProcessDecl.add_hint_rewrite ps.table id ps.table
    | Hint.Hint_smt     id -> 
        ProcessDecl.add_hint_smt     ps.table id ps.table
  in
  { ps with table; }

let abort (ps:state) : state = 
  { ps with current_goal  = None; 
            bullets       = Bullets.empty_path;
            subgoals      = [];
            prover_mode   = GoalMode;
  }

let is_proof_completed (ps:state) : bool =
  ps.subgoals = [] && Bullets.is_empty ps.bullets

let try_complete_proof (ps:state) : state =
  if is_proof_completed ps then
    { ps with prover_mode = WaitQed }
  else
    { ps with prover_mode = ProofMode}

let complete_proof (ps:state) : state = 
  assert (is_proof_completed ps);

  if ps.current_goal = None then
    Tactics.hard_failure
      (Tactics.Failure "cannot complete proof: no current goal");

  let table = match Utils.oget ps.current_goal with
    | ProofObl _ -> ps.table
    | UnprovedLemma (gc, _) -> Lemma.add_lemma `Lemma gc ps.table
  in
  { ps with current_goal = None;
            bullets = Bullets.empty_path;
            subgoals = [];
            table = table;
            prover_mode = GoalMode
  }

let start_proof (ps:state) (check : [`NoCheck | `Check])
  : (string option * state) = 
  match ps.current_goal, ps.goals with
  | None, pending_proof :: remaining_goals ->
    assert (ps.subgoals = []);

    let goals = remaining_goals in

    let goal = match pending_proof with
      | ProofObl goal
      | UnprovedLemma (_,goal) -> goal
    in
    let current_goal = Some pending_proof in

    let subgoals, bullets, mode = begin 
      match check with
      | `Check -> [goal], Bullets.initial_path, ProverLib.ProofMode
      | `NoCheck -> [], Bullets.empty_path, ProverLib.WaitQed
    end in
      (None, { ps with goals; subgoals; bullets; current_goal;
                            prover_mode = mode })
  | Some _,_ ->
    (Some "Cannot start a new proof (current proof is not done).",
     ps)

  | _, [] ->
    (Some "Cannot start a new proof (no goal remaining to prove).",
     ps)

(*---------------------    Goals handling  -----------------*)(* {↓{ *)
let get_current_goal (ps:state) : ProverLib.pending_proof option = ps.current_goal

let get_current_system (ps:state) : SystemExpr.context option =
  match get_current_goal (ps) with
  | None -> None
  | Some (ProofObl g)
  | Some (UnprovedLemma (_, g)) -> Some (Goal.system g )

let add_new_goal_i (table:Symbols.table) (parsed_goal:Goal.Parsed.t) 
    (ps:state) : state  =
  let name = match parsed_goal.Goal.Parsed.name with
    | None -> ProverLib.unnamed_goal ()
    | Some s -> s
  in
  if Lemma.mem name table then
    ProverLib.error (Location.loc name) 
      "a goal or axiom with this name already exists";

  let parsed_goal = 
    { parsed_goal with Goal.Parsed.name = Some name } in
  let statement,goal = Goal.make table parsed_goal in
  let goals =  ProverLib.UnprovedLemma (statement,goal) :: ps.goals in
  { ps with goals }

let add_new_goal (ps:state)  
    (parsed_goal:Goal.Parsed.t Location.located) : state =
  if ps.goals <> [] then
    ProverLib.error (Location.loc parsed_goal) 
      "cannot add new goal: proof obligations remaining";

  let parsed_goal = Location.unloc parsed_goal in
  add_new_goal_i ps.table parsed_goal ps

let first_goal (ps:state) : ProverLib.pending_proof =
  match ps.goals with
  | [] -> assert false
  | h :: _ -> h

let add_proof_obl (goal : Goal.t) (ps:state) : state = 
  let goals =  ProverLib.ProofObl (goal) :: ps.goals in
  { ps with goals }

let add_decls (st:state) (decls : Decl.declarations) 
  : state * Goal.t list =
  let table, proof_obls = ProcessDecl.declare_list 
      (get_table st) decls in
  let ps : state = List.fold_left (fun ps goal ->
      add_proof_obl goal ps) st proof_obls in
  let ps = set_table ps table in
  { ps with prover_mode = GoalMode }, proof_obls

let get_first_subgoal (ps:state) : Goal.t =
  match ps.current_goal, ps.subgoals with
  | Some _, j :: _ -> j
  | _ -> raise Not_found

let current_goal_name (ps:state) : string option =
  Utils.omap (function 
      | ProverLib.UnprovedLemma (stmt,_) -> stmt.Goal.name
      | ProofObl _ -> "proof obligation" ) ps.current_goal
(* }↑} *)
(*--------------------- Tactics evaluation -----------------*)(* {↓{ *)
(** [eval_tactic_focus tac] applies [tac] to the focused goal. *)
let eval_tactic_focus (tac:ProverTactics.AST.t) (ps:state) : state = 
  match ps.subgoals with
  | [] -> assert false
  | judge :: ejs' ->
    if not (Bullets.tactic_allowed ps.bullets) then
      Tactics.hard_failure (Failure "bullet needed before tactic");
    
    let post_quantum = TConfig.post_quantum (ps.table) in
    let new_j = ProverTactics.AST.eval_judgment post_quantum tac judge in
    begin
      try
        let bullets = Bullets.expand_goal (List.length new_j)
            ps.bullets  in
        {
          ps with subgoals = new_j @ ejs'; bullets = bullets
        }
      with Bullets.Error _ -> Tactics.(hard_failure (Failure "bullet error"))
    end

let cycle i_l l =
  let i, loc = Location.unloc i_l, Location.loc i_l in
  let rec cyc acc i = function
    | [] -> Tactics.hard_failure ~loc (Tactics.Failure "cycle error")
    | a :: l ->
      if i = 1 then l @ (List.rev (a :: acc))
      else cyc (a :: acc) (i - 1) l in
  if i = 0 then l else
  if i < 0 then cyc [] (List.length l + i) l
  else cyc [] i l

let eval_tactic (utac:TacticsArgs.parser_arg Tactics.ast) (ps:state) : state = 
  match utac with
  | Tactics.Abstract (Location.{ pl_desc = "cycle"}, [TacticsArgs.Int_parsed i]) ->
    (* TODO do something more for bullets?
       Cycling the list of subgoals does not change its length so
       nothing will break (fail) wrt bullets, but the result will
       be meaningless: we may want to warn the user, forbid cycles
       accross opened bullets, or even update the Bullets.path to
       reflect cycles. *)
    { ps with subgoals = cycle i ps.subgoals }
  | _ -> eval_tactic_focus utac ps
(* }↑} *)
(*----------------------- Bullets --------------------------*)(* {↓{ *)
(** Insert a bullet in the proof script. *)
let open_bullet (ps:state) (bullet : string) : state =
  assert (bullet <> "");
  try { ps with bullets = Bullets.open_bullet bullet ps.bullets } with
  | Bullets.Error _ -> Tactics.(hard_failure (Failure "invalid bullet"))

let invalid_brace () =
  Tactics.hard_failure (Failure "invalid brace")

(** Open a brace in the proof script. *)
let open_brace (ps:state) : state =
  try { ps with bullets = Bullets.open_brace ps.bullets } with
  | Bullets.Error _ -> invalid_brace ()

(** Close a brace in the proof script. *)
let close_brace (ps:state) : state =
  try { ps with bullets = Bullets.close_brace ps.bullets } with
  | Bullets.Error _ -> invalid_brace ()

let tactic_handle (ps:state) = function
 | ProverLib.Bullet bl    -> open_bullet ps bl
 | ProverLib.Brace `Open  -> open_brace ps
 | ProverLib.Brace `Close -> close_brace ps
 | ProverLib.BTactic utac  -> eval_tactic utac ps
(* }↑} *)
(*--------------------- Printings         ------------------*)(* {↓{ *)
let pp_goal (ps:state) ppf () = match ps.current_goal, ps.subgoals with
  | None,[] -> assert false
  | Some _, [] -> Fmt.pf ppf "@[<v 0>[goal> No subgoals remaining.@]@."
  | Some _, j :: _ ->
    Fmt.pf ppf "@[<v 0>[goal> Focused goal (1/%d):@;%a@;@]@."
      (List.length ps.subgoals)
      Goal.pp j
  | _ -> assert false

let pp_subgoals (ps:state) ppf () = match ps.current_goal, ps.subgoals with
  | None,[] -> assert false
  | Some _, [] -> Fmt.pf ppf "@[<v 0>[goal> No subgoals remaining.@]@."
  | Some _, subgoals ->
    List.iteri (fun i sg -> 
    Fmt.pf ppf "@[<v 0>[goal> (%d/%d):@;%a@;@]@." 
      (i+1) 
      (List.length subgoals) 
      Goal.pp sg
    ) subgoals
  | _ -> assert false

let search_about (st:state) (q:ProverLib.search_query) : 
  (Lemma.lemma * Equiv.any_form list) list =
  let env = 
    begin match st.prover_mode with
    | ProofMode -> 
      let goal = match get_current_goal st with
        | None -> assert false
        | Some (ProofObl g)
        | Some (UnprovedLemma (_, g)) -> g
      in
      begin match goal with
        | Trace j -> LowTraceSequent.env j
        | Equiv j -> LowEquivSequent.env j
      end
    | _ -> 
      begin match q with 
      | ProverLib.Srch_inSys (_,sysexpr) ->
          let set = SystemExpr.Parse.parse 
                            (get_table st) sysexpr in
          let system: SystemExpr.context option = 
            Some ({ set  = set;
                    pair = Some (SystemExpr.to_pair set)
                  }) in
          Env.init ~table:st.table ?system () 
      | _ -> Env.init ~table:st.table ()
      end
    end
  in
  Printer.prt `Default "@[<2>Search in context system@ [@[%a@]].@]@."
    SystemExpr.pp env.system.set;
  let t = match q with
    | ProverLib.Srch_inSys (t,_)
    | ProverLib.Srch_term t -> t in
  let cntxt = Theory.{ env; cntxt = InGoal; } in
  let ty_env = Type.Infer.mk_env () in

  let find (t:Term.term) =
    let pat_vars =
      Vars.Tag.local_vars ~const:true (Sv.elements (Vars.Sv.filter Vars.is_pat (Term.fv t)))
    in
    let pat = Term.{
        pat_tyvars = [];
        pat_vars;
        pat_term = t; } 
    in
    Symbols.Lemma.fold begin fun _ _ data acc -> 
        let g = Lemma.as_lemma data in
        let sys = g.stmt.system in 
        let res = begin match g.stmt.formula with
        | Global f -> Match.E.find st.table sys pat f
        | Local  f -> Match.T.find st.table sys pat f
        end in
        begin match res with
          | [] -> acc
          | _ -> 
            let any_res = 
              List.map (fun x -> Equiv.Local x) res in
            (g,any_res)::acc
        end
    end [] st.table in

  match t with
  | Local p -> 
    let t = fst (Theory.convert ~ty_env ~pat:true cntxt p) in
    find t
  | Global f ->
    let t = Theory.convert_global_formula ~ty_env ~pat:true cntxt f in
    let pat_vars =
      Vars.Tag.local_vars ~const:true (Sv.elements (Sv.filter Vars.is_pat (Equiv.fv t)))
    in
    let pat = Term.{
        pat_tyvars = [];
        pat_vars;
        pat_term = t; } in 
    Symbols.Lemma.fold (fun _ _ data acc -> 
        let g = Lemma.as_lemma data in
        let sys = g.stmt.system in 
        let res = begin match g.stmt.formula with
        | Global f -> Match.E.find_glob st.table sys pat f
        | Local  _ -> [] (* can't find Equiv.form in
                                      Term.term ? *)
        end in
        begin match res with
        | [] -> acc
        | _ ->
          let any_res = 
            List.map (fun x -> Equiv.Global x) res in
          (g,any_res)::acc
        end
      ) [] st.table

let do_search (st:state) (t:ProverLib.search_query) : unit =
  let matches = search_about st t in
  Printer.prt `Default "Search result(s):@.@.";
  let print_all fmt matches =
  List.iter (fun (lemma,_:Lemma.lemma * Equiv.any_form list) -> 
        Fmt.pf fmt "%a@.@."
          Lemma.pp lemma
    ) matches in
  Printer.prt `Default "%a" print_all matches

let do_print (st:state) (q:ProverLib.print_query) : unit =
    begin match q with
    | Pr_statement l -> 
        let lem = Lemma.find l (get_table st) in
        Printer.prt `Default "%a" Lemma.pp lem
    | Pr_system s_opt ->
        let system = 
          begin match s_opt with
          | None   -> 
            begin match get_current_system st with
              | Some s -> s.set
              | None -> Tactics.hard_failure 
                          (Failure "no default system");
            end
          | Some s -> SystemExpr.Parse.parse 
                        (get_table st) s
          end
        in
        SystemExpr.print_system 
          (get_table st) system;

        if TConfig.print_trs_equations 
            (get_table st)
        then
          Printer.prt `Result "@[<v>@;%a@;@]%!"
            Completion.print_init_trs 
              (get_table st)
    end
  (* }↑} *)

let do_eof (st:state) : state = 
    { st with prover_mode = AllDone }

let get_prover_command = function
  | ProverLib.Prover c -> c
  | _ -> assert false

let command_from_string (st:state) (s:string) = 
  if st.prover_mode = ProverLib.ProofMode 
  then
    Parser.top_proofmode Lexer.token (Lexing.from_string s)
  else
    Parser.interactive Lexer.token (Lexing.from_string s)

(* Command handlers *)(* {↓{ *)
let rec do_command (state:state) (command:ProverLib.prover_input) : state =
  match command with
  | InputDescr decls -> fst (add_decls state decls)
  | Tactic l         -> List.fold_left tactic_handle state l
  | Print q          -> do_print state q; state
  | Search t         -> do_search state t; state
  | Qed              -> complete_proof state
  | Hint h           -> add_hint state h
  | SetOption sp     -> set_param state sp
  | Goal g           -> add_new_goal state g
  | Proof            -> snd (start_proof state `Check)
  | Abort            -> abort state
  | Include i        -> do_include state i
  | EOF              -> do_eof state
and do_include (st:state) (i: ProverLib.include_param) : state =
  (* `Stdin will add cwd in path with theories *)
  let load_paths = Driver.mk_load_paths ~main_mode:`Stdin () in
  let file = Driver.locate load_paths (Location.unloc i.th_name) in
  do_all_commands_in st file
and do_all_commands_in (st:state) (file:Driver.file) : state =
  match Driver.next_input ~test:false file st.prover_mode with
  | ProverLib.Prover EOF -> do_eof st
  | cmd -> do_all_commands_in 
             (do_command st (get_prover_command cmd)) file
and exec_command (s:string) (st:state) : state  = 
  let input = command_from_string st s in
  do_command st (get_prover_command input)
and exec_all (st:state) (s:string) = 
  let commands = List.filter 
      (function | "" -> false | _ -> true) 
      (String.split_on_char '.' s) in
  List.fold_left (fun st s -> 
      exec_command (s^".") st) st commands
(* }↑} *)
