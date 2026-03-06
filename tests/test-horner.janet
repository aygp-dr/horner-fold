### tests/test-horner.janet -- Tests for horner.janet
### Run: janet tests/test-horner.janet
###
### Uses Janet's built-in assert macro. Janet also has (judge) in its
### test/judge module, but assert is simpler and zero-dep for standalone use.

# ----------------------------------------------------------------
# Functions under test (self-contained copy from horner.janet)
# ----------------------------------------------------------------

(def m 128)

(defn horner-encode [s base]
  (reduce (fn [acc c] (+ (* acc base) c))
          0
          (map (fn [c] c) (string/bytes s))))

(defn horner-encode/bytes [s base]
  (reduce (fn [acc b] (+ (* acc base) b))
          0
          (string/bytes s)))

(defn horner-decode [n base]
  (var n n)
  (def acc @[])
  (while (> n 0)
    (array/insert acc 0 (% n base))
    (set n (div n base)))
  (string/from-bytes ;acc))

(defn horner-encode/threaded [s base]
  (->> (string/bytes s)
       (reduce (fn [acc b] (+ (* acc base) b)) 0)))

# ----------------------------------------------------------------
# Test harness
# ----------------------------------------------------------------

(var pass-count 0)
(var fail-count 0)

(defn test-assert [name expr]
  (if expr
    (do (++ pass-count)
        (printf "  PASS: %s" name))
    (do (++ fail-count)
        (printf "  FAIL: %s" name))))

(defn test-equal [name expected actual]
  (if (= expected actual)
    (do (++ pass-count)
        (printf "  PASS: %s" name))
    (do (++ fail-count)
        (printf "  FAIL: %s -- expected %q, got %q" name expected actual))))

# ----------------------------------------------------------------
# String encode/decode roundtrip (base 128)
# ----------------------------------------------------------------

(print "\n# String roundtrip tests")

(test-assert "roundtrip: \"horner!\" at base 128"
  (let [n (horner-encode/bytes "horner!" m)]
    (and (number? n)
         (> n 0)
         (= "horner!" (horner-decode n m)))))

(test-assert "roundtrip: \"A\" at base 128"
  (= "A" (horner-decode (horner-encode/bytes "A" m) m)))

(test-assert "roundtrip: \"Hello, World!\" at base 128"
  (= "Hello, World!"
     (horner-decode (horner-encode/bytes "Hello, World!" m) m)))

(test-assert "roundtrip: \"abc\" at base 256"
  (= "abc" (horner-decode (horner-encode/bytes "abc" 256) 256)))

(test-assert "roundtrip: single space at base 128"
  (= " " (horner-decode (horner-encode/bytes " " m) m)))

# ----------------------------------------------------------------
# Known encoded value
# ----------------------------------------------------------------

(print "\n# Known value tests")

(test-assert "encode \"horner!\" produces positive integer"
  (> (horner-encode/bytes "horner!" m) 0))

# Compute expected: h=104, o=111, r=114, n=110, e=101, r=114, !=33
# 104*128^6 + 111*128^5 + 114*128^4 + 110*128^3 + 101*128^2 + 114*128 + 33
(test-equal "encode \"A\" = 65"
  65
  (horner-encode/bytes "A" m))

(test-equal "encode \"AB\" = 65*128 + 66 = 8386"
  8386
  (horner-encode/bytes "AB" m))

# ----------------------------------------------------------------
# horner-encode vs horner-encode/bytes equivalence
# ----------------------------------------------------------------

(print "\n# Encode variant equivalence")

# Note: horner-encode uses (map (fn [c] c) (string/bytes s)) which is
# equivalent to just (string/bytes s). The map with identity is a no-op
# since string/bytes already returns byte values (integers).
(test-equal "horner-encode == horner-encode/bytes for \"horner!\""
  (horner-encode "horner!" m)
  (horner-encode/bytes "horner!" m))

(test-equal "horner-encode == horner-encode/bytes for \"abc\""
  (horner-encode "abc" m)
  (horner-encode/bytes "abc" m))

