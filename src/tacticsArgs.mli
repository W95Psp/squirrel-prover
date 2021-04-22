(** Arguments types for tactics, used to unify the declaration of tactics
   requiring type conversions. *)

module L = Location

type lsymb = Theory.lsymb


type s_item =
  | Tryauto   of Location.t    (** '//' *)
  | Simplify  of Location.t    (** '/=' *)

(*------------------------------------------------------------------*)
(** {2 Parsed arguments for rewrite} *)

type rw_count = [`Once | `Many | `Any ] (* ε | ! | ? *)

(** General rewrite item *)
type 'a rw_item_g = { 
  rw_mult : rw_count; 
  rw_dir  : [`LeftToRight | `RightToLeft ] L.located;
  rw_type : 'a;
}

(** Rewrite or expand item*)
type rw_item = [`Form of Theory.formula | `Expand of Theory.term] rw_item_g

(** Expand item*)
type expnd_item = [`Expand of Theory.term] rw_item_g

(** Rewrite argument, which is a rewrite or simplification item*)
type rw_arg =
  | R_item   of rw_item 
  | R_s_item of s_item

(** Rewrite target.
    None means the goal. *)
type rw_in = [`All | `Hyps of lsymb list] option 

(*------------------------------------------------------------------*)
type apply_in = lsymb option

(*------------------------------------------------------------------*)
(** {2 Intro patterns} *)

type naming_pat =
  | Unnamed   (** '_' *)
  | AnyName   (** '?' *)
  | Named of string

type and_or_pat =
  | Or      of simpl_pat list
  (** e.g. \[H1 | H2\] to do a case on a disjunction. *)
               
  | Split 
  (** \[\] to do a case. *)

  | And     of simpl_pat list
  (** e.g. \[H1 H2\] to destruct a conjunction. *)

and simpl_pat =
  | SAndOr of and_or_pat
  | SNamed of naming_pat

type intro_pattern =
  | Star   of Location.t    (** '*' *)
  | SItem  of s_item
  | SExpnd of expnd_item    (** @/macro *)
  | Simpl  of simpl_pat

(*------------------------------------------------------------------*)
val pp_naming_pat : Format.formatter -> naming_pat         -> unit
val pp_and_or_pat : Format.formatter -> and_or_pat         -> unit
val pp_simpl_pat  : Format.formatter -> simpl_pat          -> unit
val pp_intro_pat  : Format.formatter -> intro_pattern      -> unit
val pp_intro_pats : Format.formatter -> intro_pattern list -> unit
  

(*------------------------------------------------------------------*)
(** handler for intro pattern application *)
type ip_handler = [
  | `Var of Vars.evar (* Careful, the variable is not added to the env  *)
  | `Hyp of Ident.t
]

(*------------------------------------------------------------------*)
(** {2 Tactic arguments types} *)

type boolean = [`Boolean]

(** Types used during parsing. 
    Note that all tactics not defined in the parser must rely on the Theory 
    type, even to parse strings. *)
type parser_arg =
  | String_name of lsymb
  | Int_parsed  of int
  | Theory      of Theory.term
  | IntroPat    of intro_pattern list
  | AndOrPat    of and_or_pat
  | SimplPat    of simpl_pat
  | RewriteIn   of rw_arg list * rw_in
  | ApplyIn     of Theory.term * apply_in
                               
(** Tactic arguments sorts *)
type _ sort =
  | None      : unit sort

  | Message   : Type.message   sort
  | Boolean   :      boolean   sort
  | Timestamp : Type.timestamp sort        
  | Index     : Type.index     sort
        
  | ETerm     : Theory.eterm    sort
  (** Boolean, timestamp or message *)

  | Int       : int sort
  | String    : lsymb sort
  | Pair      : ('a sort * 'b sort) -> ('a * 'b) sort
  | Opt       : 'a sort -> ('a option) sort

(** Tactic arguments *)
type _ arg =
  | None      : unit arg 

  | Message   : Term.message   -> Type.message   arg
  | Boolean   : Term.message   ->      boolean   arg
  | Timestamp : Term.timestamp -> Type.timestamp arg
  | Index     : Vars.index     -> Type.index     arg

  | ETerm     : 'a Type.ty * 'a Term.term * Location.t -> Theory.eterm arg
  (** A [Term.term] with its sorts. *)
        
  | Int       : int -> int arg
  | String    : lsymb -> lsymb arg
  | Pair      : 'a arg * 'b arg -> ('a * 'b) arg
  | Opt       : ('a sort * 'a arg option) -> ('a option) arg

(*------------------------------------------------------------------*)
val pp_parser_arg : Format.formatter -> parser_arg -> unit

(*------------------------------------------------------------------*)
val sort : 'a arg -> 'a sort

type esort = Sort : ('a sort) -> esort

type earg = Arg : ('a arg) -> earg

(*------------------------------------------------------------------*)
exception Uncastable

val cast:  'a sort -> 'b arg -> 'a arg

(*------------------------------------------------------------------*)
val pp_esort : Format.formatter -> esort -> unit

(*------------------------------------------------------------------*)
(** {2 Argument conversion} *)

val convert_as_lsymb : parser_arg list -> lsymb option
  
val convert_args :
  Symbols.table -> Vars.env ->
  parser_arg list -> esort -> earg

(*------------------------------------------------------------------*)
(** {2 Error handling} *)

type tac_arg_error_i =
  | CannotConvETerm 

type tac_arg_error = Location.t * tac_arg_error_i

exception TacArgError of tac_arg_error

val pp_tac_arg_error :
  (Format.formatter -> Location.t -> unit) ->
  Format.formatter -> tac_arg_error -> unit

