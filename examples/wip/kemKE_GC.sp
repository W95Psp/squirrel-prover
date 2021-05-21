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

# Protocol parameters

Two KEMs Pk Encap DeCap, and wPk wEncap wDeCap

PRFs : F, F' and G
KDF: KDF with public random salt s

Two parties I (initiator) and R (responder)

Public identities I and R
Static keys for party X := dkX, skX, sk2X
Public keys for party X : ekX = pk(dkX)


# Protocol description

I:
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


I:
kR := Decap(ctR,dkI)
kT := wDecap(ctT,dkT)

R:
kI := Decap(ctI,dkI)

Boths:

K1 := KDF(s,kI); K2 := KDF(s,kR); K3 := KDF(s,kT)

ST := (I,R,pk(dkI),pk(dkR),ctI,pk(ekT),ctR,ctT)
SK := G(ST,K1) XOR G(ST,K2) XOR G(ST,K3)


# High level intuitions

kI is a fresh key, generated by I and sent to R via Encap using the longterm public key of R
kR is a fresh key, generated by R and sent to I via Encap using the longterm public key of I
dkT is a fresh enc key generated by I, kT is a fesh key generated by R and sent via wEncap using the ephemrak pub key pk(dkT) to I.




*******************************************************************************)

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



(* session randomess of R *)
name kR : index->message
name rR : index->message
name rR2 : index->message
name rTI : index->message
name kT : index->message



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

 (* dummy conclusion *)
 out(cI,s)




process Responder(j:index) =
   in(cI, messR);
   let ctI = fst(messR) in
   let ekT = snd(messR) in

   let ctR = encap(kR(j), F(rR(j),skR) XOR F(sk2R,rR2(j)), pk(dkI)) in (* we hardcode the public key of I here, we need to add in parallel the responder that wants to talk to anybody *)
   let ctT = wencap(kT(j),rTI(j),ekT) in
   out(cR,<ctR,ctT>);

   let kI = decap(ctI,dkR) in

 out(cR,s)

system out(cI,s); ((!_j R: Responder(j)) | (!_i I: Initiator(i))).

(* Authentication goal for the action R (then branch of the reader) *)