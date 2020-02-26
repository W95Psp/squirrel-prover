open Term

type tac = EquivSequent.t Tactics.tac

module T = Prover.EquivTactics

(** {2 Utilities} *)

exception Out_of_range

(** When [0 <= i < List.length l], [nth i l] returns [before,e,after]
  * such that [List.rev_append before (e::after) = l] and
  * [List.length before = i].
  * @raise Out_of_range when [i] is out of range. *)
let nth i l =
  let rec aux i acc = function
    | [] -> raise Out_of_range
    | e::tl -> if i=0 then acc,e,tl else aux (i-1) (e::acc) tl
  in aux i [] l

(** {2 Tactics} *)

(** Wrap a tactic expecting an equivalence goal (and returning arbitrary
  * goals) into a tactic expecting a general prover goal (which fails
  * when that goal is not an equivalence). *)
let only_equiv t (s : Prover.Goal.t) sk fk =
  match s with
  | Prover.Goal.Equiv s -> t s sk fk
  | _ -> fk (Tactics.Failure "Equivalence goal expected")

(** Wrap a tactic expecting and returning equivalence goals
  * into a general prover tactic. *)
let pure_equiv t s sk fk =
  let t' s sk fk =
    t s (fun l fk -> sk (List.map (fun s -> Prover.Goal.Equiv s) l) fk) fk
  in
  only_equiv t' s sk fk

(** Tactic that succeeds (with no new subgoal) on equivalences
  * where the two frames are identical. *)
let refl (s : EquivSequent.t) sk fk =
  if EquivSequent.get_frame Term.Left s = EquivSequent.get_frame Term.Right s
  then
    sk [] fk
  else
    fk (Tactics.Failure "Frames not identical")


let () =
  T.register "refl"
    ~help:"Closes a reflexive goal.\n Usage: refl."
    (only_equiv refl)

(** TODO : dummy induc tactic, for testings,
before implementing true induction tactic. *)
let induc s sk fk =
  match   EquivSequent.get_frame Term.None s with
  | [] -> assert false
  | [EquivSequent.Message (
      Term.Macro (s ,_,Term.Pred _)
    )] when s  = Term.frame_macro -> sk [] fk
  | _ ->  fk (Tactics.Failure "Can only close dummy inductive goals.")

let () =
  T.register "induc"
    ~help:"Closes an inductive goal.\n Usage: induc."
    (only_equiv induc)

let timestamp_case ts s sk fk =
  let tsubst = Theory.subst_of_env (EquivSequent.get_env s) in
  let ts = Theory.convert tsubst ts Sorts.Timestamp in
  let goals = ref [] in
  let add_action a =
    let env = ref @@ EquivSequent.get_env s in
    let indices =
      List.map
        (fun i -> Vars.make_fresh_from_and_update env i)
        a.Action.indices
    in
    let subst =
      List.map2 (fun i i' -> Term.ESubst (Term.Var i,Term.Var i'))
        a.Action.indices indices
    in
    let name = Action.to_term (Action.subst_action subst a.Action.action) in
    let ts_subst = [Term.ESubst(ts,name)] in
    goals := (EquivSequent.apply_subst ts_subst s
             |> EquivSequent.set_env !env)
             ::!goals

  in
  let system_id = None in
  Action.iter_descrs ~system_id add_action ;
  sk !goals fk

let () =
  T.register_general "case"
    ~help:"Introduce all the possible goals when instantiating T with all \
           \n possible actions.
           \n Usage: case T."
    (function
       | [Prover.Theory th] -> pure_equiv (timestamp_case th)
       | _ -> raise @@ Tactics.Tactic_hard_failure
           (Tactics.Failure "improper arguments"))

(** Function application *)
let fa i s sk fk =
  let expand : type a. a Term.term -> EquivSequent.elem list = function
    | Fun (f,l) ->
      List.map (fun m -> EquivSequent.Message m) l
    | ITE (c,t,e) when t = e ->
        EquivSequent.[ Message t ]
    | ITE (c,t,e) ->
      EquivSequent.[ Formula c ; Message t ; Message e ]
    | Diff _ ->
        Tactics.soft_failure
          (Tactics.Failure "No common construct")
    | _ ->
        Tactics.soft_failure
          (Tactics.Failure "Unsupported: TODO")
  in
  let expand = function
    | EquivSequent.Message e -> expand (Term.head_normal_biterm e)
    | EquivSequent.Formula e -> expand (Term.head_normal_biterm e)
  in
  match nth i (EquivSequent.get_biframe s) with
    | before, e, after ->
        begin try
          let biframe = List.rev_append before (expand e @ after) in
          sk [EquivSequent.set_biframe s biframe] fk
        with
          | Tactics.Tactic_soft_failure err -> fk err
        end
    | exception Out_of_range ->
        fk (Tactics.Failure "Out of range position")

