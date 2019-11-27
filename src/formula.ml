open Term
open Bformula

type generic_atom =
  | Trace of ts_atom
  | Message of term_atom

let subst_generic_atom s =
  function
  | Trace a -> Trace (subst_ts_atom s a)
  | Message a -> Message (subst_term_atom s a)

let pp_generic_atom  ppf =  function
  | Trace a -> pp_ts_atom ppf a
  | Message a -> pp_term_atom ppf a

let generic_atom_var =  function
  | Trace a -> ts_atom_vars a
  | Message a ->  term_atom_vars a

(** First order formulas *)
type ('a, 'b) foformula =
  | ForAll of ('b list) * ('a, 'b) foformula
  | Exists of ('b list) * ('a, 'b) foformula
  | And of ('a, 'b) foformula * ('a, 'b) foformula
  | Or of ('a, 'b) foformula * ('a, 'b) foformula
  | Not of ('a, 'b) foformula
  | Impl of ('a, 'b) foformula * ('a, 'b) foformula
  | Atom of 'a
  | True
  | False

exception Not_a_boolean_formula

let rec foformula_to_bformula fatom = function
  | And (a, b) ->
    Bformula.And(foformula_to_bformula fatom a, foformula_to_bformula fatom b)
  | Or (a, b) ->
    Bformula.Or(foformula_to_bformula fatom a, foformula_to_bformula fatom b)
  | Not a -> Bformula.Not(foformula_to_bformula fatom a)
  | Impl (a, b) ->
    Bformula.Impl(foformula_to_bformula fatom a, foformula_to_bformula fatom b)
  | Atom a -> Bformula.Atom(fatom a)
  | True -> Bformula.True
  | False -> Bformula.False
  | _ -> raise Not_a_boolean_formula

let rec bformula_to_foformula fatom = function
  | Bformula.And(a,b) ->
    And(bformula_to_foformula fatom a, bformula_to_foformula fatom b)
  | Bformula.Or (a, b) ->
    Or(bformula_to_foformula fatom a, bformula_to_foformula fatom b)
  | Bformula.Not a -> Not(bformula_to_foformula fatom a)
  | Bformula.Impl (a, b) ->
    Impl(bformula_to_foformula fatom a, bformula_to_foformula fatom b)
  | Bformula.Atom a -> Atom(fatom a)
  | Bformula.True -> True
  | Bformula.False -> False

type formula = (generic_atom, Vars.var) foformula

let fact_to_formula =
  bformula_to_foformula (fun x -> Message x)

let rec is_disjunction = function
  | Atom(_) -> true
  | Or(f1, f2) -> is_disjunction f1 && is_disjunction f2
  | _ -> false

let rec is_conjunction = function
  | Atom(_) -> true
  | And(f1, f2) -> is_disjunction f1 && is_disjunction f2
  | _ -> false

let conjunction_to_atom_lists f =
  let rec ctal ms ts = function
    | And(Atom (Message a), f) | And(f, Atom (Message a)) ->
      ctal (Bformula.Atom a :: ms) ts f
    | Atom (Message a) -> ((Bformula.Atom a :: ms), ts)
    | And(Atom (Trace a), f) | And(f, Atom (Trace a)) ->
      ctal ms (Bformula.Atom a :: ts) f
    | Atom (Trace a) -> (ms, (Bformula.Atom a :: ts))
    | _ -> assert false
  in
  ctal [] [] f

let disjunction_to_atom_lists f =
  let rec ctal ms ts = function
    | Or(Atom (Message a), f) | Or(f, Atom (Message a)) ->
      ctal (Bformula.Atom a :: ms) ts f
    | Atom (Message a) -> ((Bformula.Atom a :: ms), ts)
    | Or(Atom (Trace a), f) | Or(f, Atom (Trace a)) ->
      ctal ms (Bformula.Atom a :: ts) f
    | Atom (Trace a) -> (ms, (Bformula.Atom a :: ts))
    | _ -> assert false
  in
  ctal [] [] f

let rec pp_foformula pp_atom pp_var_list ppf = function
  | ForAll (vs, b) ->
    Fmt.pf ppf "@[<v 0>forall %a%a@]"
      pp_var_list vs (pp_foformula pp_atom pp_var_list)  b
  | Exists (vs, b) ->
    Fmt.pf ppf "@[<v 0>exists %a%a@]"
      (Vars.pp_typed_list "") vs (pp_foformula pp_atom pp_var_list) b
  | And (bl, br) ->
    Fmt.pf ppf "@[<hv>(%a && %a)@]"
      (pp_foformula pp_atom pp_var_list) bl
      (pp_foformula pp_atom pp_var_list) br
  | Or (bl, br) ->
    Fmt.pf ppf "@[<hv>(%a || %a)@]"
      (pp_foformula pp_atom pp_var_list) bl
      (pp_foformula pp_atom pp_var_list) br
  | Impl (bl, br) ->
    Fmt.pf ppf "@[<hv>(%a@ =>@ %a)@]"
      (pp_foformula pp_atom pp_var_list) bl
      (pp_foformula pp_atom pp_var_list) br
  | Not b ->
    Fmt.pf ppf "@[<hv>not(%a)@]" (pp_foformula pp_atom pp_var_list) b
  | Atom a -> pp_atom ppf a
  | True -> Fmt.pf ppf "true"
  | False -> Fmt.pf ppf "false"

let rec foformula_vars atom_var = function
  | ForAll (vs,b) | Exists (vs,b) -> vs @ (foformula_vars atom_var b)
  | And (a,b) | Or (a,b) | Impl (a,b) ->
    foformula_vars atom_var a @ foformula_vars atom_var b
  | Not s -> foformula_vars atom_var s
  | Atom a -> atom_var a
  | True | False -> []

let formula_vars f =
  foformula_vars generic_atom_var f
  |> List.sort_uniq Pervasives.compare

let formula_qvars f =
  foformula_vars (fun a -> []) f
  |> List.sort_uniq Pervasives.compare

let pp_formula = pp_foformula pp_generic_atom (Vars.pp_typed_list "")

let rec subst_foformula a_subst (s : subst) (f) =
  match f with
  | ForAll (vs,b) -> ForAll (vs, subst_foformula a_subst s b)
  | Exists (vs,b) -> Exists (vs, subst_foformula a_subst s b)
  | And (a, b) ->
    And (subst_foformula a_subst s a, subst_foformula a_subst s b )
  | Or (a, b) ->
    Or (subst_foformula a_subst s a, subst_foformula a_subst s b )
  | Impl (a, b) ->
    Impl (subst_foformula a_subst s a, subst_foformula a_subst s b )
  | Not a -> Not (subst_foformula a_subst s a)
  | Atom at -> Atom (a_subst s at)
  | True | False -> f

let subst_formula = subst_foformula subst_generic_atom

let fresh_quantifications env f =
  let vars = formula_qvars f in
  let subst =
    List.map
      (fun x -> x, Vars.make_fresh_from_and_update env x)
      vars
    |> from_varsubst
  in
  subst_formula subst f
