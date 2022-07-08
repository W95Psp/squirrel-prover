module SE = SystemExpr
module Args = TacticsArgs
  
(*------------------------------------------------------------------*)
type red_param = { 
  delta  : bool;
  constr : bool;
}

val rp_default : red_param
val rp_full    : red_param

val parse_simpl_args : red_param -> Args.named_args -> red_param 

(*------------------------------------------------------------------*)
module type S = sig
  type t                        (* type of sequent *)

  (*------------------------------------------------------------------*)
  (** {2 reduction } *)
    
  val reduce_term  :
    ?expand_context:Macros.expand_context -> 
    ?se:SE.t -> 
    red_param -> t -> Term.term -> Term.term     

  val reduce_equiv : 
    ?expand_context:Macros.expand_context ->
    ?system:SE.context -> 
    red_param -> t -> Equiv.form -> Equiv.form

  val reduce : 
    ?expand_context:Macros.expand_context ->
    ?system:SE.context -> 
    red_param -> t -> 'a Equiv.f_kind -> 'a -> 'a

  (*------------------------------------------------------------------*)
  (** {2 expantion and destruction modulo } *)
    
  val expand_head_once :
    ?expand_context:Macros.expand_context ->
    ?se:SE.t -> 
    red_param -> t -> Term.term -> Term.term * bool

  val destr_eq : 
    t -> 'a Equiv.f_kind -> 'a -> (Term.term * Term.term) option

  (*------------------------------------------------------------------*)
  (** {2 conversion } *)
      
  val conv_term  :
    ?expand_context:Macros.expand_context -> 
    ?se:SE.t -> 
    ?param:red_param ->
    t ->
    Term.term -> Term.term -> bool

  val conv_equiv : 
    ?expand_context:Macros.expand_context ->
    ?system:SE.context -> 
    ?param:red_param ->
    t ->
    Equiv.form -> Equiv.form -> bool

  val conv : 
    ?expand_context:Macros.expand_context ->
    ?system:SE.context -> 
    ?param:red_param ->
    t -> 'a Equiv.f_kind ->
    'a -> 'a -> bool

end

(*------------------------------------------------------------------*)
module Mk (S : LowSequent.S) : S with type t := S.t
