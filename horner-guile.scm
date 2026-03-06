(use-modules (srfi srfi-1))

(define m 128)

;;; SRFI-1 fold: (lambda (element accumulator) ...)
;;; reverse so first char is most significant
(define (horner-encode s base)
  (fold (lambda (c acc) (+ (* acc base) c))
        0
        (map char->integer (string->list s))))

(define (horner-decode n base)
  (let loop ((n n) (acc '()))
    (if (= n 0)
        (list->string (map integer->char acc))
        (loop (quotient  n base)
              (cons (remainder n base) acc)))))

(let* ((s "horner!")
       (n (horner-encode s m)))
  (format #t "encoded: ~a~%" n)
  (format #t "decoded: ~a~%" (horner-decode n m)))
