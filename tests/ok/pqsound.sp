set autoIntro=false.
set postQuantumSound=true.

hash h
name sk : message
channel c

name k :  message

name ok : message
name ko : message

name a : message

name b : message

name d : message

system
!_i (if False then out(c,diff(ok,ko)) else out(c,ok)).

global goal _ (i:index) :
 [happens(A(i))] -> equiv(diff(cond@A(i),False)).
Proof.
  checkfail intro t exn GoalNotPQSound.
Abort.



global goal _ (i:index) :
 [happens(A(i))] -> equiv(frame@pred(A(i)))-> equiv(frame@pred(A(i)), diff(cond@A(i),False)).
Proof.
  intro t Ind.
  expand cond.
  auto.
Qed.



system [att]
 (out(c, h(k,sk)); in(c,x); if snd(x) = h(fst(x),sk) && not(fst(x)=k) then O : out(c,diff(ok,ko)) else out(c,ok)).


global goal [att] _  :
 [happens(O)] -> equiv(diff(cond@O,False)).
Proof.
  checkfail intro t exn GoalNotPQSound.
Abort.



global goal [att] _  :
 [happens(O)] -> equiv(frame@pred(O))-> equiv(frame@pred(O), diff(cond@O, False)).
Proof.
  intro t Ind.
  equivalent cond@O, False.
  expand cond.help.
  simpl.
  intro eq1.
  destruct eq1 as [P N].
  euf P.
  intro ts eq.
  depends A2,O.
  auto.
  auto.

  auto.
Qed.