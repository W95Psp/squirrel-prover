name n : index->message

channel c

system !_i out(c,n(i)).

goal forall (j:index,t:timestamp) n(j) = input@t => A(j) < t.
Proof.
nosimpl(intros).
nosimpl(fresh M0).
nosimpl(substitute j,i).
nosimpl(assumption).
Qed.