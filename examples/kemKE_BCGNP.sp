(*******************************************************************************

Generic 2xKEM - key exchange from Key encapsulation Mechanism (KEM)


[A] Boyd, Colin and Cliff, Yvonne and Nieto, Juan M. Gonzalez and Paterson, Kenneth G. One-round key exchange in the standard model.

# On KEMs

The protocol uses KEMS. In the paper, they are id based, which we abstract here.

The KEM are usally described with
(ek,dk) <- Keygen(r) returns an encryption key ek and a decryption key ek
(k,ct) <- Encap(r,ek) returns a session key k and its cyphertext ct
k <- Decap(ct,dk) returns k.

We abstract this with, pk, encap and decap function symbols, where
 * dk is a name, ek = pk(dk)
 * k is a name, ct=encap(k,r,pk(dk)).
 * decap(encap(k,r,pk(dk)),dk) = k

# Protocol description
We consider two parties I (initiator) and R (responder).
One KEM (Pk, Encap, DeCap) and two PRFs, Exct and Expd.
There is a public seed skex for Exct.


Static keys for party X := skX
Public keys for party X : pkX = pk(skX)


Initiator                                  Responder
new kI;
ctI := Encap(kI, rI  ,pk(skR))

                      --(I,ctI)->


                                         new kR;
                                         ctR := Encap(kR, rR , pk(skI))
                   I <--(R,ctR)-- R



kR := Decap(ctR,dkI)

                                         kI := Decap(ctI,dkI)

Final key deriviation:
kI2 := Exct(kI,skex)
kR2 := Exct(kR,skex)
s := (I,ctI,R,ctR)
KIR := expd(s,kI2) XOR expd(s,kR2)




*******************************************************************************)

set postQuantumSound = true.

hash exct

hash expd

(* public random key for exct *)

name skex : message

(* KEM *)

aenc encap,decap,pk

(* long term key of I *)

name skI : message

(* long term key of R *)
name skR : message

(* session randomess of I *)
name kI : index->message
name rI : index->message

(* session randomess of R *)
name kR : index->message
name rR : index->message


(* ideal keys *)
name ikIR : index ->message

abstract ok:message.

channel cI.
channel cR.

process Initiator(i:index) =
  (* we only send an encapsulation to an honest peer, with what we assume to be a valid public key*)
 let ctI = encap(kI(i), rI(i) ,pk(skR)) in
 out(cI, ctI ); (* we omit the public parameters in the output *)

 in(cR,ctR);

 (* first key derivation *)
 let dkR = decap(ctR,skI) in

 (* common derivations *)
 let kI2 = exct(kI(i),skex) in
 let kR2 = exct(dkR,skex) in
 let s = <pk(skI),<ctI,<pk(skR),ctR>>> in
 let kIR = expd(s,kI2) XOR expd(s,kR2) in


 out(cI, ok)

process Responder(j:index) =
   in(cI, ctI);

   let ctR = encap(kR(j), rR(j), pk(skI)) in (* we hardcode the public key of I here, we need to add in parallel the responder that wants to talk to anybody *)
   out(cR,ctR);
   (* first key derivation *)


   let dkI = decap(ctI,skR) in

 (* common derivations *)
 let kI2 = exct(dkI,skex) in
 let kR2 = exct(kR(j),skex) in
 let s = <pk(skI),<ctI,<pk(skR),ctR>>> in
 let kIR = expd(s,kI2) XOR expd(s,kR2) in

 out(cR, ok)

system [auth] out(cI,skex); ((!_j R: Responder(j)) | (!_i I: Initiator(i))).

goal [auth] weak_auth (j:index,i:index):
  happens(I1(i)) =>
    (dkR(i)@I1(i) = kR(j) => input@I1(i) = output@R(j)).
Proof.
simpl.
expandall.
nm Meq.
Qed.


goal [auth] weak_auth2 (j:index,i:index):
  happens(R1(j)) =>
    (dkI(j)@R1(j) = kI(i) => input@R(j) = output@I(i)).
Proof.
simpl.
expandall.
nm Meq.
Qed.

(*******************************************)
(*** Strong Secrecy of the initiator key ***)
(*******************************************)


(* Intermediate system where the kI is hidden. *)
process InitiatorRoR1(i:index) =

 let ctI = encap(diff(kI(i),skex), rI(i) ,pk(skR)) in
 out(cI, ctI ); (* we omit the public parameters in the output *)

 in(cR,ctR)

system [rori1] out(cI,skex); ((!_j R: Responder(j)) | (!_i I: InitiatorRoR1(i))).

equiv [rori1] trans.
Proof.
 enrich skex; enrich skI; enrich seq(j-> kR(j) );  enrich seq(i-> kI(i) ); enrich pk(skR); enrich seq(j-> rR(j) ).
 induction t.
 expandall.
 by fa 6.

 expandall.
 fa 6.
 fa 7.
 fa 7.
 fa 7.
 expandseq seq(j-> kR(j)),j.
 expandseq seq(j-> rR(j)),j.

 expandall.
 by fa 6.

 expandall.
 fa 6. fa 7. fa 7.
 cca1 7.
 equivalent len(diff(kI(i),skex)),diff(len(kI(i)),len(skex)).
 project.
  equivalent len(kI(i)), len(skex).
  by namelength kI(i), skex.



expandall.
fa 6.
Qed.

