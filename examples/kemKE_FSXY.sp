(*******************************************************************************

Generic Construction (GC) of key exchange from Key encapsulation Mechanism (KEM)


That is a more complex construction than the BCGNP one.

[A] Fujioka, Atsushi and Suzuki, Koutarou and Xagawa, Keita and Yoneyama, Kazuki. Strongly Secure Authenticated Key Exchange from Factoring, Codes, and Lattices


# On KEMs

The protocol uses KEMS

The KEM are usally described with
(ek,dk) <- Keygen(r) returns an encryption key ek and a decryption key ek
(k,ct) <- Encap(r,ek) returns a session key k and its cyphertext ct
k <- Decap(ct,dk) returns k.

We abstract this with, pk, encap and decap function symbols, where
 * dk is a name, ek = pk(dk)
 * k is a name, ct=encap(k,r,pk(dk)).
 * decap(encap(k,r,pk(dk)),dk) = k


# Protocol description

There are two KEMs (Pk, Encap, DeCap) and (wPk, wEncap, wDeCap)

PRFs : F, F' and G
KDF: KDF with public random salt s

Two parties I (initiator) and R (responder)

Static keys for party X := dkX, skX, sk2X
Public keys for party X : ekX = pk(dkX)


Initiator                                  Responder
new kI; new rI, rI2.
ctI := Encap(kI, F(rI,skI) XOR F(skI2,rI2)  ,pk(dkR))
new dkT; ekT := wpk(dkT);

                 I --(I,R,ctI,ekT)-> R

R:
                                       new kR; new rR, rR2, rTI.
                                       ctR := Encap(kR, F(rR,skR) XOR F(sk2R, rR2) , pk(dkI))
                                       new kT;
                                       ctT := wEncap(kT, rTI, ekT )

                 I <--(I,R,ctR,ctT)-- R



kR := Decap(ctR,dkI)
kT := wDecap(ctT,dkT)

                                       kI := Decap(ctI,dkI)

Final key derivation:

K1 := KDF(s,kI); K2 := KDF(s,kR); K3 := KDF(s,kT)

ST := (I,R,pk(dkI),pk(dkR),ctI,pk(ekT),ctR,ctT)
SK := G(ST,K1) XOR G(ST,K2) XOR G(ST,K3)


# High level intuitions


We model two agents that may initiate multiple sessions. See PQ-x3dh-like for a devellopment with multiple keys.

We prove some weak authentication: if an agent obtained some honest parameter,
it was sent out by an honest agent.

We prove also separately for each agent that the computed key is real or random,
which implies the implicit authentication of the scheme: only the other trusted
party could potentially compute the key.



*******************************************************************************)
set postQuantumSound = true.
hash F

hash F2

hash G


(* public random salt *)

name s : message

(* KEMs *)

aenc encap,decap,pk
aenc wencap,wdecap,wpk

(* long term keys of I *)
name dkI : message
name skI : message
name sk2I : message

(* long term keys of R *)
name dkR : message
name skR : message
name sk2R : message

(* session randomess of I *)
name kI : index->message
name rI : index->message
name rI2 : index->message
name dkT : index->message

abstract ok : message


(* session randomess of R *)
name kR : index->message
name rR : index->message
name rR2 : index->message
name rTI : index->message
name kT : index->message

name kIR : index->message

hash kdf

hash Gh

channel cI
channel cR.

process Initiator(i:index) =
 let ctI = encap(kI(i), F(rI(i),skI) XOR F(sk2I,rI2(i))  ,pk(dkR)) in
 let ekT = wpk(dkT(i)) in
 out(cI, <ctI,ekT> ); (*we omit the public parameters in the output *)

 in(cR,messI);
 let ctR = fst(messI) in
 let ctT = snd(messI) in

 (* first key derivations, should match kR(j) and kT(j) *)
 let kR = decap(ctR,dkI) in
 let kT = wdecap(ctT,dkT(i)) in

 (* Full common key derivations *)
 let K1 = kdf(s,kI(i)) in
 let K2 = kdf(s,kR) in
 let K3 = kdf(s,kT) in

 let ST = <pk(dkI),<pk(dkR),<ctI,<pk(ekT),<ctR,ctT>>>>> in
 let SK = xor(G(ST,K1), xor( G(ST,K2), G(ST,K3))) in

 out(cI,ok)




