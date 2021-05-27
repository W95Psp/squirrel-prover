module L = Location

type lsymb = string L.located

(*------------------------------------------------------------------*)
type tac_error_i =
  | More
  | Failure of string
  | CannotConvert
  | NotEqualArguments
  | Bad_SSC
  | NoSSC
  | NoAssumpSystem
  | NotDepends of string * string
  | NotDDHContext
  | SEncNoRandom
  | SEncSharedRandom
  | SEncRandomNotFresh
  | NameNotUnderEnc
  | NoRefl
  | NoReflMacros
  | TacTimeout
  | DidNotFail
  | FailWithUnexpected of tac_error_i
  | GoalBadShape of string

  (* TODO: remove these errors, catch directly at top-level *)
  | SystemError     of System.system_error
  | SystemExprError of SystemExpr.system_expr_err

  | CongrFail
  | GoalNotClosed
  | NothingToIntroduce
  | NothingToRewrite
  | BadRewriteRule
  | MustHappen of Term.timestamp
  | NotHypothesis

  | ApplyMatchFailure
  | ApplyBadInst

  | NoCollision

  | HypAlreadyExists of string
  | HypUnknown of string

  | InvalidVarName

  | PatNumError of int * int    (* given, need *)

type tac_error = L.t option * tac_error_i

let tac_error_strings =
  [ (More               , "More");
    (NotEqualArguments  , "NotEqualArguments");
    (Bad_SSC            , "BadSSC");
    (NoSSC              , "NoSSC");
    (NoAssumpSystem     , "NoAssumpSystem");
    (NotDDHContext      , "NotDDHContext");
    (SEncNoRandom       , "SEncNoRandom");
    (CongrFail          , "CongrFail");
    (SEncSharedRandom   , "SEncSharedRandom");
    (SEncRandomNotFresh , "SEncRandomNotFresh");
    (NameNotUnderEnc    , "NameNotUnderEnc");
    (NoRefl             , "NoRefl");
    (NoReflMacros       , "NoReflMacros");
    (TacTimeout         , "TacTimeout");
    (CannotConvert      , "CannotConvert");
    (NotHypothesis      , "NotHypothesis");
    (NoCollision        , "NoCollision");
    (GoalNotClosed      , "GoalNotClosed");
    (DidNotFail         , "DidNotFail");
    (NothingToIntroduce , "NothingToIntroduce");
    (NothingToRewrite   , "NothingToRewrite");
    (BadRewriteRule     , "BadRewriteRule");
    (InvalidVarName     , "InvalidVarName");
    (ApplyMatchFailure  , "ApplyMatchFailure");
    (ApplyBadInst       , "ApplyBadInst") ]

let rec tac_error_to_string = function
  | Failure s -> Format.sprintf "Failure %S" s
  | NotDepends (s1, s2) -> "NotDepends, "^s1^", "^s2
  | FailWithUnexpected te -> "FailWithUnexpected, "^(tac_error_to_string te)
  | More
  | NotEqualArguments
  | Bad_SSC
  | NoSSC
  | NoAssumpSystem
  | NotDDHContext
  | SEncNoRandom
  | SEncSharedRandom
  | SEncRandomNotFresh
  | NameNotUnderEnc
  | NoRefl
  | NoReflMacros
  | TacTimeout
  | CannotConvert
  | CongrFail
  | NothingToIntroduce
  | NothingToRewrite
  | BadRewriteRule
  | GoalNotClosed
  | NotHypothesis
  | NoCollision
  | ApplyMatchFailure
  | ApplyBadInst
  | InvalidVarName
  | DidNotFail as e -> List.assoc e tac_error_strings
  | HypAlreadyExists _ -> "HypAlreadyExists"
  | HypUnknown       _ -> "HypUnknown"
  | SystemExprError  _ -> "SystemExpr_Error"
  | GoalBadShape     _ -> "GoalBadShape"
  | SystemError      _ -> "System_Error"
  | PatNumError      _ -> "PatNumError"
  | MustHappen       _ -> "MustHappen"

