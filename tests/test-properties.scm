(use-modules (srfi srfi-1)    ; fold
             (srfi srfi-27)   ; random-integer
             (srfi srfi-64))  ; test framework

;;; --- Horner encode/decode (from horner-guile.scm) ---

(define (horner-encode s base)
  (fold (lambda (c acc) (+ (* acc base) c))
        0
        (map char->integer (string->list s))))

(define (horner-decode n base)
  (let loop ((n n) (acc '()))
    (if (= n 0)
        (list->string (map integer->char acc))
        (loop (quotient n base)
              (cons (remainder n base) acc)))))

(define (encode-tuple indices base)
  (fold (lambda (i acc) (+ (* acc base) i)) 0 indices))

(define (decode-tuple n base rank)
  (let loop ((n n) (r rank) (acc '()))
    (if (= r 0) acc
        (loop (quotient n base)
              (- r 1)
              (cons (remainder n base) acc)))))

;;; --- Random generators ---

(random-source-randomize! default-random-source)

(define (random-ascii-string max-len)
  "Generate a non-empty string of printable ASCII chars (1-127)."
  (let* ((len (+ 1 (random-integer max-len)))
         (chars (map (lambda (_) (integer->char (+ 1 (random-integer 126))))
                     (iota len))))
    (list->string chars)))

(define (random-tuple max-rank base)
  "Generate a non-empty list of ints in [0, base)."
  (let ((rank (+ 1 (random-integer max-rank))))
    (map (lambda (_) (random-integer base)) (iota rank))))

;;; --- Property test runner ---

(define (check-property name n-trials thunk)
  "Run THUNK N-TRIALS times. THUNK should return #t on success."
  (test-assert name
    (let loop ((i 0))
      (cond
       ((= i n-trials) #t)
       ((thunk) (loop (+ i 1)))
       (else #f)))))

(define n-trials 1000)

;;; --- Properties ---

(test-begin "horner-properties")

;; Property 1: Roundtrip for strings
;; decode(encode(s, base), base) == s for non-empty s with chars in [1, base)
(check-property "roundtrip-string" n-trials
  (lambda ()
    (let* ((base (+ 128 (random-integer 128)))  ; base in [128, 256)
           (s (random-ascii-string 20))
           (encoded (horner-encode s base))
           (decoded (horner-decode encoded base)))
      (equal? s decoded))))

;; Property 2: Roundtrip for tuples
;; decode-tuple(encode-tuple(t, base), base, len(t)) == t
;; when first element > 0 (no leading zeros)
(check-property "roundtrip-tuple" n-trials
  (lambda ()
    (let* ((base (+ 2 (random-integer 50)))
           (t (random-tuple 8 base)))
      ;; Skip tuples with leading zero (encode loses that info)
      (if (= (car t) 0)
          #t  ; vacuously pass
          (equal? t (decode-tuple (encode-tuple t base) base (length t)))))))

;; Property 3: Single element encodes to itself
;; encode([x], base) == x for any x < base
(check-property "single-element-identity" n-trials
  (lambda ()
    (let* ((base (+ 2 (random-integer 254)))
           (x (+ 1 (random-integer (- base 1)))))
      (= x (encode-tuple (list x) base)))))

;; Property 4: Prepending a zero doesn't change the encoding
;; encode([0 | rest], base) == encode(rest, base)
;; (leading zeros are absorbed, like in positional notation)
(check-property "leading-zero-absorption" n-trials
  (lambda ()
    (let* ((base (+ 2 (random-integer 50)))
           (t (random-tuple 5 base)))
      (= (encode-tuple (cons 0 t) base)
         (encode-tuple t base)))))

;; Property 5: Polynomial evaluation matches naive expansion
;; encode([a, b, c], base) == a*base^2 + b*base + c
(check-property "polynomial-equivalence" n-trials
  (lambda ()
    (let* ((base (+ 2 (random-integer 100)))
           (coeffs (random-tuple 4 base))
           (horner-result (encode-tuple coeffs base))
           (naive-result
            (let ((len (length coeffs)))
              (fold (lambda (pair acc)
                      (+ acc (* (car pair)
                                (expt base (- len 1 (cdr pair))))))
                    0
                    (map cons coeffs (iota len))))))
      (= horner-result naive-result))))

;; Property 6: Encode is monotonically increasing in last element
;; encode([...prefix, a], base) < encode([...prefix, b], base) when a < b
(check-property "monotone-last-element" n-trials
  (lambda ()
    (let* ((base (+ 3 (random-integer 50)))
           (prefix (random-tuple 3 base))
           (a (random-integer (- base 1)))
           (b (+ a 1 (random-integer (- base a 1)))))
      (if (>= a b)
          #t  ; skip degenerate case
          (< (encode-tuple (append prefix (list a)) base)
             (encode-tuple (append prefix (list b)) base))))))

;; Property 7: Concatenation property (Horner shift)
;; encode(a ++ b, base) == encode(a, base) * base^|b| + encode(b, base)
(check-property "concatenation-shift" n-trials
  (lambda ()
    (let* ((base (+ 2 (random-integer 50)))
           (a (random-tuple 3 base))
           (b (random-tuple 3 base))
           (ab (append a b)))
      (= (encode-tuple ab base)
         (+ (* (encode-tuple a base) (expt base (length b)))
            (encode-tuple b base))))))

;; Property 8: Base-10 digit encoding equals the number
;; encode([1,2,3], 10) == 123
(test-assert "base-10-digits"
  (and (= 123  (encode-tuple '(1 2 3) 10))
       (= 4259 (encode-tuple '(3 1 4 1 5) 6))
       (= 0    (encode-tuple '(0 0 0) 10))))

;; Property 9: Known string roundtrip from the org file
(test-assert "known-roundtrip-horner!"
  (let* ((s "horner!")
         (base 128)
         (n (horner-encode s base)))
    (and (number? n)
         (> n 0)
         (equal? s (horner-decode n base)))))

;; Property 10: Encoding is strictly positive for non-empty strings
;; with positive char values
(check-property "encoding-positive" n-trials
  (lambda ()
    (let* ((base 256)
           (s (random-ascii-string 10)))
      (> (horner-encode s base) 0))))

(test-end "horner-properties")