process Responder(j:index) =
   in(cI, messR);
   let ctI = fst(messR) in
   let ekT = snd(messR) in

   let ctR = encap(kR(j), F(rR(j),skR) XOR F(sk2R,rR2(j)), pk(dkI)) in (* we hardcode the public key of I here, we need to add in parallel the responder that wants to talk to anybody *)
   let ctT = wencap(kT(j),rTI(j),ekT) in
   out(cR,<ctR,ctT>);

   let kI = decap(ctI,dkR) in
  (* Full common key derivations *)
   let K1 = kdf(s,kI) in
   let K2 = kdf(s,kR(j)) in
   let K3 = kdf(s,kT(j)) in

   let ST = <pk(dkI),<pk(dkR),<ctI,<pk(ekT),<ctR,ctT>>>>> in
   let SK = xor(G(ST,K1), xor( G(ST,K2), G(ST,K3))) in

   out(cR,ok)

system out(cI,s); ((!_j R: Responder(j)) | (!_i I: Initiator(i))).


(******* Mutual Authentication ******)
(************************************)
(* We must first show that the authentication is using valid randoms *)

process Initiator2(i:index) =
 let ctI = encap(kI(i),diff(F(rI(i),skI) XOR F(sk2I,rI2(i)),rI(i)), pk(dkR)) in
 let ekT = wpk(dkT(i)) in
 out(cI, <ctI,ekT> ); (*we omit the public parameters in the output *)

 in(cR,messI);
 let ctR = fst(messI) in
 let ctT = snd(messI) in

 (* first key derivations, should match kR(j) and kT(j) *)
 let kR = decap(ctR,dkI) in
 let kT = wdecap(ctT,dkT(i)) in

 (* Full common key derivations *)
 let K1 = kdf(s,kI(i)) in
 let K2 = kdf(s,kR) in
 let K3 = kdf(s,kT) in

 let ST = <pk(dkI),<pk(dkR),<ctI,<pk(ekT),<ctR,ctT>>>>> in
 let SK = xor(G(ST,K1), xor( G(ST,K2), G(ST,K3))) in

 out(cI,ok)


process Responder2(j:index) =
   in(cI, messR);
   let ctI = fst(messR) in
   let ekT = snd(messR) in

   let ctR = encap(kR(j), diff(F(rR(j),skR) XOR F(sk2R,rR2(j)), rR(j)), pk(dkI)) in
   let ctT = wencap(kT(j),rTI(j),ekT) in
   out(cR,<ctR,ctT>);

   let kI = decap(ctI,dkR) in
  (* Full common key derivations *)
   let K1 = kdf(s,kI) in
   let K2 = kdf(s,kR(j)) in
   let K3 = kdf(s,kT(j)) in

   let ST = <pk(dkI),<pk(dkR),<ctI,<pk(ekT),<ctR,ctT>>>>> in
   let SK = xor(G(ST,K1), xor( G(ST,K2), G(ST,K3))) in

   out(cR,ok)

system [auth] out(cI,s); ((!_j R: Responder2(j)) | (!_i I: Initiator2(i))).

axiom [auth] len_F (x1,x2:message) : len(F(x1,x2)) = len(s).


