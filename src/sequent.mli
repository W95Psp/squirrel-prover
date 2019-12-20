(** This module implement sequents used to prove trace properties.
    A sequent is made of:
    - a set of hypotheses, that can be generic formulas, trace formulas or
   (dis)equalities between messages;
    - a conclusion formula;
    - an environment to store all the variables appearing inside the formulas.
*)
open Term
open Bformula
open Formula

(** {2 Sequent type and basic operations} *)

type t
type sequent = t

val pp : Format.formatter -> sequent -> unit

(** [init formula] returns a sequent with an empty set of hypotheses, and the
   given formula as conclusion. *)
val init : formula -> sequent

(** [add_trace_formula tf s] returns the sequent [s] with [tf] added to its
    hypothesis. *)
val add_trace_formula : ?prefix:string -> trace_formula -> sequent -> sequent

(** [add_trace_formula f s] returns the sequent [s] with [f] added to its
    hypothesis. The new sequent will be automatically enriched with
    equalities expressing relevant macro definitions, as well as conditions
    of all named actions that are assumed to happen. *)
val add_formula : ?prefix:string -> formula -> sequent -> sequent

(** [set_env e s] returns a new sequent with
  * the environment set to [e]. *)
val set_env : Vars.env -> sequent -> sequent

(** [get_env s] returns the environment of the sequent. *)
val get_env : sequent -> Vars.env

(** [set_conclusion f s] set the conclusion formula of the sequent to [f]. *)
val set_conclusion : formula -> sequent -> sequent

(** [get_conclusion s] returns the conclusion formula of the sequent. *)
val get_conclusion : sequent -> formula

(** {2 Finding and hypotheses} *)

(** [is_hypothesis f s] returns true if the formula appears inside the hypotesis
   of the sequent [s]. Might be used to prove the validity of a sequent, if its
   conclusion formula appears inside its hypothesis. *)
val is_hypothesis : formula -> sequent -> bool

(** [get_hypothesis id s] returns the hypothesis named [id] in [s].
  * @raise Not_found if there is no such hypothesis. *)
val get_hypothesis : string -> sequent -> formula

(** Tags attached to message hypotheses. *)
type message_hypothesis_tag = {
  t_euf : bool
    (** Indicates that the euf tactic has been applied to the hypothesis. *)
}

(** [select_message_hypothesis name s update] returns the message
   (dis)equality corresponding to the given name inside the hypothesis of [s],
   together with a sequent identical to [s] except that the tag of the
   selected hypothesis has been updated using [update]. *)
val select_message_hypothesis : string -> sequent ->
  (message_hypothesis_tag -> message_hypothesis_tag) ->
  (sequent * term_atom)

(** {2 Automated reasoning} *)

(** [get_trs s] returns a term rewriting system that corresponds to the set of
   equalities between messages. It can be used to check if an equality is
   implied by the set of messages hypotheses. *)
val get_trs : sequent -> sequent * Completion.state

(** If [message_atoms_valid s] returns [true] then (dis)equalities over
  * messages on both sides of the sequents make the sequent valid. *)
val message_atoms_valid : sequent -> bool

(** [constraints_valid s] returns true if constraints make the sequent valid,
  * taking into account constraint trace formula hypotheses and atomic
  * constraint conclusion. *)
val constraints_valid : sequent -> bool

(** [get_ts_equalities s] return all the equalities between timestamps
       derivable from its hypothesis. *)
val get_ts_equalities : sequent -> timestamp list list

(** [maximal_elems s ts] returns the maximal elements of the timestamps,
   according to their ordering derived from the hypothesis in [s]. *)
val maximal_elems : sequent -> timestamp list -> timestamp list

(** {2 Misc} *)

(** [get_all_terms s] return all the term appearing inside the messages
   hypothesis of [s]. *)
val get_all_terms : sequent -> Term.term list