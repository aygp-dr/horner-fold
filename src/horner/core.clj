(ns horner.core
  (:require [clojure.spec.alpha :as s]
            [horner.specs :as specs]))

(def m 128)

;;; reduce: (fn [acc el] ...) — accumulator first, always
(defn horner-encode [s base]
  (reduce (fn [acc c] (+' (*' acc base) (int c)))
          0
          s))  ;; strings are seqable in Clojure — no string->list needed

(s/fdef horner-encode
  :args (s/cat :s ::specs/text :base ::specs/base)
  :ret ::specs/code
  ;; only the empty string encodes to 0 (the text has no NUL digits)
  :fn (fn [{{:keys [s]} :args ret :ret}]
        (= (empty? s) (zero? ret))))

;;; decode: loop/recur is idiomatic unfold
(defn horner-decode [n base]
  (loop [n n acc []]
    (if (zero? n)
      (apply str (map char acc))
      (recur (quot n base)
             (cons (rem n base) acc)))))

(s/fdef horner-decode
  :args (s/cat :n ::specs/code :base ::specs/base)
  :ret string?
  ;; decoding is a right inverse of encoding
  :fn (fn [{{:keys [n base]} :args ret :ret}]
        (= n (horner-encode ret base))))

;;; ->> threading: left-to-right pipeline, value inserted as last arg
(defn horner-encode-threaded [s base]
  (->> s
       (map int)
       (reduce (fn [acc c] (+' (*' acc base) c)) 0)))

(s/fdef horner-encode-threaded
  :args (s/cat :s ::specs/text :base ::specs/base)
  :ret ::specs/code
  :fn (fn [{{:keys [s base]} :args ret :ret}]
        (= ret (horner-encode s base))))

;;; -> threading: value inserted as first arg — useful for obj methods
(defn horner-decode-threaded [n base]
  (-> (loop [n n acc []]
        (if (zero? n) acc
            (recur (quot n base) (cons (rem n base) acc))))
      (->> (map char))
      (->> (apply str))))

(s/fdef horner-decode-threaded
  :args (s/cat :n ::specs/code :base ::specs/base)
  :ret string?
  :fn (fn [{{:keys [n base]} :args ret :ret}]
        (= ret (horner-decode n base))))

;;; as-> for mixed threading
(defn horner-roundtrip [s base]
  (as-> s $
    (map int $)
    (reduce (fn [acc c] (+' (*' acc base) c)) 0 $)
    (horner-decode $ base)))

(s/fdef horner-roundtrip
  :args ::specs/roundtrip-args
  :ret string?
  :fn (fn [{{:keys [s]} :args ret :ret}]
        (= s ret)))
