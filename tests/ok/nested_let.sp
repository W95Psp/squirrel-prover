channel c
abstract f : message->message
abstract ff : message->message
system A: !_i
       in(c,x);
       let a = f(x) in
       let b = ff(a) in
       out(c,b).
goal forall i:index, output@A(i) = ff(f(input@A(i))).
Proof.
  auto.
Qed.