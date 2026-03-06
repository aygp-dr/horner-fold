;;; test-horner.el --- ERT tests for horner.el -*- lexical-binding: t -*-

;; Run: emacs --batch -l ert -l tests/test-horner.el -f ert-run-tests-batch-and-exit

;;; Commentary:
;;
;; Tests for Horner encode/decode in Emacs Lisp.
;; Self-contained: redefines the functions under test so the test file
;; can be run without loading horner.el (matches the project convention
;; seen in test-horner-chez.scm and test_horner.clj).

;;; Code:

(require 'ert)
(require 'seq)
(require 'cl-lib)

;; ----------------------------------------------------------------
;; Functions under test (from horner.el)
;; ----------------------------------------------------------------

(defvar horner-base 128)

(defun horner-encode (s base)
  "Encode string S as an integer using Horner's method at BASE."
  (seq-reduce (lambda (acc c) (+ (* acc base) c))
              (mapcar #'identity (string-to-list s))
              0))

(defun horner-decode (n base)
  "Decode integer N back to a string using BASE."
  (cl-loop with acc = '()
           while (> n 0)
           do (push (% n base) acc)
              (setq n (/ n base))
           finally return (concat (mapcar #'identity acc))))

(defun horner-encode/cl (s base)
  "Encode using cl-reduce (no seq dependency)."
  (cl-reduce (lambda (acc c) (+ (* acc base) c))
             (string-to-list s)
             :initial-value 0))

;; ----------------------------------------------------------------
;; String roundtrip tests
;; ----------------------------------------------------------------

(ert-deftest horner-test-roundtrip-horner! ()
  "Encode then decode \"horner!\" at base 128."
  (let* ((s "horner!")
         (n (horner-encode s horner-base)))
    (should (> n 0))
    (should (integerp n))
    (should (equal s (horner-decode n horner-base)))))

(ert-deftest horner-test-roundtrip-single-char-A ()
  "Single character \"A\" roundtrips."
  (should (equal "A" (horner-decode (horner-encode "A" horner-base) horner-base))))

(ert-deftest horner-test-roundtrip-hello-world ()
  "\"Hello, World!\" roundtrips at base 128."
  (should (equal "Hello, World!"
                 (horner-decode (horner-encode "Hello, World!" horner-base) horner-base))))

(ert-deftest horner-test-roundtrip-base-256 ()
  "\"abc\" roundtrips at base 256."
  (should (equal "abc" (horner-decode (horner-encode "abc" 256) 256))))

(ert-deftest horner-test-roundtrip-space ()
  "Single space roundtrips."
  (should (equal " " (horner-decode (horner-encode " " horner-base) horner-base))))

;; ----------------------------------------------------------------
;; Known values
;; ----------------------------------------------------------------

(ert-deftest horner-test-encode-A-equals-65 ()
  "Encoding \"A\" at base 128 should equal 65 (its codepoint)."
  (should (= 65 (horner-encode "A" horner-base))))

(ert-deftest horner-test-encode-AB ()
  "Encoding \"AB\" at base 128 should equal 65*128 + 66 = 8386."
  (should (= 8386 (horner-encode "AB" horner-base))))

;; ----------------------------------------------------------------
;; cl-reduce vs seq-reduce equivalence
;; ----------------------------------------------------------------

(ert-deftest horner-test-cl-reduce-matches-seq-reduce ()
  "cl-reduce and seq-reduce produce the same result."
  (dolist (s '("horner!" "abc" "A" "Hello, World!" " " "~"))
    (should (= (horner-encode s horner-base)
               (horner-encode/cl s horner-base)))))

;; ----------------------------------------------------------------
;; Edge cases
;; ----------------------------------------------------------------

(ert-deftest horner-test-empty-string-encodes-to-zero ()
  "Empty string encodes to 0 (reduce over empty sequence returns initial value)."
  (should (= 0 (horner-encode "" horner-base))))

(ert-deftest horner-test-decode-zero-is-empty-string ()
  "Decoding 0 produces the empty string (loop body never executes)."
  (should (equal "" (horner-decode 0 horner-base))))

(ert-deftest horner-test-empty-string-roundtrip ()
  "Empty string roundtrips through encode/decode."
  (should (equal "" (horner-decode (horner-encode "" horner-base) horner-base))))

(ert-deftest horner-test-single-char-encodes-to-codepoint ()
  "A single character encodes to its codepoint value."
  (dolist (c '(?A ?z ?! ?\s ?~))
    (let ((s (char-to-string c)))
      (should (= c (horner-encode s horner-base))))))

(ert-deftest horner-test-single-char-roundtrip-printable-ascii ()
  "All printable ASCII chars roundtrip correctly."
  (cl-loop for c from 33 to 126
           do (let* ((s (char-to-string c))
                     (n (horner-encode s horner-base)))
                (should (= c n))
                (should (equal s (horner-decode n horner-base))))))

;; ----------------------------------------------------------------
;; Positional / polynomial encoding
;; ----------------------------------------------------------------

(ert-deftest horner-test-base-10-digits ()
  "Encoding digits [1,2,3] in base 10 produces 123."
  (should (= 123 (cl-reduce (lambda (acc c) (+ (* acc 10) c))
                             '(1 2 3) :initial-value 0))))

(ert-deftest horner-test-binary-digits ()
  "Encoding bits [1,0,1,1] in base 2 produces 11."
  (should (= 11 (cl-reduce (lambda (acc c) (+ (* acc 2) c))
                            '(1 0 1 1) :initial-value 0))))

(ert-deftest horner-test-leading-zeros-absorbed ()
  "Leading zeros don't affect the encoded value (positional notation property)."
  (let ((kernel (lambda (acc c) (+ (* acc 10) c))))
    (should (= (cl-reduce kernel '(1 2 3) :initial-value 0)
               (cl-reduce kernel '(0 1 2 3) :initial-value 0)))))

;; ----------------------------------------------------------------
;; mapcar #'identity redundancy check
;; ----------------------------------------------------------------

(ert-deftest horner-test-mapcar-identity-is-redundant ()
  "Verify (mapcar #'identity (string-to-list s)) == (string-to-list s).
This confirms the mapcar in horner-encode is a no-op."
  (dolist (s '("horner!" "" "A" "Hello, World!"))
    (should (equal (mapcar #'identity (string-to-list s))
                   (string-to-list s)))))

;; ----------------------------------------------------------------
;; Encoding is strictly positive for non-empty strings
;; ----------------------------------------------------------------

(ert-deftest horner-test-encoding-positive-for-nonempty ()
  "Encoding any non-empty string with chars > 0 yields a positive number."
  (dolist (s '("a" "abc" "horner!" "Hello, World!"))
    (should (> (horner-encode s horner-base) 0))))

;; ----------------------------------------------------------------
;; Concatenation / Horner shift property
;; ----------------------------------------------------------------

(ert-deftest horner-test-concatenation-shift ()
  "encode(a++b) == encode(a) * base^|b| + encode(b)."
  (let* ((base 128)
         (a "AB")
         (b "CD")
         (ab (concat a b))
         (enc-a (horner-encode a base))
         (enc-b (horner-encode b base))
         (enc-ab (horner-encode ab base))
         (len-b (length b)))
    (should (= enc-ab
               (+ (* enc-a (expt base len-b))
                  enc-b)))))

;;; test-horner.el ends here
