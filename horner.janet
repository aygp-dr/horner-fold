(def m 128)

;;; reduce: (fn [acc el] ...) accumulator first
(defn horner-encode [s base]
  (reduce (fn [acc c] (+ (* acc base) c))
          0
          (map (fn [c] (chr c)) (string/bytes s))))

;;; string/bytes gives byte values directly — no char->int step
(defn horner-encode/bytes [s base]
  (reduce (fn [acc b] (+ (* acc base) b))
          0
          (string/bytes s)))

;;; decode: loop via while + array
(defn horner-decode [n base]
  (var n n)
  (def acc @[])
  (while (> n 0)
    (array/insert acc 0 (% n base))
    (set n (div n base)))
  (string/from-bytes ;acc))

;;; Janet has -> and ->> threading macros built-in
(defn horner-encode/threaded [s base]
  (->> (string/bytes s)
       (reduce (fn [acc b] (+ (* acc base) b)) 0)))

(let [n (horner-encode/bytes "horner!" m)]
  (print "encoded: " n)
  (print "decoded: " (horner-decode n m)))