equiv [auth] trans_auth.
Proof.
 enrich dkI; enrich dkR; enrich s;
 enrich seq(i-> kT(i)); enrich seq(i->rTI(i));
 enrich seq(i-> dkT(i));
 enrich seq(i-> kR(i));
 enrich seq(i-> kI(i)).
 induction t.

 expandall.
 fa 8.

 (* First output of R *)
 expandall.
 fa 8.
 fa 9.
 fa 9.
 fa 9.
 fa 10.
 expandseq  seq(i-> kT(i)), j.
 expandseq  seq(i-> rTI(i)), j.
 prf 9.
 yesif 9.
 project.
 xor 9, xor(F(rR(j),skR),n_PRF), n_PRF.
 yesif 9.

 use len_F with rR(j), skR.
 namelength n_PRF,s.

 fa 9.
 fresh 10.
 yesif 10.
 expandseq  seq(i-> kR(i)), j.

 (* Second output of R *)
 expandall.
 fa 8.


 (* First output of I *)
  expandall.
  fa 8.
  fa 9.
  fa 9.
  fa 9.
  fa 10.
  expandseq seq(i-> dkT(i)),i.
  prf 9.
  yesif 9.

  by project.

  xor 9, xor(F(rI(i),skI),n_PRF), n_PRF.
  yesif 9.

  use len_F with rI(i), skI.
  by namelength n_PRF,s.

  fa 9.
  fresh 10.
  yesif 10.
  expandseq  seq(i->kI(i)),i.

 (* Second output of I *)
 expandall.
 fa 8.
Qed.

(* As the encryption use valid randomness, we can prove the weak authenticaton. *)

goal [auth/right] weak_auth (j:index,i:index):
  happens(I1(i)) =>
    (kR1(i)@I1(i) = kR(j) => fst(input@I1(i)) = fst(output@R(j))).
Proof.
simpl.
expandall.
nm Meq.
Qed.

goal [auth/right] weak_auth2 (j:index,i:index):
  happens(R1(j)) =>
    (kI2(j)@R1(j) = kI(i) => fst(input@R(j)) = fst(output@I(i))).
Proof.
simpl.
expandall.
nm Meq.
Qed.



(******* Real or Randoms ******)
(******************************)

(* Intermediate system where the kI or kR is hidden.  *)
(* NOTE: this transformation breaks the correctness
of the key computation of R. But we only want to prove
on this system that the key computed by I is real or random. *)


process Initiator3(i:index) =
 let ctI = encap(diff(kI(i),s),rI(i), pk(dkR)) in
 let ekT = wpk(dkT(i)) in
 out(cI, <ctI,ekT> ); (*we omit the public parameters in the output *)

 in(cR,messI);
 let ctR = fst(messI) in
 let ctT = snd(messI) in

 (* first key derivations, should match kR(j) and kT(j) *)
 let kR = decap(ctR,dkI) in
 let kT = wdecap(ctT,dkT(i)) in

 (* Full common key derivations *)
 let K1 = kdf(s,kI(i)) in
 let K2 = kdf(s,kR) in
 let K3 = kdf(s,kT) in

 let ST = <pk(dkI),<pk(dkR),<ctI,<pk(ekT),<ctR,ctT>>>>> in
 let SK = xor(G(ST,K1), xor( G(ST,K2), G(ST,K3))) in

 out(cI,ok)


process Responder3(j:index) =
   in(cI, messR);
   let ctI = fst(messR) in
   let ekT = snd(messR) in

   let ctR = encap(diff(kR(j),s), rR(j), pk(dkI)) in
   let ctT = wencap(kT(j),rTI(j),ekT) in
   out(cR,<ctR,ctT>);

   let kI = decap(ctI,dkR) in
  (* Full common key derivations *)
   let K1 = kdf(s,kI) in
   let K2 = kdf(s,kR(j)) in
   let K3 = kdf(s,kT(j)) in

   let ST = <pk(dkI),<pk(dkR),<ctI,<pk(ekT),<ctR,ctT>>>>> in
   let SK = xor(G(ST,K1), xor( G(ST,K2), G(ST,K3))) in

   out(cR,ok)

system [trans_ror] out(cI,s); ((!_j R: Responder3(j)) | (!_i I: Initiator3(i))).

