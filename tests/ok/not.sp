set autoIntro=false.

system null.
goal _ (t:timestamp): not(happens(t)) => not(happens(t)).
Proof.
  nosimpl(intro t Hnot H).
  nosimpl(apply Hnot; assumption). 
Qed.