let rec pp_tac_error_i ppf = function
  | More -> Fmt.string ppf "more results required"
  | Failure s -> Fmt.pf ppf "%s" s
  | NotEqualArguments -> Fmt.pf ppf "arguments not equals"
  | Bad_SSC -> Fmt.pf ppf "key does not satisfy the syntactic side condition"

  | NoSSC ->
      Fmt.pf ppf
        "no key which satisfies the syntactic condition has been found"

  | NotDepends (a, b) ->
      Fmt.pf ppf "action %s does not depend on action %s" a b

  | NoAssumpSystem ->
      Fmt.pf ppf "lemma does not apply to the current system"

  | NotDDHContext ->
      Fmt.pf ppf "the current system cannot be seen as a context \
                  of the given DDH shares"

  | SystemExprError e -> SystemExpr.pp_system_expr_err ppf e

  | SystemError e -> System.pp_system_error ppf e

  | SEncNoRandom ->
    Fmt.string ppf "an encryption is performed without a random name"

  | SEncSharedRandom ->
    Fmt.string ppf "two encryptions share the same random"

  | SEncRandomNotFresh ->
    Fmt.string ppf "a random used for an encryption is used elsewhere"

  | NameNotUnderEnc ->
     Fmt.string ppf "the given name does not only occur under encryptions"

  | NoRefl  ->
    Fmt.string ppf "frames not identical"

  | NoReflMacros ->
    Fmt.string ppf "frames contain macros that may not be diff-equivalent"

  | TacTimeout -> Fmt.pf ppf "time-out"

  | DidNotFail -> Fmt.pf ppf "the tactic did not fail"

  | CannotConvert -> Fmt.pf ppf "conversion error"

  | FailWithUnexpected t -> Fmt.pf ppf "the tactic did not fail with the expected \
                                      exception, but failed with: %s"
                            (tac_error_to_string t)

  | GoalNotClosed -> Fmt.pf ppf "cannot close goal"

  | CongrFail -> Fmt.pf ppf "congruence closure failed"

  | NothingToIntroduce ->
    Fmt.pf ppf "nothing to introduce"

  | NothingToRewrite ->
    Fmt.pf ppf "nothing to rewrite"

  | BadRewriteRule ->
    Fmt.pf ppf "invalid rewriting: rhs variables are not all bound by the lhs"

  | GoalBadShape s ->
    Fmt.pf ppf "goal has the wrong shape: %s" s

  | PatNumError (give, need) ->
    Fmt.pf ppf "invalid number of patterns (%d given, %d needed)" give need

  | MustHappen t ->
    Fmt.pf ppf "timestamp %a must happen" Term.pp t

  | NotHypothesis ->
    Fmt.pf ppf "the conclusion does not appear in the hypotheses"

  | HypAlreadyExists s ->
    Fmt.pf ppf "an hypothesis named %s already exists" s

  | HypUnknown s ->
    Fmt.pf ppf "unknown hypothesis %s" s

  | NoCollision ->
    Fmt.pf ppf "no collision found"

  | ApplyMatchFailure ->
    Fmt.pf ppf "apply failed: no match found"

  | ApplyBadInst ->
    Fmt.pf ppf "apply failed: rhs variables are not all bound by the lhs"

  | InvalidVarName -> Fmt.pf ppf "invalid variable name"

let strings_tac_error =
  let (a,b) = List.split tac_error_strings in
  List.combine b a

let rec tac_error_of_strings = function
  | [] -> raise (Failure "exception name expected")
  | ["Failure"] -> Failure ""
  | [s] ->
    (match List.assoc_opt s strings_tac_error with
      | None -> raise (Failure "exception name unknown")
      | Some e -> e
    )
  | ["NotDepends"; s1; s2] -> NotDepends (s1, s2)
  | _ ->  raise (Failure "exception name unknown")

exception Tactic_soft_failure of tac_error

exception Tactic_hard_failure of tac_error

let soft_failure ?loc e = raise (Tactic_soft_failure (loc,e))
let hard_failure ?loc e = raise (Tactic_hard_failure (loc,e))

let () =
  let s_lopt = function
    | None   -> ""
    | Some l -> "at " ^ (L.tostring l)
  in

  Printexc.register_printer
    (function
       | Tactic_hard_failure (l,e) ->
           Some (Format.sprintf "Tactic_hard_failure(%s) at %s"
                   (tac_error_to_string e) (s_lopt l))
       | Tactic_soft_failure (l,e) ->
           Some
             (Format.sprintf "Tactic_soft_failure(%s) at %s"
                (tac_error_to_string e) (s_lopt l))
       | _ -> None)

type a

type fk = tac_error -> a

type 'a sk = 'a -> fk -> a

type 'a tac = 'a -> 'a list sk -> fk -> a

(*------------------------------------------------------------------*)
let run : 'a tac -> 'a -> 'a list = fun tac a ->
  let exception Done in
  let found = ref None in

  let fk _ = assert false in
  let sk res _ = found := Some res; raise Done in

  try ignore (tac a sk fk : a); assert false
  with Done -> Utils.oget !found

