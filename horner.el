;;; -*- lexical-binding: t -*-

(defvar horner-base 128)

;;; seq-reduce: (lambda (accumulator element) ...) — accumulator first
(defun horner-encode (s base)
  (seq-reduce (lambda (acc c) (+ (* acc base) c))
              (mapcar #'identity (string-to-list s))
              0))

;;; decode: named loop via cl-loop
(require 'cl-lib)
(defun horner-decode (n base)
  (cl-loop with acc = '()
           while (> n 0)
           do (push (% n base) acc)
              (setq n (/ n base))
           finally return (concat (mapcar #'identity acc))))

;;; With dash threading macros (->> pipes right, -> pipes left)
;;; (require 'dash) if available
(defun horner-encode/dash (s base)
  (->> (string-to-list s)
       (seq-reduce (lambda (acc c) (+ (* acc base) c)) it 0)))

;;; Pure cl-reduce version (built-in, no deps)
(defun horner-encode/cl (s base)
  (cl-reduce (lambda (acc c) (+ (* acc base) c))
             (string-to-list s)
             :initial-value 0))

(let* ((s "horner!")
       (n (horner-encode s horner-base)))
  (message "encoded: %d" n)
  (message "decoded: %s" (horner-decode n horner-base)))