let () =
  T.register_general "fa"
    ~help:"Break function applications on the nth term of the sequence.\
           \n Usage: fa i."
    (function
       | [Prover.Int i] -> pure_equiv (fa i)
       | _ -> Tactics.hard_failure (Tactics.Failure "Integer expected"))

(** Fresh *)

exception Bad_fresh_ssc

class check_fresh ~system_id name = object (self)

  method visit_term t = match t with
    | EquivSequent.Message e -> self#visit_message e
    | EquivSequent.Formula e -> self#visit_formula e

  method visit_message t = match t with
    | Fun (_, l) -> List.iter self#visit_message l
    | Macro ((mn, sort, is),l,a) ->
        List.iter self#visit_message l ;
        self#visit_message (Macros.get_definition ~system_id sort mn is a)
    | Name (n,_) -> if n = name then raise Bad_fresh_ssc
    | Var _ -> ()
    | Diff(a, b) -> self#visit_message a; self#visit_message b
    | Left a -> self#visit_message a
    | Right a -> self#visit_message a
    | ITE (a, b, c) -> self#visit_formula a;
      self#visit_message b; self#visit_message c
    | Find (a, b, c, d) ->
        self#visit_formula b; self#visit_message c; self#visit_message d

  method visit_formula (f:Term.formula) =
    match f with
    | And (l,r) | Or (l,r) | Impl (l,r) ->
        self#visit_formula l ;
        self#visit_formula r
    | Not f -> self#visit_formula f
    | True | False -> ()
    | ForAll (vs,l) | Exists (vs,l) -> self#visit_formula l
    | Atom (`Message (_, t, t')) ->
        self#visit_message t ;
        self#visit_message t'
    | Macro ((mn, Sorts.Boolean, is),[],a) ->
      (* TODO : if we visit the subterm here, we have a recursive infinite loop
         due to exec. *)
      ()
    | _ -> failwith "unsupported"

end

(* Check the key syntactic side-condition:
    name must not appear in elems. *)
let fresh_name_ssc ~system_id name elems =
  try
    let ssc = new check_fresh ~system_id name in
    List.iter ssc#visit_term elems;
    true
  with Bad_fresh_ssc -> false

let fresh i s sk fk =
  match nth i (EquivSequent.get_biframe s) with
    | before, e, after ->
        begin try
          let (n_left, n_right) =
            match e with
            | EquivSequent.Message Name (n,_) -> (n,n)
            | EquivSequent.Message Diff (Name (nl,_),Name (nr,_)) -> (nl,nr)
            | _ -> raise @@ Tactics.Tactic_hard_failure
                    (Tactics.Failure "Can only apply fresh on names")
          in
          let biframe = (List.rev_append before after) in
          let frame_left = (List.map (EquivSequent.pi_elem Term.Left) biframe) in
          let frame_right = (List.map (EquivSequent.pi_elem Term.Right) biframe) in
          let system_id = EquivSequent.id_left s in
          if fresh_name_ssc ~system_id n_left frame_left
          then
            let system_id = EquivSequent.id_right s in
            if fresh_name_ssc ~system_id n_right frame_right
            then sk [EquivSequent.set_biframe s biframe] fk
            else raise @@ Tactics.Tactic_hard_failure
              (Tactics.Failure "Name not fresh in the right system")
          else
            raise @@ Tactics.Tactic_hard_failure
              (Tactics.Failure "Name not fresh in the left system")
        with
        | Tactics.Tactic_hard_failure err -> fk err
        end
    | exception Out_of_range ->
        fk (Tactics.Failure "Out of range position")

let () =
  T.register_general "fresh"
    ~help:"Removes a name if fresh.\n Usage: fresh i."
    (function
       | [Prover.Int i] -> pure_equiv (fresh i)
       | _ -> Tactics.hard_failure (Tactics.Failure "Integer expected"))

let dup i s sk fk =
  match nth i (EquivSequent.get_biframe s) with
    | before, e, after ->
        if List.mem e before || List.mem e after
        then
          let biframe = List.rev_append before after in
          sk [EquivSequent.set_biframe s biframe] fk
        else
          fk (Tactics.Failure "Dup tactic not applicable")
    | exception Out_of_range ->
        fk (Tactics.Failure "Out of range position")

let () =
  T.register_general "dup"
    ~help:"Removes a duplicated term.\n Usage: dup i."
    (function
       | [Prover.Int i] -> pure_equiv (dup i)
       | _ -> Tactics.hard_failure (Tactics.Failure "Integer expected"))


let expand (term : Theory.term)(s : EquivSequent.t) sk fk =
  let tsubst = Theory.subst_of_env (EquivSequent.get_env s) in
  let subst = match Theory.convert tsubst term Sorts.Boolean with
    | Macro ((mn, sort, is),l,a) ->
      [Term.ESubst (Macro ((mn, sort, is),l,a),
                    Macros.get_definition sort mn is a)
      ]
    | exception _ ->
      begin
        match Theory.convert tsubst term Sorts.Message with
        | Macro ((mn, sort, is),l,a) ->
          [Term.ESubst (Macro ((mn, sort, is),l,a),
                        Macros.get_definition sort mn is a)
          ]
        | _ -> raise @@ Tactics.Tactic_hard_failure
            (Tactics.Failure "Can only expand macros")
      end
    | _ -> raise @@ Tactics.Tactic_hard_failure
           (Tactics.Failure "Can only expand macros")
  in
  let apply_subst = function
    | EquivSequent.Message e ->  EquivSequent.Message (Term.subst subst e)
    | EquivSequent.Formula e ->  EquivSequent.Formula (Term.subst subst e)
  in
  sk [EquivSequent.set_biframe s
        (List.map apply_subst (EquivSequent.get_biframe s))] fk

let () = T.register_general "expand"
    ~help:"Expand all occurences of the given macro in the given hypothesis.\
           \n Usage: expand macro H."
    (function
       | [Prover.Theory v] -> pure_equiv (expand v)
       | _ -> raise @@ Tactics.Tactic_hard_failure
           (Tactics.Failure "improper arguments"))

let equiv t1 t2 (s : EquivSequent.t) sk fk =
  let env  = EquivSequent.get_env s in
  let tsubst = Theory.subst_of_env env in
  let t1 = Theory.convert tsubst t1 Sorts.Boolean in
  let t2 = Theory.convert tsubst t2 Sorts.Boolean in
  let trace_sequent = TraceSequent.init ~system:None
              (Term.And(Term.Impl(t1, t2), Term.Impl(t2, t1)))
               |> TraceSequent.set_env env
  in
  sk [ Prover.Goal.Trace trace_sequent;
       Prover.Goal.Equiv (EquivSequent.apply_subst [Term.ESubst(t1, t2)] s);
     ]
    fk

let () = T.register_general "equivalent"
    ~help:"Replace all occurences of a formula by another, and ask to prove \
           \n that they are equivalent.
           \n Usage: equiv t1, t2."
    (function
       | [Prover.Theory v1; Prover.Theory v2] -> only_equiv (equiv v1 v2)
       | _ -> raise @@ Tactics.Tactic_hard_failure
           (Tactics.Failure "improper arguments"))


let no_if i s sk fk =
  match nth i (EquivSequent.get_biframe s) with
    | before, e, after ->
      begin try
          let cond, negative_branch =
            match e with
            | EquivSequent.Message ITE (c,t,e) -> (c, EquivSequent.Message e)
            | _ -> raise @@ Tactics.Tactic_hard_failure
                (Tactics.Failure "improper arguments")
          in
          let biframe = List.rev_append before (negative_branch :: after) in
          let env = EquivSequent.get_env s in
          let trace_sequent = TraceSequent.init ~system:None
              (Term.Impl(cond,False))
                                   |> TraceSequent.set_env env
           in
           sk [Prover.Goal.Trace trace_sequent;
               Prover.Goal.Equiv (EquivSequent.set_biframe s biframe)] fk
        with
          | Tactics.Tactic_soft_failure err -> fk err
        end
    | exception Out_of_range ->
        fk (Tactics.Failure "Out of range position")
let () =
  T.register_general "noif"
    ~help:"Try to prove diff equivalence by proving that the condition at the \
           \n i-th position implies False.\
           \n Usage: noif i."
    (function
       | [Prover.Int i] -> only_equiv (no_if i)
       | _ -> Tactics.hard_failure (Tactics.Failure "Integer expected"))
