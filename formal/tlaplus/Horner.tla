---------------------------- MODULE Horner ----------------------------
(*
 * Horner's Method: Polynomial Evaluation via Fold / Unfold
 *
 * Models the encode (fold) and decode (unfold) operations and verifies
 * the roundtrip property: decode(encode(coeffs, base), base, |coeffs|) = coeffs.
 *
 * The encode operation is a left fold with kernel: acc * base + element.
 * The decode operation is an unfold via repeated quotient/remainder.
 *)

EXTENDS Integers, Sequences, FiniteSets, TLC

CONSTANTS Base, MaxLen

ASSUME Base \in Nat \ {0, 1}
ASSUME MaxLen \in Nat \ {0}

(*
 * Horner encode: fold a sequence of coefficients into a single integer.
 * HornerEncode(<<a, b, c>>, m) = ((a*m + b)*m + c)
 *)
RECURSIVE HornerEncode(_, _)
HornerEncode(coeffs, base) ==
    IF Len(coeffs) = 0 THEN 0
    ELSE HornerEncode(SubSeq(coeffs, 1, Len(coeffs) - 1), base) * base
         + coeffs[Len(coeffs)]

(*
 * Horner decode: unfold an integer into a sequence of coefficients.
 * HornerDecode(n, base, rank) produces <<c1, c2, ..., c_rank>>
 * where coefficients are extracted most-significant first.
 *)
RECURSIVE HornerDecode(_, _, _)
HornerDecode(n, base, rank) ==
    IF rank = 0 THEN <<>>
    ELSE Append(HornerDecode(n \div base, base, rank - 1), n % base)

(* State variable — single step model *)
VARIABLE checked

(* AllCoeffs: the set of all coefficient sequences up to MaxLen *)
AllCoeffs == UNION { [1..k -> 0..(Base - 1)] : k \in 1..MaxLen }

(* Initial state: evaluate all properties *)
Init ==
    /\ checked = "init"
    (* Example checks — evaluated at init via ASSUME *)
    /\ PrintT(<<"encode [1,2,3] base 10 =", HornerEncode(<<1, 2, 3>>, 10)>>)
    /\ PrintT(<<"decode 123 base 10 rank 3 =", HornerDecode(123, 10, 3)>>)

(* Terminal — no further states *)
Next == UNCHANGED checked

Spec == Init /\ [][Next]_checked

(*
 * The central roundtrip property:
 * For any valid coefficient sequence, decode(encode(s, b), b, |s|) = s.
 *)
RoundtripInv ==
    \A coeffs \in AllCoeffs :
        HornerDecode(HornerEncode(coeffs, Base), Base, Len(coeffs)) = coeffs

(*
 * Encoding is non-negative for valid coefficients.
 *)
EncodeNonNegInv ==
    \A coeffs \in AllCoeffs :
        HornerEncode(coeffs, Base) >= 0

(*
 * Encoding is injective: distinct same-length coefficient sequences
 * produce distinct encoded values.
 *)
EncodeInjectiveInv ==
    \A s1, s2 \in AllCoeffs :
        (Len(s1) = Len(s2) /\ HornerEncode(s1, Base) = HornerEncode(s2, Base))
            => s1 = s2

(*
 * Concrete example assertions — checked at ASSUME time.
 *)
ASSUME HornerEncode(<<1, 2, 3>>, 10) = 123
ASSUME HornerEncode(<<3, 1, 4, 1, 5>>, 6) = 4259
ASSUME HornerDecode(123, 10, 3) = <<1, 2, 3>>
ASSUME HornerDecode(4259, 6, 5) = <<3, 1, 4, 1, 5>>

=======================================================================