equiv [trans_ror] trans_ror.
Proof.
 enrich pk(dkI); enrich pk(dkR); enrich s;
 enrich seq(i-> kT(i)); enrich seq(i->rTI(i));
 enrich seq(i-> dkT(i)).
 induction t.

 expandall.
 fa 6.

 (* First output of R *)
 expandall.
 fa 6.
 fa 7.
 fa 7.
 fa 7.
 fa 8.
 expandseq  seq(i-> kT(i)), j.
 expandseq  seq(i-> rTI(i)), j.
 cca1 7.
 equivalent len(diff(kR(j),s)),diff(len(kR(j)),len(s)).

 by project.

 equivalent len(kR(j)),len(s).
 by namelength kR(j),s.

 (* Second output of R *)
 expandall.
 fa 6.

 (* First output of I *)
  expandall.
  fa 6.
  fa 7.
  fa 7.
  fa 7.
  fa 8.
  expandseq seq(i-> dkT(i)),i.
  cca1 7.

 equivalent len(diff(kI(i),s)),diff(len(kI(i)),len(s)).

 by project.

 equivalent len(kI(i)),len(s).
 by namelength kI(i),s.

 (* Second output of I *)
 expandall.
 fa 6.
Qed.


(*** Targets for RoR ***)
(***********************)

process Initiator4(i:index) =
 let ctI = encap(s,rI(i), pk(dkR)) in
 let ekT = wpk(dkT(i)) in
 out(cI, <ctI,ekT> ); (*we omit the public parameters in the output *)

 in(cR,messI);
 let ctR = fst(messI) in
 let ctT = snd(messI) in

 (* first key derivations, should match kR(j) and kT(j) *)
 let kR = decap(ctR,dkI) in
 let kT = wdecap(ctT,dkT(i)) in

 (* Full common key derivations *)
 let K1 = kdf(s,kI(i)) in
 let K2 = kdf(s,kR) in
 let K3 = kdf(s,kT) in

 let ST = <pk(dkI),<pk(dkR),<ctI,<pk(ekT),<ctR,ctT>>>>> in
 let SK = xor(G(ST,K1), xor( G(ST,K2), G(ST,K3))) in

 out(cI,ok)


process Responder4(j:index) =
   in(cI, messR);
   let ctI = fst(messR) in
   let ekT = snd(messR) in

   let ctR = encap(s, rR(j), pk(dkI)) in
   let ctT = wencap(kT(j),rTI(j),ekT) in
   out(cR,<ctR,ctT>);

   let kI = decap(ctI,dkR) in
  (* Full common key derivations *)
   let K1 = kdf(s,kI) in
   let K2 = kdf(s,kR(j)) in
   let K3 = kdf(s,kT(j)) in

   let ST = <pk(dkI),<pk(dkR),<ctI,<pk(ekT),<ctR,ctT>>>>> in
   let SK = xor(G(ST,K1), xor( G(ST,K2), G(ST,K3))) in

   out(cR,ok)
.


(****** Initiator RoR *****)
(**************************)
process Initiator5(i:index) =
 let ctI = encap(s,rI(i), pk(dkR)) in
 let ekT = wpk(dkT(i)) in
 out(cI, <ctI,ekT> ); (*we omit the public parameters in the output *)

 in(cR,messI);
 let ctR = fst(messI) in
 let ctT = snd(messI) in

 (* first key derivations, should match kR(j) and kT(j) *)
 let kR = decap(ctR,dkI) in
 let kT = wdecap(ctT,dkT(i)) in

 (* Full common key derivations *)
 let K1 = kdf(s,kI(i)) in
 let K2 = kdf(s,kR) in
 let K3 = kdf(s,kT) in

 let ST = <pk(dkI),<pk(dkR),<ctI,<pk(ekT),<ctR,ctT>>>>> in
 let SK = xor(G(ST,K1), xor( G(ST,K2), G(ST,K3))) in

 out(cI,diff(kIR(i),SK)).

system [rorI] out(cI,s); ((!_j R: Responder4(j)) | (!_i I: Initiator5(i))).

