;;; tests/test-horner-chez.scm -- Tests for horner-chez.scm
;;; Run: scheme --script tests/test-horner-chez.scm
;;;
;;; Chez Scheme has no built-in test framework, so we use a lightweight
;;; assert-equal / assert-true macro pair that reports pass/fail counts.

;;; ----------------------------------------------------------------
;;; Minimal test harness
;;; ----------------------------------------------------------------

(define *test-passes* 0)
(define *test-failures* 0)
(define *test-errors* '())

(define (test-report)
  (newline)
  (display "========================================") (newline)
  (display (string-append
            "Results: "
            (number->string *test-passes*) " passed, "
            (number->string *test-failures*) " failed, "
            (number->string (+ *test-passes* *test-failures*)) " total"))
  (newline)
  (unless (null? *test-errors*)
    (display "FAILURES:") (newline)
    (for-each (lambda (e)
                (display (string-append "  FAIL: " (car e) " -- " (cdr e)))
                (newline))
              *test-errors*))
  (display "========================================") (newline)
  ;; Exit with non-zero status on failure (CI-friendly)
  (when (> *test-failures* 0)
    (exit 1)))

(define-syntax test-assert
  (syntax-rules ()
    [(_ name expr)
     (guard (exn [#t (set! *test-failures* (+ *test-failures* 1))
                     (set! *test-errors*
                           (append *test-errors*
                                   (list (cons name
                                               (if (condition? exn)
                                                   (condition-message exn)
                                                   "exception")))))])
       (if expr
           (set! *test-passes* (+ *test-passes* 1))
           (begin
             (set! *test-failures* (+ *test-failures* 1))
             (set! *test-errors*
                   (append *test-errors*
                           (list (cons name "assertion failed")))))))]))

(define-syntax test-equal
  (syntax-rules ()
    [(_ name expected expr)
     (test-assert name (equal? expected expr))]))

;;; ----------------------------------------------------------------
;;; Functions under test (copied from horner-chez.scm to be self-contained)
;;; ----------------------------------------------------------------

(define (horner-encode s base)
  (fold-left (lambda (acc c) (+ (* acc base) c))
             0
             (map char->integer (string->list s))))

(define (horner-decode n base)
  (let loop ((n n) (acc '()))
    (if (= n 0)
        (list->string (map integer->char acc))
        (loop (quotient n base)
              (cons (remainder n base) acc)))))

(define (encode-tuple indices base)
  (fold-left (lambda (acc i) (+ (* acc base) i)) 0 indices))

(define (decode-tuple n base rank)
  (let loop ((n n) (r rank) (acc '()))
    (if (= r 0) acc
        (loop (quotient n base)
              (- r 1)
              (cons (remainder n base) acc)))))

;;; ----------------------------------------------------------------
;;; Chez-specific: fixnum-optimized variants (fx+, fx*, fxarithmetic-shift)
;;; These only work when values stay within fixnum range.
;;; ----------------------------------------------------------------

;; Fixnum-optimized encode for small bases and short tuples.
(define (encode-tuple/fx indices base)
  (fold-left (lambda (acc i) (fx+ (fx* acc base) i)) 0 indices))

;;; ----------------------------------------------------------------
;;; Test suite
;;; ----------------------------------------------------------------

(display "Running horner-chez tests...") (newline)
(newline)

;;; --- String roundtrip at base 128 ---

(display "# String encode/decode roundtrip (base 128)") (newline)

(test-assert "roundtrip: \"horner!\" at base 128"
  (let* ((s "horner!")
         (n (horner-encode s 128)))
    (and (number? n)
         (> n 0)
         (equal? s (horner-decode n 128)))))

(test-assert "roundtrip: \"A\" at base 128"
  (equal? "A" (horner-decode (horner-encode "A" 128) 128)))

(test-assert "roundtrip: \"Hello, World!\" at base 128"
  (equal? "Hello, World!"
          (horner-decode (horner-encode "Hello, World!" 128) 128)))

(test-assert "roundtrip: \"abc\" at base 256"
  (equal? "abc" (horner-decode (horner-encode "abc" 256) 256)))

(test-assert "roundtrip: single space at base 128"
  (equal? " " (horner-decode (horner-encode " " 128) 128)))

(test-equal "encode: \"horner!\" produces known bignum"
  (let ((expected (+ (* (char->integer #\h) (expt 128 6))
                     (* (char->integer #\o) (expt 128 5))
                     (* (char->integer #\r) (expt 128 4))
                     (* (char->integer #\n) (expt 128 3))
                     (* (char->integer #\e) (expt 128 2))
                     (* (char->integer #\r) (expt 128 1))
                     (* (char->integer #\!) (expt 128 0)))))
    expected)
  (horner-encode "horner!" 128))

;;; --- Tuple encode/decode at base 10 ---

(display "# Tuple encode/decode (base 10)") (newline)

(test-equal "encode-tuple: (1 2 3) base 10 = 123"
  123
  (encode-tuple '(1 2 3) 10))

(test-equal "decode-tuple: 123 base 10 rank 3 = (1 2 3)"
  '(1 2 3)
  (decode-tuple 123 10 3))

(test-equal "encode-tuple: (0) base 10 = 0"
  0
  (encode-tuple '(0) 10))

(test-equal "encode-tuple: (9 9 9) base 10 = 999"
  999
  (encode-tuple '(9 9 9) 10))

(test-equal "encode-tuple: (1 0 0) base 10 = 100"
  100
  (encode-tuple '(1 0 0) 10))

(test-equal "decode-tuple: 0 base 10 rank 3 = (0 0 0)"
  '(0 0 0)
  (decode-tuple 0 10 3))

;;; --- encode-tuple / decode-tuple agreement ---

(display "# encode-tuple / decode-tuple agreement") (newline)

(test-assert "roundtrip: (3 1 4 1 5) base 6"
  (equal? '(3 1 4 1 5)
          (decode-tuple (encode-tuple '(3 1 4 1 5) 6) 6 5)))

(test-assert "roundtrip: (7 0 3) base 8"
  (equal? '(7 0 3)
          (decode-tuple (encode-tuple '(7 0 3) 8) 8 3)))

(test-equal "encode-tuple then decode-tuple: (1 1 0 1) base 2"
  '(1 1 0 1)
  (decode-tuple (encode-tuple '(1 1 0 1) 2) 2 4))

(test-assert "agreement: encode matches polynomial expansion"
  (let* ((base 10)
         (coeffs '(4 5 6))
         (horner (encode-tuple coeffs base))
         (naive (+ (* 4 100) (* 5 10) 6)))
    (= horner naive)))

(test-assert "agreement: encode matches polynomial expansion (base 7)"
  (let* ((base 7)
         (coeffs '(2 3 5))
         (horner (encode-tuple coeffs base))
         (naive (+ (* 2 (expt 7 2)) (* 3 7) 5)))
    (= horner naive)))

;;; --- Edge cases ---

(display "# Edge cases") (newline)

;; Empty list: fold-left over '() returns the seed (0)
(test-equal "encode-tuple: empty list = 0"
  0
  (encode-tuple '() 10))

(test-equal "decode-tuple: 0 rank 0 = ()"
  '()
  (decode-tuple 0 10 0))

;; Single element
(test-equal "encode-tuple: single (5) base 10 = 5"
  5
  (encode-tuple '(5) 10))

(test-equal "encode-tuple: single (1) base 2 = 1"
  1
  (encode-tuple '(1) 2))

(test-equal "encode-tuple: single (0) base 2 = 0"
  0
  (encode-tuple '(0) 2))

(test-equal "decode-tuple: 5 base 10 rank 1 = (5)"
  '(5)
  (decode-tuple 5 10 1))

;; Base 2 (binary)
(test-equal "encode-tuple: (1 0 1 1) base 2 = 11"
  11  ; 1*8 + 0*4 + 1*2 + 1*1
  (encode-tuple '(1 0 1 1) 2))

(test-equal "decode-tuple: 11 base 2 rank 4 = (1 0 1 1)"
  '(1 0 1 1)
  (decode-tuple 11 2 4))

(test-equal "encode-tuple: (1 1 1 1 1 1 1 1) base 2 = 255"
  255
  (encode-tuple '(1 1 1 1 1 1 1 1) 2))

;; Leading zeros are absorbed (important structural property)
(test-assert "leading zeros: encode (0 1 2 3) = encode (1 2 3) at base 10"
  (= (encode-tuple '(0 1 2 3) 10)
     (encode-tuple '(1 2 3) 10)))

;; Large base
(test-assert "roundtrip: (42 99 7) base 100"
  (equal? '(42 99 7)
          (decode-tuple (encode-tuple '(42 99 7) 100) 100 3)))

;;; --- Concatenation / shift property ---

(display "# Concatenation (Horner shift) property") (newline)

(test-assert "concat: encode(a++b) = encode(a)*base^|b| + encode(b)"
  (let* ((base 10)
         (a '(1 2))
         (b '(3 4 5))
         (ab (append a b)))
    (= (encode-tuple ab base)
       (+ (* (encode-tuple a base) (expt base (length b)))
          (encode-tuple b base)))))

;;; --- Fixnum-optimized variant ---

(display "# Chez fixnum-optimized encode (fx+, fx*)") (newline)

(test-equal "encode-tuple/fx: (1 2 3) base 10 = 123"
  123
  (encode-tuple/fx '(1 2 3) 10))

(test-equal "encode-tuple/fx: (1 0 1 1) base 2 = 11"
  11
  (encode-tuple/fx '(1 0 1 1) 2))

(test-assert "encode-tuple/fx agrees with encode-tuple"
  (= (encode-tuple '(3 1 4 1 5) 6)
     (encode-tuple/fx '(3 1 4 1 5) 6)))

;;; ----------------------------------------------------------------
;;; Report
;;; ----------------------------------------------------------------

(test-report)
