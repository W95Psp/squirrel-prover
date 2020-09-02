(*******************************************************************************
SIGNED DDH

[G] ISO/IEC 9798-3:2019, IT Security techniques – Entity authentication –
Part 3: Mechanisms using digital signature techniques.

P -> S : g^a
S -> P : <g^a,g^b>,h(<g^a,g^b>,kS)
P -> S : h(<g^a,g^b>,kP)

We leverage the composition result, to prove a single session in the
presence of an adversary with access to a "backdoor" about the signature
function, which allows him to about signatures of some specific messages.

The proof is split into two systems, one modelling the authentication property,
and the other the strong secrecy. Put together, they allow to derive very simply
the actual assumption needed to apply the composition theorem.
*******************************************************************************)


abstract ok : message
abstract ko : message

name kP : message
name kS : message

channel cP
channel cS


name a1 : message
name b1 : message
name k11 : message
name a : index -> message
name b : index -> message
name k : index -> index -> message

axiom DDHgroup : forall (x1,x2:message), x1 <> x2 => g^x1 <> g^x2

signature sign,checksign,pk with oracle forall (m:message,sk:message)
 (sk <> kP || exists (i:index, x1:message, x2:message) m=<<x1,g^a(i)>,x2> )
  &&
 (sk <> kS || exists (i:index, x1:message, x2:message) m=<<x1,g^b(i)>,x2>)

hash h

process P =
  out(cP, <pk(kP),g^a1>);
  in(cP, t);
  let gS = snd(fst(t)) in
  let pkS = fst(fst(t)) in
  if checksign(snd(t),pkS) = <<g^a1,gS>,pk(kP)> then
    out(cP,sign(<<gS,g^a1>,pkS>,kP));
    in(cP, challenge);
    if pkS= pk(kS) then
      if snd(fst(t)) = g^b1 then
        out(cP, ok)
      else
      (try find j such that snd(fst(t)) = g^b(j) in
        out(cP, ok)
      else
       out(cP, diff(ok,ko))
       )


process S =
  in(cS, sP);
  let gP = snd(sP) in
  let pkP = fst(sP) in
  out(cS, < <pk(kS),g^b1>, sign(<<gP,g^b1>,pkP>,kS)>);
  in(cS, signed);
  if checksign(signed,pkP) = <<g^b1,gP>,pk(kS)> then
    out(cS,ok);
    in(cS, challenge);
    if pkP=pk(kP) then
     (if gP = g^a1 then
      out(cS, ok)
      else
       (try find l such that gP = g^a(l) in
          out(cS, ok)
	else
    	  out(cS, diff(ok,ko))
	 )
       )
     else null

system [auth] ( P | S).


process P2 =
  out(cP, <pk(kP),g^a1>);
  in(cP, t);
  let gS = snd(fst(t)) in
  let pkS = fst(fst(t)) in

  if checksign(snd(t),pkS) = <<g^a1,gS>,pk(kP)> then
    out(cP,sign(<<gS,g^a1>,pkS>,kP));
    in(cP, challenge);
    if pkS= pk(kS) then
      if snd(fst(t)) = g^b1 then
         out(cP, diff(g^a1^b1,g^k11))
      else
      (try find j such that snd(fst(t)) = g^b(j) in
         out(cP, g^a1^b(j)))

process S2 =
	in(cS, sP);
	let gP = snd(sP) in
	let pkP = fst(sP) in
	out(cS, < <pk(kS),g^b1>, sign(<<gP,g^b1>,pkP>,kS)>);
	in(cS, signed);
        if checksign(signed,pkP) = <<g^b1,gP>,pk(kS)> then
	out(cS,ok);
	in(cS, challenge);
	if pkP=pk(kP) then
          if gP = g^a1 then
            out(cS, diff(g^a1^b1,g^k11))
          else
            (try find l such that gP = g^a(l) in
               out(cP, g^b1^a(l)))

system [secret] ( P2 | S2).


(** Prove that the condition above the only diff term inside S is never true. **)
goal [none, auth] S1_charac :
  cond@S1 => (cond@S4 => False) .
Proof.
  simpl.
  nosimpl(expand cond@S1; expand cond@S4; simpl).
  expand pkP@S1.
  substitute fst(input@S), pk(kP).
  euf M1.

  case H2.
  apply H1 to i.

  notleft H0.
Qed.

(** Prove that the condition above the only diff term inside P is never true. **)
goal [none, auth] P1_charac :
   cond@P1 => (cond@P4 => False).
Proof.
  simpl.
  nosimpl(expand cond@P1; expand cond@P4; simpl).
  substitute pkS@P1,pk(kS).
  euf M1.

  case H3.
  apply H1 to i.

  notleft H0.
Qed.

(** The strong secrecy is directly obtained through ddh. *)
equiv [left,secret] [right,secret] secret.
Proof.
   ddh a1, b1, k11.
Qed.

(** The equivalence for authentication is obtained by using the unreachability
proofs over the two actions. The rest of the protocol can be handled through
some simple enriching of the induction hypothesis, and then dup applications. *)

equiv [left, auth] [right, auth] auth.
Proof.
   enrich kP; enrich g^a1; enrich g^b1; enrich kS.
   enrich seq(i-> g^b(i)).    enrich seq(i-> g^a(i)).

   induction t.

   expandall.
   fa 6.

   expandall.
   fa 6.

   expandall.
   fa 6.

   expandall.
   expand seq(i->g^b(i)),j.
   fa 7.

   expand frame@P4; expand exec@P4.
   fa 6.

   equivalent exec@pred(P4) && cond@P4, False.
   executable pred(P4). depends P1, P4. apply H2 to P1. expand exec@P1. apply P1_charac.
   fa 7.
   noif 7.

   expandall.
   fa 6.

   expandall.
   fa 6.

   expandall.
   fa 6.

   expandall.
   fa 6.

   expandall.
   fa 6.

   expandall.
   expand seq(i->g^a(i)),l.
   fa 7.

   expand frame@S4; expand exec@S4.
   equivalent exec@pred(S4) && cond@S4, False.
   executable pred(S4). depends S1, S4. apply H2 to S1. expand exec@S1. apply S1_charac.

   fa 6. fa 7. noif 7.

   expandall.
   fa 6.

   expandall.
   fa 6.
Qed.