(*------------------------------------------------------------------*)
(** Selector for tactic *)
type selector = int list

let check_sel sel_tacs l =
  (* check that there a no selector for non-existing goal *)
  let max_list l = match l with
    | [] -> assert false
    | a :: l -> List.fold_left max a l
  in
  let max_sel =
    List.fold_left (fun m (sel,_) ->
        max m (max_list sel)
      ) 0 sel_tacs in
  if max_sel > List.length l then
    hard_failure (Failure ("no goal " ^ string_of_int max_sel));

  (* check that selectors are disjoint *)
  let all_sel = List.fold_left (fun all (s,_) -> s @ all) [] sel_tacs in
  let _ =
    List.fold_left (fun acc s ->
        if List.mem s acc then
          hard_failure
            (Failure ("selector " ^ string_of_int s ^ " appears twice"));
        s :: acc
      ) [] all_sel in
  ()

(*------------------------------------------------------------------*)
(** Basic Tactics *)

let fail sk (fk : fk) = fk (None, Failure "fail")

let return x sk (fk : fk) = sk x fk

let cut t j sk (fk : fk) = t j (fun l _ -> sk l fk) fk

(** [map t [e1;..;eN]] returns all possible lists [l1@..@lN]
  * where [li] is a result of [t e1]. *)
let map ?(cut=true) t l sk fk0 =
  let rec aux acc l fk = match l with
    | [] -> sk (List.rev acc) fk
    | e::l ->
        t e
          (fun r fk ->
             let fk = if cut then fk0 else fk in
             aux (List.rev_append r acc) l fk)
          fk
  in 
  aux [] l fk0

(** Like [map], but only apply the tactic to selected judgements. *)
let map_sel ?(cut=true) sel_tacs l sk fk0 =
  check_sel sel_tacs l;         (* check user input *)

  let rec aux i acc l fk = match l with
    | [] -> sk (List.rev acc) fk
    | e::l ->
      match List.find_opt (fun (sel,_) -> List.mem i sel) sel_tacs with
      | Some (_,t) ->
        t e
          (fun r fk ->
             let fk = if cut then fk0 else fk in
             aux (i + 1) (List.rev_append r acc) l fk)
          fk
      | None -> aux (i + 1) (e :: acc) l fk
  in aux 1 [] l fk0

let orelse_nojudgment a b sk (fk : fk)  = a sk (fun _ -> b sk fk)

let orelse a b j sk fk = orelse_nojudgment (a j) (b j) sk fk

let orelse_list l j =
  List.fold_right (fun t t' -> orelse_nojudgment (t j) t') l fail

