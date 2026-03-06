#lang racket/base

;;; Test suite for horner-racket.rkt
;;; Run with: raco test tests/test-horner-racket.rkt

(require rackunit
         rackunit/text-ui
         threading)

;; ---------------------------------------------------------------------------
;; Functions under test (inlined to keep this file standalone)
;; ---------------------------------------------------------------------------

(define (horner-encode s base)
  (foldl (lambda (c acc) (+ (* acc base) c))
         0
         (map char->integer (string->list s))))

(define (horner-encode/for s base)
  (for/fold ([acc 0])
            ([c (map char->integer (string->list s))])
    (+ (* acc base) c)))

(define (horner-decode n base)
  (let loop ([n n] [acc '()])
    (if (= n 0)
        (list->string (map integer->char acc))
        (loop (quotient n base)
              (cons (remainder n base) acc)))))

(define (horner-encode/threaded s base)
  (~> s
      string->list
      (map char->integer _)
      (foldl (lambda (c acc) (+ (* acc base) c)) 0 _)))

(define (encode-tuple indices base)
  (foldl (lambda (i acc) (+ (* acc base) i)) 0 indices))

(define (decode-tuple n base rank)
  (let loop ([n n] [r rank] [acc '()])
    (if (= r 0) acc
        (loop (quotient n base)
              (- r 1)
              (cons (remainder n base) acc)))))

;; ---------------------------------------------------------------------------
;; Helpers
;; ---------------------------------------------------------------------------

(define (random-ascii-string max-len)
  "Generate a non-empty string of printable ASCII chars (code-points 1..127)."
  (let* ([len (+ 1 (random max-len))]
         [chars (for/list ([_ (in-range len)])
                  (integer->char (+ 1 (random 126))))])
    (list->string chars)))

(define (random-tuple max-rank base)
  "Generate a non-empty list of ints in [0, base)."
  (let ([rank (+ 1 (random max-rank))])
    (for/list ([_ (in-range rank)])
      (random base))))

;; Number of trials for property-style tests
(define N 200)

;; ---------------------------------------------------------------------------
;; Test suites
;; ---------------------------------------------------------------------------

(define roundtrip-tests
  (test-suite
   "Roundtrip encode/decode"

   (test-case "roundtrip for 'horner!' base 128"
     (let* ([base 128]
            [s "horner!"]
            [n (horner-encode s base)])
       (check-true (> n 0) "encoding should be positive")
       (check-equal? (horner-decode n base) s)))

   (test-case "roundtrip for single character"
     (for ([c (in-range 1 128)])
       (let ([s (string (integer->char c))])
         (check-equal? (horner-decode (horner-encode s 128) 128) s
                       (format "roundtrip failed for char ~a" c)))))

   (test-case "roundtrip random strings base 128 (property)"
     (for ([_ (in-range N)])
       (let* ([s (random-ascii-string 15)]
              [n (horner-encode s 128)])
         (check-equal? (horner-decode n 128) s))))

   (test-case "roundtrip random strings random base (property)"
     (for ([_ (in-range N)])
       (let* ([base (+ 128 (random 128))]
              [s (random-ascii-string 15)]
              [n (horner-encode s base)])
         (check-equal? (horner-decode n base) s))))))

(define equivalence-tests
  (test-suite
   "Equivalence of foldl, for/fold, and threading"

   (test-case "foldl vs for/fold on 'horner!'"
     (check-equal? (horner-encode "horner!" 128)
                   (horner-encode/for "horner!" 128)))

   (test-case "foldl vs threading (~>) on 'horner!'"
     (check-equal? (horner-encode "horner!" 128)
                   (horner-encode/threaded "horner!" 128)))

   (test-case "all three agree on random strings (property)"
     (for ([_ (in-range N)])
       (let* ([base (+ 128 (random 128))]
              [s (random-ascii-string 12)]
              [v-foldl   (horner-encode s base)]
              [v-for     (horner-encode/for s base)]
              [v-thread  (horner-encode/threaded s base)])
         (check-equal? v-foldl v-for
                       (format "foldl vs for/fold disagree on ~s base ~a" s base))
         (check-equal? v-foldl v-thread
                       (format "foldl vs ~> disagree on ~s base ~a" s base)))))))

(define edge-case-tests
  (test-suite
   "Edge cases"

   (test-case "empty string encodes to 0"
     (check-equal? (horner-encode "" 128) 0))

   (test-case "single char encodes to its code-point"
     (check-equal? (horner-encode "A" 128) (char->integer #\A))
     (check-equal? (horner-encode "A" 256) (char->integer #\A)))

   (test-case "base-10 tuple sanity"
     (check-equal? (encode-tuple '(1 2 3) 10) 123)
     (check-equal? (encode-tuple '(3 1 4 1 5) 6) 4259)
     (check-equal? (encode-tuple '(0 0 0) 10) 0))

   (test-case "tuple roundtrip (no leading zeros)"
     (for ([_ (in-range N)])
       (let* ([base (+ 2 (random 50))]
              [t (random-tuple 6 base)])
         (unless (= (car t) 0)
           (check-equal? (decode-tuple (encode-tuple t base) base (length t))
                         t)))))

   (test-case "leading-zero absorption"
     (for ([_ (in-range N)])
       (let* ([base (+ 2 (random 50))]
              [t (random-tuple 4 base)])
         (check-equal? (encode-tuple (cons 0 t) base)
                       (encode-tuple t base)))))))

(define ordering-tests
  (test-suite
   "Lexicographic ordering preservation"

   (test-case "encoding preserves lex order for same-length strings"
     ;; For strings of equal length, Horner encoding with base >= 128
     ;; preserves lexicographic (string<?) ordering.
     (for ([_ (in-range N)])
       (let* ([base 128]
              [len (+ 1 (random 8))]
              [s1 (let ([chars (for/list ([_ (in-range len)])
                                 (integer->char (+ 1 (random 126))))])
                    (list->string chars))]
              [s2 (let ([chars (for/list ([_ (in-range len)])
                                 (integer->char (+ 1 (random 126))))])
                    (list->string chars))]
              [n1 (horner-encode s1 base)]
              [n2 (horner-encode s2 base)])
         (cond
           [(string<? s1 s2) (check-true (< n1 n2)
                                         (format "~s < ~s but ~a >= ~a" s1 s2 n1 n2))]
           [(string>? s1 s2) (check-true (> n1 n2)
                                         (format "~s > ~s but ~a <= ~a" s1 s2 n1 n2))]
           [else             (check-equal? n1 n2)]))))

   (test-case "monotone in last element"
     (for ([_ (in-range N)])
       (let* ([base (+ 3 (random 50))]
              [prefix (random-tuple 3 base)]
              [a (random (- base 1))]
              [b (+ a 1 (random (- base a 1)))])
         (when (< a b)
           (check-true (< (encode-tuple (append prefix (list a)) base)
                          (encode-tuple (append prefix (list b)) base)))))))))

(define algebraic-tests
  (test-suite
   "Algebraic properties"

   (test-case "polynomial equivalence: Horner vs naive expansion"
     (for ([_ (in-range N)])
       (let* ([base (+ 2 (random 100))]
              [coeffs (random-tuple 4 base)]
              [horner-result (encode-tuple coeffs base)]
              [naive-result
               (for/fold ([sum 0])
                         ([c (in-list coeffs)]
                          [i (in-naturals)])
                 (+ sum (* c (expt base (- (length coeffs) 1 i)))))])
         (check-equal? horner-result naive-result))))

   (test-case "concatenation/shift property"
     ;; encode(a ++ b, base) == encode(a, base) * base^|b| + encode(b, base)
     (for ([_ (in-range N)])
       (let* ([base (+ 2 (random 50))]
              [a (random-tuple 3 base)]
              [b (random-tuple 3 base)]
              [ab (append a b)])
         (check-equal? (encode-tuple ab base)
                       (+ (* (encode-tuple a base) (expt base (length b)))
                          (encode-tuple b base))))))

   (test-case "single element encodes to itself"
     (for ([_ (in-range N)])
       (let* ([base (+ 2 (random 254))]
              [x (+ 1 (random (- base 1)))])
         (check-equal? (encode-tuple (list x) base) x))))

   (test-case "encoding is strictly positive for non-empty strings"
     (for ([_ (in-range N)])
       (let ([s (random-ascii-string 10)])
         (check-true (> (horner-encode s 256) 0)))))))

;; ---------------------------------------------------------------------------
;; Run
;; ---------------------------------------------------------------------------

(run-tests
 (test-suite
  "horner-racket"
  roundtrip-tests
  equivalence-tests
  edge-case-tests
  ordering-tests
  algebraic-tests))
