set autoIntro=false.

channel c
abstract ok : message
system let x = ok in out(c,x).
goal _: output@A = x@A.
Proof.
  auto.
Qed.
