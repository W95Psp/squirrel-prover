name n : index->message
channel c
system !_i !_j out(c,n(j)).

goal forall (i:index,t:timestamp) n(i) = input@t => exists k:index, A(k,i) < t.
Proof.
  nosimpl(intros).
  nosimpl(fresh M0).
  nosimpl(exists i1).
  nosimpl(substitute i,j).
  nosimpl(assumption).
Qed.