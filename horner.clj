(ns horner.core)

(def m 128)

;;; reduce: (fn [acc el] ...) — accumulator first, always
(defn horner-encode [s base]
  (reduce (fn [acc c] (+ (* acc base) (int c)))
          0
          s))  ;; strings are seqable in Clojure — no string->list needed

;;; decode: loop/recur is idiomatic unfold
(defn horner-decode [n base]
  (loop [n n acc []]
    (if (zero? n)
      (apply str (map char acc))
      (recur (quot n base)
             (cons (rem n base) acc)))))

;;; ->> threading: left-to-right pipeline, value inserted as last arg
(defn horner-encode-threaded [s base]
  (->> s
       (map int)
       (reduce (fn [acc c] (+ (* acc base) c)) 0)))

;;; -> threading: value inserted as first arg — useful for obj methods
(defn horner-decode-threaded [n base]
  (-> (loop [n n acc []]
        (if (zero? n) acc
            (recur (quot n base) (cons (rem n base) acc))))
      (->> (map char))
      (apply str [])))

;;; as-> for mixed threading
(defn horner-roundtrip [s base]
  (as-> s $
    (map int $)
    (reduce (fn [acc c] (+ (* acc base) c)) 0 $)
    (horner-decode $ base)))

(let [n (horner-encode "horner!" m)]
  (println "encoded:" n)
  (println "decoded:" (horner-decode n m))
  (println "roundtrip:" (horner-roundtrip "horner!" m)))