let andthen ?(cut=true) tac1 tac2 judge sk (fk : fk) : a =
  let sk =
    if cut then
      (fun l fk' -> map ~cut tac2 l sk fk)
    else
      (fun l fk' -> map ~cut tac2 l sk fk')
  in
  tac1 judge sk fk

let rec andthen_list ?(cut=true) = function
  | [] -> hard_failure (Failure "empty anthen_list")
  | [t] -> t
  | t::l -> andthen ~cut t (andthen_list ~cut l)

let andthen_sel ?(cut=true) tac1 sel_tacs judge sk (fk : fk) : a =
  let sk l fk' = 
    let fk = if cut then fk else fk' in
    map_sel ~cut sel_tacs l sk fk
  in
  tac1 judge sk fk

let id j sk fk = sk [j] fk

let try_tac t j sk fk =
  let succeeded = ref false in
  let sk' l fk = succeeded := true ; sk l fk in
  let fk' e = if !succeeded then fk e else sk [j] fk in
  t j sk' fk'

let checkfail_tac exc t j (sk : 'a sk) (fk : fk) =
  try
    let sk l fk = soft_failure DidNotFail in
    t j sk fk
  with
  | (Tactic_soft_failure (_,e) | Tactic_hard_failure (_,e)) when e = exc ->
    sk [j] fk
  | (Tactic_soft_failure (_, Failure _) |
     Tactic_hard_failure (_, Failure _) )
    when exc=Failure "" -> sk [j] fk
  | Tactic_soft_failure (l,e)
  | Tactic_hard_failure (l,e) ->
    raise (Tactic_hard_failure (l, FailWithUnexpected e))

let check_time t j sk fk =
  let time = Sys.time () in
  let sk j fk =
    Printer.prt `Dbg "time: %f" (Sys.time () -. time);
    sk j fk
  in
  t j sk fk


let repeat ?(cut=true) t j sk fk =
  let rec aux j sk fk =
    t j
      (fun l fk' ->
         let fk = if cut then fk else fk' in
         map ~cut aux l sk fk)
      (fun e -> sk [j] fk)
  in aux j sk fk

let eval_all (t : 'a tac) x =
  let l = ref [] in
  let exception End in
  try
    let sk r fk = l := r :: !l ; fk (None, More) in
    let fk _ = raise End in
    ignore (t x sk fk) ;
    assert false
  with End -> List.rev !l

let () =
  let checki ?name a b =
    Alcotest.(check (list (list int)))
      (match name with None -> "results" | Some s -> s)
      a b
  in
  Checks.add_suite "Tacticals" [
    "OrElse", `Quick, begin fun () ->
      let t1 = fun x sk fk -> sk [x] fk in
      let t2 = fun _ sk fk -> sk [(1,1)] fk in
      assert (eval_all (orelse_list [t1;t2]) (0,0) = [[(0,0)];[(1,1)]]) ;
      assert (eval_all (orelse t2 t1) (0,0) = [[(1,1)];[(0,0)]])
    end ;
    "AndThen", `Quick, begin fun () ->
      let t1 = fun _ sk fk -> sk [(0,0);(0,1)] (fun _ -> sk [(1,0)] fk) in

      let t2 = fun (x,y) sk fk -> sk [(-x,-y);(-2*x,-2*y)] fk in
      let expected = [ [0,0; 0,0; 0,-1; 0,-2]; [-1,0; -2,0] ] in
      assert (eval_all (andthen_list ~cut:false [t1;t2]) (11,12) = expected) ;
      assert (eval_all (andthen ~cut:false t1 t2) (11,12) = expected) ;

      let t3 = fun (x,y) sk fk -> if x+y = 1 then sk [] fk else sk [x,y] fk in
      let expected = [ [0,0] ; [] ] in
      assert (eval_all (andthen_list ~cut:false [t1;t3]) (11,12) = expected) ;
      assert (eval_all (andthen ~cut:false t1 t3) (11,12) = expected) ;

      let t3 = fun (x,y) sk fk -> if x+y = 0 then fk (None, More) else sk [y,x] fk in
      let expected = [ [0,1] ] in
      assert (eval_all (andthen_list ~cut:false [t1;t3]) (11,12) = expected) ;
      assert (eval_all (andthen ~cut:false t1 t3) (11,12) = expected) ;
    end ;
    "Repeat", `Quick, begin fun () ->
      let t : int tac =
        fun n sk fk -> if n = 0 then fk (None, Failure "") else sk [n-1] fk in
      checki [[0];[1];[2]] (eval_all (repeat ~cut:false t) 2) ;
      checki [[0]] (eval_all (repeat ~cut:true t) 2)
    end ;
    "Repeat cut", `Quick, begin fun () ->
      (* Non-branching tactic that sends 0 to 1 or 2, and sends 1 to 3,
       * fails otherwise. *)
      let t : int tac = fun n sk fk ->
        if n = 0 then sk [1] (fun _ -> sk [2] fk) else
          if n = 1 then sk [3] fk else
            fk (None, Failure "")
      in
      checki
        [[3];[1];[2];[0]]
        (eval_all (repeat ~cut:false t) 0) ;
      checki
        [[3]]
        (eval_all (repeat ~cut:true t) 0)
    end ;
    "Repeat cut", `Quick, begin fun () ->
      (* Non-branching tactic that sends 0 to 1 or 2,
       * fails otherwise. Here we see that (repeat t) also cuts
       * backtracking on its last call to t. *)
      let t : int tac = fun n sk fk ->
        if n = 0 then sk [1] (fun _ -> sk [2] fk) else
          fk (None, Failure "")
      in
      checki
        [[1];[2];[0]]
        (eval_all (repeat ~cut:false t) 0) ;
      checki
        [[1]]
        (eval_all (repeat ~cut:true t) 0)
    end ;
    "Andthen cut", `Quick, begin fun () ->
      (* Testing andthen with cut=true on a non-branching case.
       * The flag only cuts the backtracking on the first argument
       * of andthen. *)
      let t : int tac = fun _ sk fk -> sk [1] (fun _ -> sk [2] fk) in
      (* Check that id is neutral for anthen, on both sides. *)
      checki ~name:"id;t"
        [[1];[2]]
        (eval_all (andthen ~cut:false id t) 0) ;
      checki ~name:"t;id"
        [[1];[2]]
        (eval_all (andthen ~cut:false t id) 0) ;
      checki ~name:"[id;t]"
        [[1];[2]]
        (eval_all (andthen_list ~cut:false [id;t]) 0) ;
      checki ~name:"[t;id]"
        [[1];[2]]
        (eval_all (andthen_list ~cut:false [t;id]) 0) ;
      (* This is not the case anymore when cut=true. *)
      checki ~name:"t!id"
        [[1]]
        (eval_all (andthen ~cut:true t id) 0) ;
      (* checki ~name:"id!t"
       *   [[1];[2]]
       *   (eval_all (andthen ~cut:true id t) 0) ; *)
      checki ~name:"[t!id]"
        [[1]]
        (eval_all (andthen_list ~cut:true [t;id]) 0) ;
      (* checki ~name:"[id!t]"
       *   [[1];[2]]
       *   (eval_all (andthen_list ~cut:true [id;t]) 0) ; *)
      (* Check that cut=true is propagated in andthen beyond the first
       * andthen. Thus only we only backtrack on the last instance of t. *)
      (* checki ~name:"[t!t!t]"
       *   [[1];[2]]
       *   (eval_all (andthen_list ~cut:true [t;t;t]) 0) *)
    end ;
    "Andthen cut branching", `Quick, begin fun () ->
      (* Andthen with cut=true and a branching tactic.
       * The first invokation of t yields a success with
       * two subgoals: [0;1]. Further successes won't be considered.
       * The use of cut still allow backtracking in second invokation
       * of t, and since t is applied to both 0 and 1, we have four
       * possibilities: [0;1;2;3], [0;1], [2;3] and []. *)
      let t : int tac = fun n sk fk -> sk [2*n;2*n+1] (fun _ -> sk [] fk) in
      checki [[0;1];[]] (eval_all t 0) ;
      checki [[0;1]] (eval_all (andthen ~cut:true t id) 0) ;
      (* checki
       *   [[0;1;2;3];[0;1];[2;3];[]]
       *   (eval_all (andthen ~cut:true t t) 0) ; *)
      (* We now wrap t using cut, so there is no backtracking at all. *)
      checki
        [[0;1;2;3]]
        (eval_all (andthen ~cut:false (cut t) (cut t)) 0) ;
    end ;
    "Trytac", `Quick, begin fun () ->
      checki
        [[1]]
        (eval_all (try_tac (fun _ -> fail)) 1) ;
      checki
        [[1]]
        (eval_all (orelse (fun _ -> fail) id) 1) ;
      checki
        [[2]]
        (eval_all (try_tac (fun _ -> return [2])) 1) ;
      checki
        [[2];[1]]
        (eval_all (orelse (fun _ -> return [2]) id) 1)
    end ;
    "Try", `Quick, begin fun () ->
      let t = fun _ sk fk -> sk [1] (fun _ -> sk [] fk) in
      checki [[0]] (eval_all (try_tac (fun _ -> fail)) 0) ;
      checki [[1];[]] (eval_all (try_tac t) 0)
    end
  ]

(** Generic tactic syntax trees *)

module type S = sig

  type arg
  val pp_arg : Format.formatter -> arg -> unit

  type judgment

  val eval_abstract : string list -> lsymb -> arg list -> judgment tac
  val pp_abstract : pp_args:(Format.formatter -> arg list -> unit) ->
    string -> arg list -> Format.formatter -> unit

end

(** AST for tactics, with abstract leaves corresponding to prover-specific
  * tactics, with prover-specific arguments. Modifiers have no internal
  * semantics: they are printed, but ignored during evaluation -- they
  * can only be used for cheap tricks now, but may be used to guide tactic
  * evaluation in richer ways in the future. *)
type 'a ast =
  | Abstract of lsymb * 'a list
  | AndThen    : 'a ast list -> 'a ast
  | AndThenSel : 'a ast * (selector * 'a ast) list -> 'a ast
  | OrElse     : 'a ast list -> 'a ast
  | Try        : 'a ast -> 'a ast
  | Repeat     : 'a ast -> 'a ast
  | Ident      : 'a ast
  | Modifier   : string * 'a ast -> 'a ast
  | CheckFail  : tac_error_i * 'a ast -> 'a ast
  | By         : 'a ast * L.t -> 'a ast
  | Time       : 'a ast -> 'a ast

