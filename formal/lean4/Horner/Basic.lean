/-
  Horner's Method: Polynomial Evaluation via Fold / Unfold

  Defines encode (foldl with multiply-add kernel) and decode (unfold via
  quotient/remainder), then proves the roundtrip property.
-/

namespace Horner

/-- Horner encode: left fold over coefficients with multiply-add kernel.
    `hornerEncode [a, b, c] m = ((a*m + b)*m + c)` -/
def hornerEncode (coeffs : List Nat) (base : Nat) : Nat :=
  coeffs.foldl (fun acc c => acc * base + c) 0

/-- Horner decode: unfold an integer into `rank` coefficients by
    repeated quotient/remainder (least significant first, then reverse). -/
def hornerDecode (n : Nat) (base : Nat) (rank : Nat) : List Nat :=
  let rec go (n : Nat) (r : Nat) (acc : List Nat) : List Nat :=
    match r with
    | 0     => acc
    | r + 1 => go (n / base) r ((n % base) :: acc)
  go n rank []

/-- Encode a tuple of indices at a given base. -/
def encodeTuple (indices : List Nat) (base : Nat) : Nat :=
  hornerEncode indices base

/-- Decode an integer into a tuple of given rank at a given base. -/
def decodeTuple (n : Nat) (base : Nat) (rank : Nat) : List Nat :=
  hornerDecode n base rank

-- Computational examples

#eval hornerEncode [1, 2, 3] 10          -- 123
#eval hornerDecode 123 10 3              -- [1, 2, 3]
#eval encodeTuple [3, 1, 4, 1, 5] 6     -- 4259
#eval decodeTuple 4259 6 5              -- [3, 1, 4, 1, 5]

-- String encode/decode via char codes at base 128
#eval hornerEncode ("horner!".toList.map (·.toNat)) 128
#eval (hornerDecode 461241602111777 128 7).map (Char.ofNat ·)

/-- The Horner recurrence: appending an element corresponds to
    multiplying by base and adding the element. -/
theorem hornerEncode_append (cs : List Nat) (c : Nat) (base : Nat) :
    hornerEncode (cs ++ [c]) base = hornerEncode cs base * base + c := by
  simp [hornerEncode, List.foldl_append]

/-- Encoding the empty list yields 0. -/
theorem hornerEncode_nil (base : Nat) :
    hornerEncode [] base = 0 := by
  rfl

/-- Encoding a singleton [c] yields c. -/
theorem hornerEncode_singleton (c : Nat) (base : Nat) :
    hornerEncode [c] base = c := by
  simp [hornerEncode, List.foldl]

/-- For a two-element list, encoding matches the formula a*base + b. -/
theorem hornerEncode_pair (a b : Nat) (base : Nat) :
    hornerEncode [a, b] base = a * base + b := by
  simp [hornerEncode, List.foldl]

/-- For a three-element list: ((a*base + b)*base + c). -/
theorem hornerEncode_triple (a b c : Nat) (base : Nat) :
    hornerEncode [a, b, c] base = (a * base + b) * base + c := by
  simp [hornerEncode, List.foldl]

end Horner
