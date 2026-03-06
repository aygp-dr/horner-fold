import Horner

open Horner

def main : IO Unit := do
  -- Polynomial / tuple encoding
  IO.println s!"encode [1,2,3] base 10 = {hornerEncode [1, 2, 3] 10}"
  IO.println s!"decode 123 base 10 rank 3 = {hornerDecode 123 10 3}"

  -- String encoding at base 128
  let s := "horner!"
  let codes := s.toList.map (·.toNat)
  let n := hornerEncode codes 128
  IO.println s!"encode \"{s}\" base 128 = {n}"

  let decoded := (hornerDecode n 128 s.length).map (Char.ofNat ·)
  let s' := String.mk decoded
  IO.println s!"decode {n} base 128 rank {s.length} = \"{s'}\""

  -- Tuple examples
  IO.println s!"encode [3,1,4,1,5] base 6 = {encodeTuple [3, 1, 4, 1, 5] 6}"
  IO.println s!"decode 4259 base 6 rank 5 = {decodeTuple 4259 6 5}"
