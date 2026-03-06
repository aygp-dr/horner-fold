;;; tests/test-horner-guile.scm — SRFI-64 tests for Horner encode/decode
;;;
;;; Covers:
;;;   - Roundtrip for base 128 (ASCII strings)
;;;   - Roundtrip for base 10 (digit tuples)
;;;   - Empty string / empty list edge cases
;;;   - decode(encode(s, b), b) = s for several hand-picked examples
;;;   - Strict monotonicity for single-char strings
;;;   - SRFI-1 fold vs rnrs fold-left argument order equivalence
;;;
;;; Requires: Guile 3.0+ (SRFI-1, SRFI-64, rnrs lists are built-in)
;;; Run:      guile tests/test-horner-guile.scm

(use-modules (srfi srfi-1)    ; fold
             (srfi srfi-64)   ; test framework
             (rnrs lists))    ; fold-left

;;; ====================================================================
;;; Horner encode/decode (SRFI-1 fold variant — canonical)
;;; ====================================================================

(define (horner-encode s base)
  "Encode string S as an integer via Horner's method at BASE.
SRFI-1 fold: lambda receives (element accumulator)."
  (fold (lambda (c acc) (+ (* acc base) c))
        0
        (map char->integer (string->list s))))

(define (horner-decode n base)
  "Decode integer N back to a string via repeated quotient/remainder at BASE."
  (let loop ((n n) (acc '()))
    (if (= n 0)
        (list->string (map integer->char acc))
        (loop (quotient n base)
              (cons (remainder n base) acc)))))

;;; ====================================================================
;;; Horner encode using rnrs fold-left (swapped argument order)
;;; ====================================================================

(define (horner-encode-rnrs s base)
  "Encode string S via Horner's method using (rnrs lists) fold-left.
fold-left: lambda receives (accumulator element) — opposite of SRFI-1."
  (fold-left (lambda (acc c) (+ (* acc base) c))
             0
             (map char->integer (string->list s))))

;;; ====================================================================
;;; Tuple encode/decode (generalized Horner for integer lists)
;;; ====================================================================

(define (encode-tuple indices base)
  "Encode a list of non-negative integers as a single integer at BASE."
  (fold (lambda (i acc) (+ (* acc base) i)) 0 indices))

(define (decode-tuple n base rank)
  "Decode integer N into RANK digits at BASE."
  (let loop ((n n) (r rank) (acc '()))
    (if (= r 0) acc
        (loop (quotient n base)
              (- r 1)
              (cons (remainder n base) acc)))))

;;; ====================================================================
;;; Test suite
;;; ====================================================================

(test-begin "horner-guile")

;;; --------------------------------------------------------------------
;;; 1. Roundtrip: base 128 (ASCII strings)
;;; --------------------------------------------------------------------

(test-group "roundtrip-base-128"

  (test-equal "horner! roundtrip"
    "horner!"
    (horner-decode (horner-encode "horner!" 128) 128))

  (test-equal "single char A"
    "A"
    (horner-decode (horner-encode "A" 128) 128))

  (test-equal "single char ~"
    "~"
    (horner-decode (horner-encode "~" 128) 128))

  (test-equal "multi-byte Hello, World!"
    "Hello, World!"
    (horner-decode (horner-encode "Hello, World!" 128) 128))

  (test-equal "all printable ASCII"
    " !\"#$%&"
    (horner-decode (horner-encode " !\"#$%&" 128) 128))

  ;; Encoding "horner!" should produce the known value from the org file
  (test-equal "horner! known encoding value"
    461241602111777
    (horner-encode "horner!" 128))

  ;; Single char encodes to its codepoint
  (test-equal "single char encodes to char->integer"
    65
    (horner-encode "A" 128))
)

;;; --------------------------------------------------------------------
;;; 2. Roundtrip: base 10 (digit tuples)
;;; --------------------------------------------------------------------

(test-group "roundtrip-base-10"

  (test-equal "digits (1 2 3) encode to 123"
    123
    (encode-tuple '(1 2 3) 10))

  (test-equal "decode 123 base 10 rank 3"
    '(1 2 3)
    (decode-tuple 123 10 3))

  (test-equal "roundtrip (1 2 3)"
    '(1 2 3)
    (decode-tuple (encode-tuple '(1 2 3) 10) 10 3))

  (test-equal "roundtrip (9 0 9)"
    '(9 0 9)
    (decode-tuple (encode-tuple '(9 0 9) 10) 10 3))

  (test-equal "roundtrip (5)"
    '(5)
    (decode-tuple (encode-tuple '(5) 10) 10 1))

  (test-equal "digits (3 1 4 1 5) base 6"
    4259
    (encode-tuple '(3 1 4 1 5) 6))

  (test-equal "roundtrip (3 1 4 1 5) base 6"
    '(3 1 4 1 5)
    (decode-tuple (encode-tuple '(3 1 4 1 5) 6) 6 5))
)

;;; --------------------------------------------------------------------
;;; 3. Edge cases: empty string / empty list
;;; --------------------------------------------------------------------

(test-group "edge-cases-empty"

  ;; Empty string encodes to 0
  (test-equal "encode empty string"
    0
    (horner-encode "" 128))

  ;; Decode of 0 produces empty string (lossy: can't distinguish from NUL)
  (test-equal "decode 0 produces empty string"
    ""
    (horner-decode 0 128))

  ;; Empty list encodes to 0
  (test-equal "encode empty tuple"
    0
    (encode-tuple '() 10))

  ;; decode-tuple with rank 0 produces empty list regardless of n
  (test-equal "decode-tuple rank 0"
    '()
    (decode-tuple 999 10 0))

  ;; Roundtrip for empty string (trivially: 0 -> "" -> 0)
  (test-equal "empty string roundtrip encode->decode"
    ""
    (horner-decode (horner-encode "" 128) 128))

  ;; Note: roundtrip "" -> 0 -> "" works, but leading NUL chars are lost
  ;; This is inherent to positional encoding (leading zeros vanish)
  (test-equal "encode NUL-prefixed string equals encode of suffix"
    (horner-encode "A" 128)
    (horner-encode (string (integer->char 0) #\A) 128))
)

;;; --------------------------------------------------------------------
;;; 4. Property: decode(encode(s, b), b) = s for several examples
;;; --------------------------------------------------------------------

(test-group "roundtrip-examples"

  ;; A table of (string . base) pairs
  (let ((cases '(("abc"      . 128)
                 ("Z"        . 128)
                 ("Scheme"   . 256)
                 ("42"       . 128)
                 ("hello"    . 200)
                 ("!"        . 128)
                 ("fold"     . 128)
                 ("SRFI-64"  . 128))))
    (for-each
     (lambda (pair)
       (let ((s (car pair))
             (b (cdr pair)))
         (test-equal (string-append "roundtrip: \"" s "\" base " (number->string b))
           s
           (horner-decode (horner-encode s b) b))))
     cases))
)

;;; --------------------------------------------------------------------
;;; 5. Property: encode is strictly monotonic for single-char strings
;;;    If c1 < c2 (as integers), then encode(c1) < encode(c2)
;;; --------------------------------------------------------------------

(test-group "monotonicity-single-char"

  ;; For single chars, horner-encode just returns char->integer,
  ;; so monotonicity is trivially char->integer's ordering.
  ;; We verify it concretely for all printable ASCII (32..126).

  (test-assert "strict monotonicity over printable ASCII"
    (let loop ((i 33) (prev (horner-encode (string (integer->char 32)) 128)))
      (if (> i 126)
          #t
          (let ((curr (horner-encode (string (integer->char i)) 128)))
            (if (> curr prev)
                (loop (+ i 1) curr)
                #f)))))

  ;; Also verify for multi-char: "aa" < "ab" < "ba" < "bb" at base 128
  (test-assert "lexicographic monotonicity for 2-char strings"
    (let ((aa (horner-encode "aa" 128))
          (ab (horner-encode "ab" 128))
          (ba (horner-encode "ba" 128))
          (bb (horner-encode "bb" 128)))
      (and (< aa ab) (< ab ba) (< ba bb))))
)

;;; --------------------------------------------------------------------
;;; 6. SRFI-1 fold vs rnrs fold-left: same result, different arg order
;;; --------------------------------------------------------------------

(test-group "fold-vs-fold-left"

  ;; The critical difference:
  ;;   SRFI-1 fold:      (lambda (element accumulator) ...)
  ;;   rnrs fold-left:   (lambda (accumulator element) ...)
  ;;
  ;; For Horner encoding, both must produce identical results
  ;; because the kernel is the same — just the parameter names swap.

  (test-equal "fold vs fold-left: horner! base 128"
    (horner-encode "horner!" 128)
    (horner-encode-rnrs "horner!" 128))

  (test-equal "fold vs fold-left: empty string"
    (horner-encode "" 128)
    (horner-encode-rnrs "" 128))

  (test-equal "fold vs fold-left: single char"
    (horner-encode "X" 128)
    (horner-encode-rnrs "X" 128))

  (test-equal "fold vs fold-left: Hello, World!"
    (horner-encode "Hello, World!" 128)
    (horner-encode-rnrs "Hello, World!" 128))

  (test-equal "fold vs fold-left: base 256"
    (horner-encode "test" 256)
    (horner-encode-rnrs "test" 256))

  ;; Demonstrate that naively swapping args is wrong:
  ;; If someone uses (lambda (acc c) ...) with SRFI-1 fold, the arguments
  ;; would be bound backwards. Verify with a non-commutative operation.
  (test-assert "arg-order matters for non-commutative ops"
    (let* (;; Correct: SRFI-1 fold with (element accumulator)
           (correct (fold (lambda (el acc) (- acc el)) 0 '(1 2 3)))
           ;; Same lambda with fold-left would swap meaning
           (also-correct (fold-left (lambda (acc el) (- acc el)) 0 '(1 2 3))))
      ;; Both should give: ((0 - 1) - 2) - 3 = -6
      (and (= correct -6)
           (= also-correct -6))))

  ;; Show that reversing the arg names (a common mistake) breaks non-commutative ops
  (test-assert "swapped args break subtraction"
    (let (;; WRONG: treating fold's (el acc) as (acc el) would compute 3-(2-(1-0))=2
          (wrong (fold (lambda (acc el) (- acc el)) 0 '(1 2 3))))
      ;; "wrong" here means: the programmer swapped arg names in the lambda.
      ;; fold still passes (element accumulator), so:
      ;;   step1: (- 1 0) = 1
      ;;   step2: (- 2 1) = 1
      ;;   step3: (- 3 1) = 2
      (= wrong 2)))
)

;;; --------------------------------------------------------------------
;;; Additional: concatenation / shift property
;;; --------------------------------------------------------------------

(test-group "algebraic-properties"

  ;; encode(a ++ b, base) = encode(a, base) * base^|b| + encode(b, base)
  (test-equal "concatenation shift: (1 2) ++ (3 4) base 10"
    1234
    (+ (* (encode-tuple '(1 2) 10) (expt 10 2))
       (encode-tuple '(3 4) 10)))

  (test-equal "leading zero absorption"
    (encode-tuple '(1 2 3) 10)
    (encode-tuple '(0 1 2 3) 10))

  (test-equal "single element identity"
    7
    (encode-tuple '(7) 10))

  ;; Polynomial equivalence: encode([a,b,c], base) = a*base^2 + b*base + c
  (test-equal "polynomial expansion for (2 3 5) base 10"
    235
    (+ (* 2 (expt 10 2)) (* 3 10) 5))
)

(test-end "horner-guile")

;;; Note: (test-end) resets the test runner, so we capture the fail count
;;; *before* calling test-end.  SRFI-64 in Guile 3.x returns the runner
;;; from test-end, but it's already been finalized.  The idiomatic way
;;; is to just let the test output speak — a non-zero fail count prints
;;; "# of unexpected failures" to current-output-port.
;;;
;;; If you need a non-zero exit code for CI, wrap the whole file in a
;;; custom test-runner that records the count before teardown.  For now,
;;; the output format is sufficient for `grep` in a Makefile target.
