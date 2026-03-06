(ns test-horner-bb
  "Babashka-compatible tests (no test.check dependency).
   Run via: bb -cp src:tests -m test-horner-bb"
  (:require [clojure.test :refer [deftest is testing run-tests]]
            [horner.core :refer [horner-encode horner-decode
                                 horner-encode-threaded horner-decode-threaded
                                 horner-roundtrip m]]))

(deftest test-known-roundtrip
  (testing "encode then decode 'horner!' at base 128"
    (let [s "horner!"
          n (horner-encode s m)]
      (is (pos? n))
      (is (= s (horner-decode n m))))))

(deftest test-edge-cases
  (testing "empty string encodes to 0"
    (is (= 0 (horner-encode "" m))))
  (testing "empty string roundtrip"
    (is (= "" (horner-decode 0 m))))
  (testing "single character roundtrip"
    (doseq [c [\A \z \! \space]]
      (let [s (str c)]
        (is (= (int c) (horner-encode s m)))
        (is (= s (horner-decode (horner-encode s m) m)))))))

(deftest test-threading-equivalence
  (testing "->> encode matches plain encode"
    (doseq [s ["horner!" "abc" "A"]]
      (is (= (horner-encode s m) (horner-encode-threaded s m)))))
  (testing "-> decode matches plain decode"
    (doseq [s ["horner!" "abc" "A"]]
      (let [n (horner-encode s m)]
        (is (= (horner-decode n m) (horner-decode-threaded n m))))))
  (testing "as-> roundtrip"
    (doseq [s ["horner!" "abc" "A"]]
      (is (= s (horner-roundtrip s m))))))

(deftest test-manual-generative
  (testing "pseudo-random roundtrip checks"
    (let [rng (java.util.Random. 42)]
      (dotimes [_ 100]
        (let [base (+ 128 (.nextInt rng 128))
              len (+ 1 (.nextInt rng 20))
              chars (repeatedly len #(char (+ 1 (.nextInt rng 126))))
              s (apply str chars)]
          (is (= s (horner-decode (horner-encode s base) base))
              (str "roundtrip failed for: " (pr-str s) " base=" base)))))))

(defn -main [& _args]
  (let [result (run-tests)]
    (System/exit (if (and (zero? (:fail result))
                          (zero? (:error result)))
                  0 1))))

(-main)
