name n : index->message
abstract f : message->message->message

system null.

goal forall (i1,i2,j:index) n(j) = f(n(i1),n(i2)) => (j = i1 || j = i2).
Proof.
nosimpl(intros).
nosimpl(fresh M0).
left.
right.
Qed.