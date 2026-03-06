(define m 128)

;;; fold-left native in Chez: (lambda (acc element) ...)
(define (horner-encode s base)
  (fold-left (lambda (acc c) (+ (* acc base) c))
             0
             (map char->integer (string->list s))))

(define (horner-decode n base)
  (let loop ((n n) (acc '()))
    (if (= n 0)
        (list->string (map integer->char acc))
        (loop (quotient  n base)
              (cons (remainder n base) acc)))))

;;; Generalize to arbitrary tuples
(define (encode-tuple indices base)
  (fold-left (lambda (acc i) (+ (* acc base) i)) 0 indices))

(define (decode-tuple n base rank)
  (let loop ((n n) (r rank) (acc '()))
    (if (= r 0) acc
        (loop (quotient n base)
              (- r 1)
              (cons (remainder n base) acc)))))

(display (horner-encode "horner!" m)) (newline)
(display (encode-tuple '(1 2 3) 10))  (newline) ;; => 123
(display (decode-tuple 123 10 3))     (newline) ;; => (1 2 3)
