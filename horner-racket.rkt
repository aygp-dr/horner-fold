#lang racket

(define m 128)

;;; foldl in Racket: (lambda (element accumulator) ...) — same as SRFI-1
(define (horner-encode s base)
  (foldl (lambda (c acc) (+ (* acc base) c))
         0
         (map char->integer (string->list s))))

;;; for/fold is idiomatic Racket — reads as "for each c, accumulating acc"
(define (horner-encode/for s base)
  (for/fold ([acc 0])
            ([c (map char->integer (string->list s))])
    (+ (* acc base) c)))

(define (horner-decode n base)
  (let loop ([n n] [acc '()])
    (if (= n 0)
        (list->string (map integer->char acc))
        (loop (quotient  n base)
              (cons (remainder n base) acc)))))

;;; Threading macro (~>) from racket/function — pipe left to right
(require threading)

(define (horner-encode/threaded s base)
  (~> s
      string->list
      (map char->integer _)
      (foldl (lambda (c acc) (+ (* acc base) c)) 0 _)))

(let ([n (horner-encode "horner!" m)])
  (displayln n)
  (displayln (horner-decode n m))
  (displayln (horner-encode/threaded "horner!" m)))