(test-equal "horner-encode == horner-encode/bytes for \"A\""
  (horner-encode "A" m)
  (horner-encode/bytes "A" m))

# ----------------------------------------------------------------
# Threading macro equivalence
# ----------------------------------------------------------------

(print "\n# Threading macro (->>)")

(test-equal "->> threaded encode matches plain for \"horner!\""
  (horner-encode/bytes "horner!" m)
  (horner-encode/threaded "horner!" m))

(test-equal "->> threaded encode matches plain for \"abc\""
  (horner-encode/bytes "abc" m)
  (horner-encode/threaded "abc" m))

(test-equal "->> threaded encode matches plain for \"A\""
  (horner-encode/bytes "A" m)
  (horner-encode/threaded "A" m))

(test-equal "->> threaded encode matches plain for \"Hello, World!\""
  (horner-encode/bytes "Hello, World!" m)
  (horner-encode/threaded "Hello, World!" m))

# ----------------------------------------------------------------
# Edge cases
# ----------------------------------------------------------------

(print "\n# Edge cases")

# Empty string: reduce over empty tuple with init 0 returns 0
(test-equal "encode empty string = 0"
  0
  (horner-encode/bytes "" m))

# Decode 0: while loop never executes, array is empty, string/from-bytes
# with no args returns ""
(test-equal "decode 0 = empty string"
  ""
  (horner-decode 0 m))

# Empty roundtrip
(test-equal "roundtrip empty string"
  ""
  (horner-decode (horner-encode/bytes "" m) m))

# Single character: encode should equal the byte value
(test-equal "single char 'A' encodes to 65"
  65
  (horner-encode/bytes "A" m))

(test-equal "single char '!' encodes to 33"
  33
  (horner-encode/bytes "!" m))

(test-equal "single char '~' encodes to 126"
  126
  (horner-encode/bytes "~" m))

# Single character roundtrip
(test-assert "single char roundtrip: all printable ASCII"
  (all (fn [c]
         (let [s (string/from-bytes c)
               n (horner-encode/bytes s m)]
           (and (= c n)
                (= s (horner-decode n m)))))
       (range 33 127)))

# ----------------------------------------------------------------
# string/from-bytes splice syntax
# ----------------------------------------------------------------

(print "\n# Splice syntax verification")

# Verify that (string/from-bytes ;acc) works correctly:
# The ; in Janet is the splice operator. When acc is @[72 73],
# (string/from-bytes ;acc) expands to (string/from-bytes 72 73) => "HI"
(test-equal "string/from-bytes with splice: @[72 73] => \"HI\""
  "HI"
  (let [acc @[72 73]]
    (string/from-bytes ;acc)))

(test-equal "string/from-bytes with splice: empty array => \"\""
  ""
  (let [acc @[]]
    (string/from-bytes ;acc)))

(test-equal "string/from-bytes with splice: single byte"
  "A"
  (let [acc @[65]]
    (string/from-bytes ;acc)))

# ----------------------------------------------------------------
# Polynomial / positional encoding
# ----------------------------------------------------------------

(print "\n# Positional encoding")

# Digits [1 2 3] in base 10 = 123
(test-equal "encode digits [1 2 3] base 10 = 123"
  123
  (reduce (fn [acc c] (+ (* acc 10) c)) 0 [1 2 3]))

# Binary [1 0 1 1] in base 2 = 11
(test-equal "encode bits [1 0 1 1] base 2 = 11"
  11
  (reduce (fn [acc c] (+ (* acc 2) c)) 0 [1 0 1 1]))

# Leading zeros are absorbed
(test-equal "leading zeros: [0 1 2 3] base 10 = [1 2 3] base 10"
  (reduce (fn [acc c] (+ (* acc 10) c)) 0 [1 2 3])
  (reduce (fn [acc c] (+ (* acc 10) c)) 0 [0 1 2 3]))

# ----------------------------------------------------------------
# Report
# ----------------------------------------------------------------

(print "")
(print "========================================")
(printf "Results: %d passed, %d failed, %d total"
        pass-count fail-count (+ pass-count fail-count))
(print "========================================")

(when (> fail-count 0)
  (os/exit 1))
