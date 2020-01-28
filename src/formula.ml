open Atom

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

type formula = (generic_atom, Vars.evar) foformula

let rec pp_foformula pp_atom pp_var_list ppf = function
  | ForAll (vs, b) ->
    Fmt.pf ppf "@[forall (@[%a@]),@ %a@]"
      pp_var_list vs (pp_foformula pp_atom pp_var_list) b
  | Exists (vs, b) ->
    Fmt.pf ppf "@[exists (@[%a@]),@ %a@]"
      pp_var_list vs (pp_foformula pp_atom pp_var_list) b
  | And (bl, br) ->
    Fmt.pf ppf "@[<1>(%a@ &&@ %a)@]"
      (pp_foformula pp_atom pp_var_list) bl
      (pp_foformula pp_atom pp_var_list) br
  | Or (bl, br) ->
    Fmt.pf ppf "@[<1>(%a@ ||@ %a)@]"
      (pp_foformula pp_atom pp_var_list) bl
      (pp_foformula pp_atom pp_var_list) br
  | Impl (bl, br) ->
    Fmt.pf ppf "@[<1>(%a@ =>@ %a)@]"
      (pp_foformula pp_atom pp_var_list) bl
      (pp_foformula pp_atom pp_var_list) br
  | Not b ->
    Fmt.pf ppf "not(@[%a@])" (pp_foformula pp_atom pp_var_list) b
  | Atom a -> pp_atom ppf a
  | True -> Fmt.pf ppf "True"
  | False -> Fmt.pf ppf "False"

let rec foformula_vars atom_var = function
  | ForAll (vs,b) | Exists (vs,b) -> vs @ (foformula_vars atom_var b)
  | And (a,b) | Or (a,b) | Impl (a,b) ->
    foformula_vars atom_var a @ foformula_vars atom_var b
  | Not s -> foformula_vars atom_var s
  | Atom a -> atom_var a
  | True | False -> []

let formula_vars (f:formula) =
  foformula_vars generic_atom_var f
  |> List.sort_uniq Pervasives.compare

let formula_qvars f : Vars.evar list =
  foformula_vars (fun _ -> []) f
  |> List.sort_uniq Pervasives.compare

let pp_formula = pp_foformula pp_generic_atom Vars.pp_typed_list

let rec subst_foformula a_subst (s : Term.subst) (f) =
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

let subst_formula : Term.subst -> formula -> formula =
  subst_foformula subst_generic_atom

let fresh_quantifications env f =
  let vars = formula_qvars f in
  let subst =
    List.map
      (fun (Vars.EVar x) -> Term.ESubst
          (Term.Var x, Term.Var (Vars.make_fresh_from_and_update env x)))
      vars
  in
  subst_formula subst f

exception Not_a_disjunction

let rec disjunction_to_atom_list = function
  | False -> []
  | Atom at -> [at]
  | Or (a, b) -> disjunction_to_atom_list a @ disjunction_to_atom_list b
  | _ -> raise Not_a_disjunction
