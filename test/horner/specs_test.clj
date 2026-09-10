(ns horner.specs-test
  "Generative checks for every pure s/fdef'd fn, plus data-spec sanity.
  Per https://clojure.org/guides/spec (Testing)."
  (:require [clojure.spec.alpha :as s]
            [clojure.spec.test.alpha :as stest]
            [clojure.test :refer [deftest is testing]]
            [horner.core :as core]
            [horner.specs :as specs]))

(def ^:private check-opts {:clojure.spec.test.check/opts {:num-tests 50}})

;; Side-effecting fns: none. Every fn in horner.core is pure.
(def ^:private side-effecting #{})

(defn- checkable []
  (remove side-effecting (stest/enumerate-namespace 'horner.core)))

(deftest fdefs-hold-under-generative-testing
  (let [results (stest/check (checkable) check-opts)]
    (is (seq results) "expected at least one fdef'd fn to check")
    (doseq [r results]
      (testing (str (:sym r))
        (is (nil? (:failure r))
            (pr-str (stest/abbrev-result r)))))))

(deftest data-specs-generate-and-conform
  (doseq [k [::specs/text ::specs/base ::specs/code ::specs/roundtrip-args]]
    (testing (str k)
      (is (every? (fn [[v _]] (s/valid? k v)) (s/exercise k 10))))))

(deftest real-values-conform
  (testing "the README example: \"horner!\" at base 128"
    (is (s/valid? ::specs/roundtrip-args ["horner!" core/m]))
    (is (s/valid? ::specs/code (core/horner-encode "horner!" core/m))))
  (testing "a value past Long/MAX_VALUE"
    (is (s/valid? ::specs/code (core/horner-encode "Hello, World!" 256)))))
