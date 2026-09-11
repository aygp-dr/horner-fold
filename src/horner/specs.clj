(ns horner.specs
  "Data specs for horner-fold (https://clojure.org/guides/spec).
  Function specs (s/fdef) live next to each defn in horner.core."
  (:require [clojure.spec.alpha :as s]
            [clojure.spec.gen.alpha :as gen]))

;; Generators are built by fns, not held in vars: building one loads
;; test.check, which is only on the :dev/:test classpath.
(defn- gen-text []
  (gen/fmap (fn [cs] (apply str (map char cs)))
            (gen/vector (gen/choose 1 127) 0 40)))

;; A string without NUL characters. NUL (codepoint 0) would be a leading-zero
;; digit, which decode drops, so a NUL-prefixed string cannot round-trip.
(s/def ::text
  (s/with-gen (s/and string? (fn [s] (every? #(pos? (int %)) s)))
    gen-text))

;; A radix. Base 0 divides by zero and base 1 never terminates in decode.
(s/def ::base (s/with-gen (s/and int? #(>= % 2)) #(gen/choose 2 1024)))

;; An encoded value: a non-negative integer, a BigInt once it outgrows a long.
(s/def ::code
  (s/with-gen (s/and integer? (complement neg?))
    #(gen/one-of [(gen/large-integer* {:min 0})
                  (gen/fmap (fn [n] (*' n Long/MAX_VALUE)) (gen/large-integer* {:min 0}))])))

;; encode/decode round-trip only when the base exceeds every codepoint.
(s/def ::roundtrip-args
  (s/and (s/cat :s ::text :base ::base)
         (fn [{:keys [s base]}] (every? #(< (int %) base) s))))
