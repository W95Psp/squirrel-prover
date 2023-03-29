(** Current mode of the prover:
    - [GoalMode] : waiting for the next goal.
    - [ProofMode] : proof of a goal in progress.
    - [WaitQed] : finished proof, waiting for closure.
    - [AllDone] : everything is done, waiting to leave the prover.
*)
type prover_mode = GoalMode | ProofMode | WaitQed | AllDone

type pending_proof = 
  | ProofObl of Goal.t          
  (** proof obligation *)
  | UnprovedLemma of Goal.statement * Goal.t
  (** lemma remaining to be proved *)

(** Option management **)
type option_name =
  | Oracle_for_symbol of string

type option_val =
  | Oracle_formula of Term.term

type option_def = option_name * option_val

val reset_option_defs : unit -> unit

exception Option_already_defined

val get_option : option_name -> option_val option

val add_option : option_def -> unit

(** From the name of the function, returns the corresponding formula. If no tag
   formula was defined, returns False. *)
val get_oracle_tag_formula : string -> Term.term

val option_defs : option_def list ref

(*------------------------------------------------------------------*)
(** {2 Printing infos} *)

(** User printing query *)
type print_query =
  | Pr_system    of SystemExpr.Parse.t option (* [None] means current system *)
  | Pr_any of Theory.lsymb (* print any lemma, function, name or macro
                              with given lsymb *)

(** User search query *)
type search_query =
  | Srch_term    of Theory.any_term
  | Srch_inSys   of Theory.any_term * SystemExpr.Parse.t 

(*------------------------------------------------------------------*)
(** Error handling *)

type error = Location.t * string

exception Error of error

val error : Location.t -> string -> 'a

val pp_error :
  (Format.formatter -> Location.t -> unit) -> 
  Format.formatter -> error -> unit


(* TOMOVE in prover.ml cpt in state TODO !*)
val unnamed_goal : unit -> Theory.lsymb

(*------------------------------------------------------------------*)
(** {2 Utilities for parsing} *)

type include_param = { th_name : Theory.lsymb; params : Theory.lsymb list }

type bulleted_tactic =
  | Bullet of string
  | Brace of [`Open | `Close]
  | BTactic of TacticsArgs.parser_arg Tactics.ast

type bulleted_tactics = bulleted_tactic list

(*------------------------------------------------------------------*)
type toplevel_input =
  | Undo    of int

type prover_input = 
  | InputDescr of Decl.declarations
  | SetOption  of Config.p_set_param
  | Tactic of bulleted_tactics
  | Print   of print_query
  | Search of search_query
  | Reset
  | Goal    of Goal.Parsed.t Location.located
  | Proof
  | Qed
  | Abort
  | Hint of Hint.p_hint
  | EOF
  | Include of include_param

type input =
  | Prover of prover_input
  | Toplvl of toplevel_input