process InitiatorRoR(i:index) =
  (* We now assume the kI is hidden. *)
 let ctI = encap(skex, rI(i) ,pk(skR)) in
 out(cI, ctI ); (* we omit the public parameters in the output *)

 in(cR,ctR);

 (* first key derivation *)
 let dkR = decap(ctR,skI) in

 (* common derivations *)
 let kI2 = exct(skex,kI(i)) in
 let kR2 = exct(dkR,skex) in
 let s = <pk(skI),<ctI,<pk(skR),ctR>>> in
 let kIR = expd(s,kI2) XOR expd(s,kR2) in

 (* outputting the key should be real or random when a partnered session exists among the set of honest sessions *)
 out(cI, diff(ikIR(i), kIR)).

system [rori] out(cI,skex); ((!_j R: Responder(j)) | (!_i I: InitiatorRoR(i))).

axiom [rori] len_expd (x1,x2:message) : len(expd(x1,x2)) = len(skex).

equiv [rori] main.
Proof.
 enrich skex; enrich pk(skI); enrich pk(skR).
induction t.


  expandall.
  by fa 3.

  (* first output of R *)
  expandall.
  fa 3.
  fa 4.
  fa 4.
  cca1 4.

  equivalent len(kR(j)), len(skex).
  by namelength kR(j), skex.

  (* second output of R  *)
  expandall.
  by fa 3.

 (* first output of I *)
  expandall.
  fa 3.
  fa 4.
  fa 4.
  cca1 4.
   by depends I(i0), I1(i0).

  equivalent len(kI(i)), len(skex).
  namelength kI(i), skex.


 (* diff output of I *)
  expand frame, output, kIR4,kI6.
  fa 3.
  fa 4.
  fa 5.



  prf 5, exct(skex,kI(i)).
  yesif 5.
  project.

  prf 5, expd(s4(i)@I1(i),n_PRF).
  yesif 5.


  xor 5.
  yesif 5.
  use len_expd with s4(i)@I1(i),kR6(i)@I1(i).
  namelength n_PRF1, skex.

  fresh 5.
  yesif 5.

Qed.


(*******************************************)
(*** Strong Secrecy of the responder key ***)
(*******************************************)

(* Intermediate system where the kR is hidden. *)
process ResponderRoR1(j:index) =
   in(cI, ctI);

   let ctR = encap(diff(kR(j),skex), rR(j), pk(skI)) in (* we hardcode the public key of I here, we need to add in parallel the responder that wants to talk to anybody *)
   out(cR,ctR)

system [rorr1] out(cI,skex); ((!_j R: ResponderRoR1(j)) | (!_i I: Initiator(i))).

equiv [rorr1] transR.
Proof.
 enrich skex; enrich skR; enrich seq(j-> kR(j) );  enrich seq(i-> kI(i) ); enrich pk(skI); enrich seq(i-> rI(i) ).
 induction t.
 expandall.
 by fa 6.

 expandall.
 fa 6.
 fa 7.
 fa 7.
 cca1 7.
 equivalent len(diff(kR(j),skex)),diff(len(kR(j)),len(skex)).
 project.
  equivalent len(kR(j)), len(skex).
  by namelength kR(j), skex.


  expandall.

 expandseq seq(i-> kI(i)),i.
 expandseq seq(i-> rI(i)),i.
 fa 8.

 expandall.
 by fa 6.

Qed.

process ResponderRoR(j:index) =
   in(cI, ctI);

   let ctR = encap(skex, rR(j), pk(skI)) in (* we hardcode the public key of I here, we need to add in parallel the responder that wants to talk to anybody *)
   out(cR,ctR);
   (* first key derivation *)


   let dkI = decap(ctI,skR) in

 (* common derivations *)
 let kI2 = exct(dkI,skex) in
 let kR2 = exct(skex,kR(j)) in
 let s = <pk(skI),<ctI,<pk(skR),ctR>>> in
 let kIR = expd(s,kI2) XOR expd(s,kR2) in

 (* outputting the key should be real or random when a partnered session exists among the set of honest sessions *)
 out(cR, diff(ikIR(j), kIR)).

system [rorr] out(cI,skex); ((!_j R: ResponderRoR(j)) | (!_i I: Initiator(i))).

axiom [rorr] len_expdR (x1,x2:message) : len(expd(x1,x2)) = len(skex).

equiv [rorr] main2.
Proof.
 enrich skex; enrich pk(skI); enrich pk(skR).
induction t.


  expandall.
  by fa 3.

  (* first output of R *)
  expandall.
  fa 3.
  fa 4.
  fa 4.
  cca1 4.
   by depends R(j0), R1(j0).

  (* diff output of R  *)
  expand frame, output, kIR6, kR8.
  fa 3.
  fa 4.
  fa 5.

  prf 5, exct(skex,kR(j)).
  yesif 5.
  project.
  case H0.
   by depends R(j), R1(j).

  prf 5, expd(s6(j)@R1(j),n_PRF).
  yesif 5.

  xor 5, xor(expd(s6(j)@R1(j),kI8(j)@R1(j)),n_PRF1), n_PRF1.
  yesif 5.
  use len_expdR with s6(j)@R1(j),kI8(j)@R1(j).
  namelength n_PRF1, skex.

  fresh 5.
  yesif 5.

 (* first output of I *)
  expandall.
  fa 3.
  fa 4.
  fa 4.
  cca1 4.

  equivalent len(kI(i)), len(skex).
  namelength kI(i), skex.

 (* second output of I *)
 expandall.
 fa 3.

Qed.