module type AST_sig = sig

  type arg
  type judgment
  type t = arg ast

  val eval : string list -> t -> judgment tac

  val eval_judgment : t -> judgment -> judgment list

  val pp : Format.formatter -> t -> unit

end

module AST (M:S) = struct

  open M

  (** AST for tactics, with abstract leaves corresponding to prover-specific
    * tactics, with prover-specific arguments. *)
  type t = arg ast

  type arg = M.arg
  type judgment = M.judgment

  let rec eval modifiers = function
    | Abstract (id,args)  -> eval_abstract modifiers id args
    | AndThen tl          -> andthen_list (List.map (eval modifiers) tl)
    | AndThenSel (t,tl)   ->
      let tl = List.map (fun (s,t') -> s, (eval modifiers t')) tl in
      andthen_sel (eval modifiers t) tl

    | OrElse tl           -> orelse_list (List.map (eval modifiers) tl)
    | Try t               -> try_tac (eval modifiers t)
    | By (t,loc)                ->
      andthen_list [eval modifiers t;
                    eval modifiers (Abstract (L.mk_loc loc "auto",[]))]

    | Repeat t            -> repeat (eval modifiers t)
    | Ident               -> id
    | Modifier (id,t)     -> eval (id::modifiers) t
    | CheckFail (e,t)     -> checkfail_tac e (eval modifiers t)
    | Time t              -> check_time (eval modifiers t)

  let pp_args fmt l =
    Fmt.list
      ~sep:(fun ppf () -> Fmt.pf ppf ",@ ")
      pp_arg fmt l

  let rec pp ppf = function
    | Abstract (i,args) ->
      let i = L.unloc i in
        begin try
          pp_abstract ~pp_args i args ppf
        with _ ->
          if args = [] then Fmt.string ppf i else
            Fmt.pf ppf "@[(%s@ %a)@]" i pp_args args
        end
    | Modifier (i,t) -> Fmt.pf ppf "(%s(%a))" i pp t

    | AndThen ts ->
      Fmt.pf ppf "@[(%a)@]"
        (Fmt.list ~sep:(fun ppf () -> Fmt.pf ppf ";@,") pp) ts

    | AndThenSel (t,l) ->
      let pp_sel_tac fmt (sel,s) =
        Fmt.pf ppf "@[%a: %a@]"
          pp t
          (Fmt.list ~sep:(fun ppf () -> Fmt.pf ppf ",") Fmt.int) sel
      in
      let pp_sel_tacs fmt l = match l with
        | [(sel,s)] -> pp_sel_tac fmt (sel, s)
        | _ ->
          Fmt.pf fmt "@[[%a]@]"
            (Fmt.list ~sep:(fun ppf () -> Fmt.pf ppf "|") pp_sel_tac) l
      in

      Fmt.pf ppf "@[(%a;@ %a)@]"
        pp t
        pp_sel_tacs l

    | OrElse ts ->
      Fmt.pf ppf "@[(%a)@]"
        (Fmt.list ~sep:(fun ppf () -> Fmt.pf ppf "+@,") pp) ts

    | By (t,_) -> Fmt.pf ppf "@[by %a@]" pp t

    | Ident -> Fmt.pf ppf "id"

    | Try t ->
      Fmt.pf ppf "(try @[%a@])" pp t

    | Repeat t ->
      Fmt.pf ppf "(repeat @[%a@])" pp t

    | CheckFail (e, t) ->
        Fmt.pf ppf "(checkfail %s @[%a@])" (tac_error_to_string e) pp t

    | Time t -> Fmt.pf ppf "(time %a)" pp t

  exception Return of M.judgment list

  (** The evaluation of a tactic, may either raise a soft failure or a hard
    * failure (cf tactics.ml). A soft failure should be formatted inside the
    * [Tactic_Soft_Failure] exception.
    * A hard failure inside Tactic_hard_failure. Those exceptions are caught
    * inside the interactive loop. *)
  let eval_judgment ast j =
    let tac = eval [] ast in
    (* The failure should raise the soft failure,
     * according to [pp_tac_error]. *)
    let fk (loc,tac_error) = soft_failure ?loc tac_error in
    let sk l _ = raise (Return l) in
    try ignore (tac j sk fk) ; assert false with Return l -> l

end


let timeout_get = function
  | Utils.Result a -> a
  | Utils.Timeout -> hard_failure TacTimeout


(*------------------------------------------------------------------*)
let print_system table system =
  Printer.prt `Result "@.%a@.%a@."
    (SystemExpr.pp_descrs table) system
    (if Config.print_trs_equations ()
     then Completion.print_init_trs
     else (fun _fmt _ -> ()))
    table
