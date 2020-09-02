channel c

system A : !_i new a; !_j new b; out(c,b).

equiv test (i,j,ii,jj:index) :
  diff(output@pred(A(i,j)),output@pred(A(ii,jj))),
  diff(output@A(i,j),output@A(ii,jj)).

Proof.
  expand output@A(i,j).
  expand output@A(ii,jj).
  fresh 1.
  yesif 1.
  admit. (* Induction hypothesis.*)
Qed.