axiom [rorI] len_G (x1,x2:message) : len(G(x1,x2)) = len(s).

axiom [rorI] len_xor (x1,x2:message) : len(x1) = len(x2) => len(xor(x1,x2)) = len(x1).

 set timeout = 10.

equiv [rorI] rorI.
Proof.
 enrich pk(dkI); enrich pk(dkR); enrich s;
 enrich seq(i-> kT(i)); enrich seq(i->rTI(i));
 enrich seq(i-> rR(i)); enrich seq(i->rI(i));
 enrich seq(i-> dkT(i)).
 induction t.

 expandall.
 fa 8.

 (* First output of R *)
 expandall.
 fa 8.
 fa 9.
 fa 9.
 fa 9.
 fa 9.
 fa 10.
 expandseq  seq(i-> kT(i)), j.
 expandseq  seq(i-> rTI(i)), j.
 expandseq  seq(i-> rR(i)), j.

 (* Second output of R *)
 expandall.
 fa 8.


 (* First output of I *)
  expandall.
  fa 8.
  fa 9.
  fa 9.
  fa 9.
  fa 9.
  fa 10.
  expandseq  seq(i-> rI(i)), i.
  expandseq seq(i-> dkT(i)),i.

 (* Second output of I *)
 expandall.
 fa 8.
 fa 9.

 fa 9.
 prf 9,  kdf(s,kI(i)).
 yesif 9.

 by project.

 prf 9, G(<pk(dkI),
            <pk(dkR),
             <encap(s,rI(i),pk(dkR)),
              <pk(wpk(dkT(i))),<fst(input@I1(i)),snd(input@I1(i))>>>>>,n_PRF).
 yesif 9.
 xor 9, n_PRF1.
 yesif 9.

 use len_xor with G(<pk(dkI),
         <pk(dkR),
          <encap(s,rI(i),pk(dkR)),
           <pk(wpk(dkT(i))),<fst(input@I1(i)),snd(input@I1(i))>>>>>,
      kdf(s,decap(fst(input@I1(i)),dkI))),
  G(<pk(dkI),
     <pk(dkR),
      <encap(s,rI(i),pk(dkR)),
       <pk(wpk(dkT(i))),<fst(input@I1(i)),snd(input@I1(i))>>>>>,
  kdf(s,wdecap(snd(input@I1(i)),dkT(i)))).
 use len_G with <pk(dkI),
          <pk(dkR),
           <encap(s,rI(i),pk(dkR)),
            <pk(wpk(dkT(i))),<fst(input@I1(i)),snd(input@I1(i))>>>>>,
       kdf(s,decap(fst(input@I1(i)),dkI)).
 by namelength n_PRF1, s.

 use len_G with <pk(dkI),
          <pk(dkR),
           <encap(s,rI(i),pk(dkR)),
            <pk(wpk(dkT(i))),<fst(input@I1(i)),snd(input@I1(i))>>>>>,
       kdf(s,decap(fst(input@I1(i)),dkI)).
 by use len_G with <pk(dkI),
     <pk(dkR),
      <encap(s,rI(i),pk(dkR)),
       <pk(wpk(dkT(i))),<fst(input@I1(i)),snd(input@I1(i))>>>>>,
  kdf(s,wdecap(snd(input@I1(i)),dkT(i))).

  fresh 9.
  yesif 9.
Qed.


(****** Responder RoR *****)
(**************************)


process Responder5(j:index) =
   in(cI, messR);
   let ctI = fst(messR) in
   let ekT = snd(messR) in

   let ctR = encap(s, rR(j), pk(dkI)) in
   let ctT = wencap(kT(j),rTI(j),ekT) in
   out(cR,<ctR,ctT>);

   let kI = decap(ctI,dkR) in
  (* Full common key derivations *)
   let K1 = kdf(s,kI) in
   let K2 = kdf(s,kR(j)) in
   let K3 = kdf(s,kT(j)) in

   let ST = <pk(dkI),<pk(dkR),<ctI,<pk(ekT),<ctR,ctT>>>>> in
   let SK = xor(G(ST,K2), xor( G(ST,K1), G(ST,K3))) in

   out(cI,diff(kIR(j),SK)).

