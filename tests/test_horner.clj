(ns test-horner
  (:require [clojure.test :refer [deftest is testing are run-tests]]
            [clojure.test.check :as tc]
            [clojure.test.check.generators :as gen]
            [clojure.test.check.properties :as prop]
            [clojure.test.check.clojure-test :refer [defspec]]
            [horner.core :refer [horner-encode horner-decode
                                 horner-encode-threaded horner-decode-threaded
                                 horner-roundtrip m]]))

;; =============================================================================
;; Known-value tests
;; =============================================================================

(deftest test-known-roundtrip
  (testing "encode then decode 'horner!' at base 128"
    (let [s "horner!"
          n (horner-encode s m)]
      (is (pos? n) "encoding a non-empty string must be positive")
      (is (= s (horner-decode n m))))))

(deftest test-base-10-digits
  (testing "Horner encoding matches positional notation"
    ;; encode-tuple style: use a vector of ints directly
    (is (= 123 (reduce (fn [acc c] (+ (* acc 10) c)) 0 [1 2 3])))
    (is (= 4259 (reduce (fn [acc c] (+ (* acc 6) c)) 0 [3 1 4 1 5])))))

;; =============================================================================
;; Edge cases
;; =============================================================================

(deftest test-edge-cases
  (testing "empty string encodes to 0"
    (is (= 0 (horner-encode "" m))
        "reduce over empty seq with init 0 returns 0"))

  (testing "empty string decode: decode(0) => empty string"
    (is (= "" (horner-decode 0 m))
        "zero decodes to empty string (loop never enters body)"))

  (testing "empty string roundtrip"
    (is (= "" (horner-decode (horner-encode "" m) m))))

  (testing "single character roundtrip"
    (doseq [c [\A \z \! \space \~]]
      (let [s (str c)
            n (horner-encode s m)]
        (is (= (int c) n)
            (str "single char " c " should encode to its codepoint"))
        (is (= s (horner-decode n m))
            (str "single char " c " should roundtrip"))))))

;; =============================================================================
;; Threading macro equivalence
;; =============================================================================

(deftest test-threading-variants-produce-same-results
  (testing "->> threaded encode matches plain encode"
    (doseq [s ["horner!" "abc" "A" "Hello, World!"]]
      (is (= (horner-encode s m)
              (horner-encode-threaded s m))
          (str "threaded encode differs for: " s))))

  (testing "-> threaded decode matches plain decode"
    (doseq [s ["horner!" "abc" "A" "Hello, World!"]]
      (let [n (horner-encode s m)]
        (is (= (horner-decode n m)
                (horner-decode-threaded n m))
            (str "threaded decode differs for n=" n)))))

  (testing "as-> roundtrip matches explicit encode+decode"
    (doseq [s ["horner!" "abc" "A" "Hello, World!"]]
      (is (= s (horner-roundtrip s m))
          (str "as-> roundtrip failed for: " s)))))

;; =============================================================================
;; Generative / property-based tests (test.check)
;; =============================================================================

;; Generator: non-empty strings of ASCII chars with codepoints in [1, 127]
;; (codepoint 0 would encode as a "leading zero" and break roundtrip)
(def gen-ascii-string
  (gen/fmap (fn [cs] (apply str (map char cs)))
            (gen/not-empty
             (gen/vector (gen/choose 1 127)))))

;; Generator: base large enough to hold all ASCII codepoints
(def gen-base
  (gen/choose 128 256))

(defspec roundtrip-string-property 200
  (prop/for-all [s gen-ascii-string
                 base gen-base]
    (= s (horner-decode (horner-encode s base) base))))

(defspec threaded-encode-matches-plain 200
  (prop/for-all [s gen-ascii-string
                 base gen-base]
    (= (horner-encode s base)
       (horner-encode-threaded s base))))

(defspec threaded-decode-matches-plain 200
  (prop/for-all [s gen-ascii-string
                 base gen-base]
    (let [n (horner-encode s base)]
      (= (horner-decode n base)
         (horner-decode-threaded n base)))))

(defspec as->-roundtrip-matches 200
  (prop/for-all [s gen-ascii-string
                 base gen-base]
    (= s (horner-roundtrip s base))))

;; Encoding is always non-negative
(defspec encoding-non-negative 200
  (prop/for-all [s gen-ascii-string
                 base gen-base]
    (>= (horner-encode s base) 0)))

;; Single element identity: a single char c encodes to (int c)
(defspec single-char-identity 200
  (prop/for-all [c (gen/choose 1 127)
                 base gen-base]
    (= c (horner-encode (str (char c)) base))))

;; Polynomial equivalence: Horner encode == naive polynomial expansion
(def gen-nonzero-leading-coeffs
  "Generates [base coeffs] where first coeff > 0 and all coeffs < base."
  (gen/bind (gen/choose 2 50)
            (fn [base]
              (gen/bind (gen/choose 1 (dec base))
                        (fn [first-coeff]
                          (gen/bind (gen/vector (gen/choose 0 (dec base)) 0 5)
                                   (fn [rest-coeffs]
                                     (gen/return [base (into [first-coeff] rest-coeffs)]))))))))

(defspec polynomial-equivalence 200
  (prop/for-all [[base coeffs] gen-nonzero-leading-coeffs]
    (let [horner-result (reduce (fn [acc c] (+ (* acc base) c)) 0 coeffs)
          len (count coeffs)
          naive-result (reduce + 0
                               (map-indexed
                                (fn [i c]
                                  (*' c (long (Math/pow base (- len 1 i)))))
                                coeffs))]
      (= horner-result naive-result))))

;; Tuple roundtrip (no leading zeros)
(defspec tuple-roundtrip 200
  (prop/for-all [[base coeffs] gen-nonzero-leading-coeffs]
    (let [encoded (reduce (fn [acc c] (+ (* acc base) c)) 0 coeffs)
          decoded (loop [n encoded acc []]
                    (if (zero? n) acc
                        (recur (quot n base) (into [(rem n base)] acc))))]
      (= coeffs decoded))))

;; =============================================================================
;; Run tests when loaded as a script
;; =============================================================================

(defn -main [& _args]
  (let [result (run-tests)]
    (System/exit (if (and (zero? (:fail result))
                          (zero? (:error result)))
                  0 1))))

;; When run via `clj -M tests/test_horner.clj`, execute tests
(when (= *file* (System/getProperty "babashka.file" *file*))
  (-main))
