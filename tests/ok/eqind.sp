hash h
name k : message

name m1 : index -> message

system null.

goal function :
 forall (i:index,j:index),
  i = j =>
  m1(i) = m1(j).
Proof.
 simpl.
Qed.