system [rorR] out(cI,s); ((!_j R: Responder5(j)) | (!_i I: Initiator4(i))).

axiom [rorR] len_G2 (x1,x2:message) : len(G(x1,x2)) = len(s).

axiom [rorR] len_xor2 (x1,x2:message) : len(x1) = len(x2) => len(xor(x1,x2)) = len(x1).

 set timeout = 10.

equiv [rorR] rorR.
Proof.
 enrich pk(dkI); enrich pk(dkR); enrich s;
 enrich seq(i-> kT(i)); enrich seq(i->rTI(i));
 enrich seq(i-> rR(i)); enrich seq(i->rI(i));
 enrich seq(i-> dkT(i)).
 induction t.

 expandall.
 fa 8.

 (* First output of R *)
 expandall.
 fa 8.
 fa 9.
 fa 9.
 fa 9.
 fa 9.
 fa 10.
 expandseq  seq(i-> kT(i)), j.
 expandseq  seq(i-> rTI(i)), j.
 expandseq  seq(i-> rR(i)), j.

 (* Second output of R *)
 expandall.
 fa 8.
 fa 9.

 fa 9.
 prf 9,  kdf(s,kR(j)).
 yesif 9.

 project.
 case H0.
   by depends R(j), R1(j).

 prf 9, G(<pk(dkI),
            <pk(dkR),
             <fst(input@R(j)),
              <pk(snd(input@R(j))),
               <encap(s,rR(j),pk(dkI)),wencap(kT(j),rTI(j),snd(input@R(j)))>>>>>,
         n_PRF).
 yesif 9.
 xor 9, n_PRF1.
 yesif 9.

 use len_xor2 with G(<pk(dkI),
         <pk(dkR),
          <fst(input@R(j)),
           <pk(snd(input@R(j))),
            <encap(s,rR(j),pk(dkI)),wencap(kT(j),rTI(j),snd(input@R(j)))>>>>>,
      kdf(s,decap(fst(input@R(j)),dkR))),
  G(<pk(dkI),
     <pk(dkR),
      <fst(input@R(j)),
       <pk(snd(input@R(j))),
        <encap(s,rR(j),pk(dkI)),wencap(kT(j),rTI(j),snd(input@R(j)))>>>>>,
  kdf(s,kT(j))).


 use len_G2 with <pk(dkI),
         <pk(dkR),
          <fst(input@R(j)),
           <pk(snd(input@R(j))),
            <encap(s,rR(j),pk(dkI)),wencap(kT(j),rTI(j),snd(input@R(j)))>>>>>,
      kdf(s,decap(fst(input@R(j)),dkR)).
 by namelength n_PRF1, s.

 use len_G2 with <pk(dkI),
     <pk(dkR),
      <fst(input@R(j)),
       <pk(snd(input@R(j))),
        <encap(s,rR(j),pk(dkI)),wencap(kT(j),rTI(j),snd(input@R(j)))>>>>>,
  kdf(s,decap(fst(input@R(j)),dkR))  .
 by use len_G2 with <pk(dkI),
     <pk(dkR),
      <fst(input@R(j)),
       <pk(snd(input@R(j))),
        <encap(s,rR(j),pk(dkI)),wencap(kT(j),rTI(j),snd(input@R(j)))>>>>>,
  kdf(s,kT(j)).

  fresh 9.
  yesif 9.


 (* First output of I *)
  expandall.
  fa 8.
  fa 9.
  fa 9.
  fa 9.
  fa 9.
  fa 10.
  expandseq  seq(i-> rI(i)), i.
  expandseq seq(i-> dkT(i)),i.

 (* Second output of I *)
 expandall.
 fa 8.

Qed.
