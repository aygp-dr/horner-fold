(use-modules (rnrs lists))

;;; (rnrs lists) fold-left: (lambda (accumulator element) ...)
(define (horner-encode s base)
  (fold-left (lambda (acc c) (+ (* acc base) c))
             0
             (map char->integer (string->list s))))
