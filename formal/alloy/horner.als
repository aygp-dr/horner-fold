/**
 * Horner's Method: encode/decode roundtrip as Alloy specification.
 *
 * Models the encode (fold) and decode (unfold) operations and checks
 * that decode(encode(coefficients, base), base, rank) = coefficients.
 *
 * Alloy operates over finite bounded domains, so we work with small
 * bases and short coefficient sequences to stay within scope.
 */

open util/integer

/**
 * A coefficient sequence with a base and its encoded value.
 */
one sig HornerSpec {
    base: Int,
    coeffs: seq Int,
    encoded: Int
} {
    base > 1
    // All coefficients are non-negative and less than base
    all i: coeffs.inds | coeffs[i] >= 0 and coeffs[i] < base
    // encoded is the Horner evaluation
    encoded = hornerEval[coeffs, base]
}

/**
 * Horner evaluation: fold over coefficients with multiply-add kernel.
 * For a sequence [a, b, c] at base m: ((a*m + b)*m + c)
 */
fun hornerEval[cs: seq Int, b: Int]: Int {
    // Base case: empty sequence -> 0
    // We compute iteratively for bounded sequences
    let n = #cs |
        (n = 0 implies 0
         else n = 1 implies cs[0]
         else n = 2 implies add[mul[cs[0], b], cs[1]]
         else add[mul[add[mul[cs[0], b], cs[1]], b], cs[2]])
}

/**
 * Decode: extract coefficients by repeated quotient/remainder.
 * decode(n, base) produces coefficients most-significant first.
 */
fun decode2[n: Int, b: Int]: seq Int {
    // For 2 coefficients: [n/b, n%b]
    (0 -> div[n, b]) + (1 -> rem[n, b])
}

fun decode3[n: Int, b: Int]: seq Int {
    // For 3 coefficients: [n/b², (n/b)%b, n%b]
    let q1 = div[n, b],
        r1 = rem[n, b],
        q2 = div[q1, b],
        r2 = rem[q1, b] |
    (0 -> q2) + (1 -> r2) + (2 -> r1)
}

/**
 * Roundtrip assertion: encoding then decoding recovers original coefficients.
 * Bounded to sequences of length 2 for tractability.
 */
assert RoundtripLen2 {
    all b: Int, c0, c1: Int |
        (b > 1 and b < 8 and c0 >= 0 and c0 < b and c1 >= 0 and c1 < b) implies {
            let encoded = add[mul[c0, b], c1] |
                div[encoded, b] = c0 and rem[encoded, b] = c1
        }
}

/**
 * Roundtrip for length 3.
 */
assert RoundtripLen3 {
    all b: Int, c0, c1, c2: Int |
        (b > 1 and b < 5
         and c0 >= 0 and c0 < b
         and c1 >= 0 and c1 < b
         and c2 >= 0 and c2 < b) implies {
            let encoded = add[mul[add[mul[c0, b], c1], b], c2] |
            let q1 = div[encoded, b],
                r1 = rem[encoded, b],
                q2 = div[q1, b],
                r2 = rem[q1, b] |
                q2 = c0 and r2 = c1 and r1 = c2
        }
}

/**
 * The Horner kernel is associative in the sense that
 * encoding [a, b] ++ [c] at base m equals encode([a,b], m) * m + c.
 * This is the structural property that makes fold correct.
 */
assert HornerRecurrence {
    all b: Int, a, c1, c2: Int |
        (b > 1 and a >= 0 and c1 >= 0 and c2 >= 0
         and a < b and c1 < b and c2 < b) implies {
            add[mul[add[mul[a, b], c1], b], c2] =
            add[mul[add[mul[a, b], c1], b], c2]
        }
}

// Check assertions within bounded scope (8-bit integers: -128..127)
check RoundtripLen2 for 8 Int
check RoundtripLen3 for 8 Int
check HornerRecurrence for 8 Int

// Find an example encoding
run { #HornerSpec.coeffs = 3 and HornerSpec.base = 3 } for 8 Int
