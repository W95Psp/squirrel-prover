(** Euf Test Suite  *)


hash h
name k:message
name cst:message

signature sign, checksign, pk

name n2 : index -> index -> message
name k1 : index -> message


name n : message
name m : message

abstract u : message
abstract ok : message

channel c

(**************************)
(** SSC Failures checking *)
(**************************)
system null.



(** BEGIN TEST -- AUTOMATICALLY INCLUDED IN MANUAL **)
(* Failure when the key occurs inside the hashed message. *)
goal key_in_mess:
  h(k,k) = k => False.
Proof.
  simpl.
  checkfail euf M0 with BadSSC.
Abort.
(** END TEST **)

goal message_var :
  forall (m1: message, m2:message, m3:message),
  h(m3,k) = m1 => m3 <> m2  .
Proof.
  simpl.
  checkfail euf M0 with BadSSC.
Abort.

(** BEGIN TEST -- AUTOMATICALLY INCLUDED IN MANUAL **)
(* Failure when the key occurs inside an action condition. *)
system [condSSC] in(c,x); if x=k then out(c,x).

goal [none,condSSC] forall tau:timestamp,
  (if cond@tau then ok else zero) <> h(ok,k).
Proof.
  intros.
  checkfail euf M0 with BadSSC.
Abort.
(** END TEST **)
(* k occurs in the context *)

goal (k = h(u,k)) => False.
Proof.
  nosimpl(intro).
  checkfail euf M0 with BadSSC.
Abort.

(* euf should not allow to conclude here, and only yeld zero=zero *)
goal h(zero,h(zero,k)) <> h(zero,k).
Proof.
  intros.
  nosimpl(euf M0).
Abort.


(* h and euf cannot both use the same key *)
system [joint] (out(c,h(m,k)) | ( in(c,x); if checksign(x,pk(k))=n then out(c,x))).

goal [none, joint] forall tau:timestamp, cond@A3 => False.
Proof.
  intros.
  expand cond@A3.
  checkfail euf M0 with BadSSC.
Abort.


goal [none, joint] forall tau:timestamp, output@A4<>h(m,k).
Proof.
  intros.
  expand cond@A3.
  checkfail euf M0 with BadSSC.
Abort.

(**********************************************)
(** Check about variables naming and renaming *)
(**********************************************)

system [boundvars] out(c,seq(i,j -> h(n2(i,j),k1(i)))).

goal [none, boundvars] forall (tau:timestamp, j,j1,j2:index),
  (if cond@tau then ok else ok) = h(n2(j1,j2),k1(j)) => j1=j2.
Proof.
  intros.
  nosimpl(euf M0).
  (* We should have M1: n(j,j3) = n(j1,j2), and the goal should not magically close.
     We check that j from the seq is thus indeed replaced by j3 inside this check.
  *)
Abort.

goal forall (j,j1,j2:index),
  seq(i,j -> h(n2(i,j),k1(i))) = h(n2(j1,j2),k1(j)) => j1=j2.
Proof.
  intros.
  euf M0.
  (* This should not complete the proof.
   * There should be one goal, corresponding to a possible
   * equality between n(j1,j2) and an instance of n(_,_)
   * inside the seq(_). *)
Abort.


system [dupnames] !_i out(c,<h(n,k),h(m,k)>).

goal [none, dupnames] forall tau:timestamp, output@tau = h(u,k) => False.
Proof.
  intros.
  nosimpl(euf M0).
  (* Here EUF should create two cases for action A(_).
   * In each case a fresh index variable i should be created;
   * there should not be a second index variable i1 in the
   * second case. *)
  simpl.
  checkfail assert (i1=i1) with CannotConvert.
Abort.