channel c

axiom [test] triv_false : False

system A: in(c,x);out(c,x);
       B: in(c,y);out(c,diff(x,y)).



goal [left] test_left_bis : False.
Proof.
  apply triv_false.
Qed.
