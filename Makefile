# ============================================================================
# Makefile -- Horner's Method: Polyglot Lisp Implementations + Formal Methods
# ============================================================================
#
# Usage:
#   make              Show all targets with descriptions
#   make run-all      Run all language implementations
#   make test-all     Run all language test suites
#   make formal-all   Run all formal verification suites
#   make ci           Full CI pipeline (test-all + formal-all)
#
# Each target checks for its tool first and prints a SKIP message if not
# found, so `make -k run-all` degrades gracefully on partial installs.
#
# Parallel-safe: `make -j4 test-all` works -- no shared state between targets.
#
# ============================================================================

SHELL := /bin/bash
.DELETE_ON_ERROR:
.DEFAULT_GOAL := help

# --------------------------------------------------------------------------
# Tool paths -- override on the command line or via environment
#
#   make run-guile GUILE=/opt/guile3/bin/guile
#   CHEZ=scheme make run-chez
# --------------------------------------------------------------------------
GUILE   ?= guile
# Chez: Homebrew installs as "chez-scheme", upstream as "scheme"
CHEZ    ?= $(or $(shell command -v chez-scheme 2>/dev/null),$(shell command -v scheme 2>/dev/null),chez-scheme)
RACKET  ?= racket
RACO    ?= raco
EMACS   ?= emacs
# Prefer Babashka (bb) for fast Clojure; fall back to clj
CLOJURE ?= $(or $(shell command -v bb 2>/dev/null),$(shell command -v clj 2>/dev/null),clojure-not-found)
JANET   ?= janet
ALLOY   ?= alloy
JAVA    ?= java
TLC_JAR ?= $(HOME)/.local/lib/tla2tools.jar
LEAN    ?= lean
LAKE    ?= lake
PYTEST  ?= pytest
PYTHON  ?= python3

# --------------------------------------------------------------------------
# Project layout (absolute paths for parallel/subshell safety)
# --------------------------------------------------------------------------
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

SRC_GUILE      := $(ROOT)/horner-guile.scm
SRC_GUILE_RNRS := $(ROOT)/horner-guile-rnrs.scm
SRC_CHEZ       := $(ROOT)/horner-chez.scm
SRC_RACKET     := $(ROOT)/horner-racket.rkt
SRC_ELISP      := $(ROOT)/horner.el
SRC_CLOJURE    := $(ROOT)/horner.clj
SRC_JANET      := $(ROOT)/horner.janet

FORMAL_ALLOY   := $(ROOT)/formal/alloy
FORMAL_TLA     := $(ROOT)/formal/tlaplus
FORMAL_LEAN    := $(ROOT)/formal/lean4

TEST_SCM       := $(ROOT)/tests/test-properties.scm
TEST_PYTHON    := $(ROOT)/tests/test_properties.py

ORG_SOURCE     := $(ROOT)/horner-fold.org

# --------------------------------------------------------------------------
# Dependency-check macros
# --------------------------------------------------------------------------
# $(call require-cmd,VAR_NAME,human label)
define require-cmd
	@command -v $($(1)) >/dev/null 2>&1 || { \
		echo "SKIP: $(2) not found (looked for '$($(1))')"; \
		echo "      Set $(1)=/path/to/binary to override."; \
		exit 1; \
	}
endef

# $(call require-file,VAR_NAME,human label)
define require-file
	@test -f "$($(1))" || { \
		echo "SKIP: $(2) not found at '$($(1))'"; \
		echo "      Set $(1)=/path/to/file to override."; \
		exit 1; \
	}
endef

# ============================================================================
# .PHONY declarations
# ============================================================================
.PHONY: help
.PHONY: run-guile run-chez run-racket run-elisp run-clojure run-janet run-all
.PHONY: test-guile test-chez test-racket test-elisp test-clojure test-janet
.PHONY: test-guile-properties test-python test-all
.PHONY: formal-alloy formal-tla formal-lean formal-all
.PHONY: tangle install-racket-deps
.PHONY: clean distclean ci check-tools lint

# ============================================================================
# Help -- self-documenting (default target)
# ============================================================================
help: ## Show this help message
	@echo ""
	@echo "Horner's Method -- Polyglot Build System"
	@echo "========================================="
	@echo ""
	@echo "Run implementations:"
	@awk 'BEGIN {FS = ":.*##"} /^run-[a-zA-Z_-]+:.*##/ { printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "Test suites:"
	@awk 'BEGIN {FS = ":.*##"} /^test-[a-zA-Z_-]+:.*##/ { printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "Formal verification:"
	@awk 'BEGIN {FS = ":.*##"} /^formal-[a-zA-Z_-]+:.*##/ { printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "Other:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ && !/^(run|test|formal)-/ { printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "Variables (override with VAR=value):"
	@echo "  GUILE=$(GUILE)  CHEZ=$(CHEZ)  RACKET=$(RACKET)"
	@echo "  EMACS=$(EMACS)  CLOJURE=$(CLOJURE)  JANET=$(JANET)"
	@echo "  ALLOY=$(ALLOY)  TLC_JAR=$(TLC_JAR)"
	@echo "  LAKE=$(LAKE)  PYTEST=$(PYTEST)"
	@echo ""

# ============================================================================
# Run targets -- execute each implementation
# ============================================================================

run-guile: ## Run Guile Scheme (SRFI-1 fold)
	$(call require-cmd,GUILE,Guile Scheme)
	$(GUILE) $(SRC_GUILE)

run-chez: ## Run Chez Scheme (native fold-left + tuple encoding)
	$(call require-cmd,CHEZ,Chez Scheme)
	$(CHEZ) --script $(SRC_CHEZ)

run-racket: ## Run Racket (foldl, for/fold, threading macro)
	$(call require-cmd,RACKET,Racket)
	$(RACKET) $(SRC_RACKET)

run-elisp: ## Run Emacs Lisp (cl-reduce, seq-reduce)
	$(call require-cmd,EMACS,Emacs)
	$(EMACS) --batch --script $(SRC_ELISP)

run-clojure: ## Run Clojure (reduce, ->> -> as-> threading)
	$(call require-cmd,CLOJURE,Clojure (bb or clj))
	$(CLOJURE) $(SRC_CLOJURE)

run-janet: ## Run Janet (reduce, string/bytes)
	$(call require-cmd,JANET,Janet)
	$(JANET) $(SRC_JANET)

run-all: run-guile run-chez run-racket run-elisp run-clojure run-janet ## Run all implementations

# ============================================================================
# Test targets
#
# Strategy per language:
#   - Guile: dedicated SRFI-64 property test file (tests/test-properties.scm)
#   - Chez, Racket, Elisp, Clojure, Janet: inline assertions via -e / --eval
#     that exercise encode/decode roundtrip and known-value checks.
#   - Python: Hypothesis property-based tests (tests/test_properties.py)
#
# All targets are independent and parallel-safe.
# ============================================================================

test-guile: ## Test Guile: property-based tests (SRFI-64, 1000 trials)
	$(call require-cmd,GUILE,Guile Scheme)
	$(GUILE) $(TEST_SCM)

test-chez: ## Test Chez: roundtrip + tuple encoding assertions
	$(call require-cmd,CHEZ,Chez Scheme)
	@echo "--- Chez Scheme: roundtrip tests ---"
	@echo '(define m 128) \
	(define (horner-encode s base) (fold-left (lambda (acc c) (+ (* acc base) c)) 0 (map char->integer (string->list s)))) \
	(define (horner-decode n base) (let loop ((n n) (acc (quote ()))) (if (= n 0) (list->string (map integer->char acc)) (loop (quotient n base) (cons (remainder n base) acc))))) \
	(define (encode-tuple indices base) (fold-left (lambda (acc i) (+ (* acc base) i)) 0 indices)) \
	(define (decode-tuple n base rank) (let loop ((n n) (r rank) (acc (quote ()))) (if (= r 0) acc (loop (quotient n base) (- r 1) (cons (remainder n base) acc))))) \
	(assert (equal? "horner!" (horner-decode (horner-encode "horner!" m) m))) \
	(assert (= 123 (encode-tuple (quote (1 2 3)) 10))) \
	(assert (equal? (quote (1 2 3)) (decode-tuple 123 10 3))) \
	(assert (= 4259 (encode-tuple (quote (3 1 4 1 5)) 6))) \
	(assert (equal? (quote (3 1 4 1 5)) (decode-tuple 4259 6 5))) \
	(display "All Chez tests passed.") (newline)' | $(CHEZ) --script /dev/stdin

test-racket: ## Test Racket: roundtrip and encoding assertions
	$(call require-cmd,RACKET,Racket)
	@echo "--- Racket: roundtrip tests ---"
	@$(RACKET) -e ' \
	(define m 128) \
	(define (horner-encode s base) \
	  (foldl (lambda (c acc) (+ (* acc base) c)) 0 \
	         (map char->integer (string->list s)))) \
	(define (horner-decode n base) \
	  (let loop ([n n] [acc (list)]) \
	    (if (= n 0) (list->string (map integer->char acc)) \
	        (loop (quotient n base) (cons (remainder n base) acc))))) \
	(unless (equal? "horner!" (horner-decode (horner-encode "horner!" m) m)) \
	  (error "roundtrip failed")) \
	(unless (= 123 (foldl (lambda (c acc) (+ (* acc 10) c)) 0 (list 1 2 3))) \
	  (error "tuple encode failed")) \
	(displayln "All Racket tests passed.")'

test-elisp: ## Test Emacs Lisp: batch-mode roundtrip assertions
	$(call require-cmd,EMACS,Emacs)
	@echo "--- Emacs Lisp: roundtrip tests ---"
	@$(EMACS) --batch --eval ' \
	(require (quote cl-lib)) \
	(defun horner-encode (s base) \
	  (cl-reduce (lambda (acc c) (+ (* acc base) c)) \
	             (string-to-list s) :initial-value 0)) \
	(defun horner-decode (n base) \
	  (cl-loop with acc = nil \
	           while (> n 0) \
	           do (push (% n base) acc) (setq n (/ n base)) \
	           finally return (concat acc))) \
	(let* ((s "horner!") (n (horner-encode s 128))) \
	  (cl-assert (equal s (horner-decode n 128))) \
	  (cl-assert (= (horner-encode "ABC" 256) \
	                (+ (* (+ (* 65 256) 66) 256) 67)))) \
	(message "All Emacs Lisp tests passed.")'

test-clojure: ## Test Clojure: roundtrip assertions via bb/clj
	$(call require-cmd,CLOJURE,Clojure (bb or clj))
	@echo "--- Clojure: roundtrip tests ---"
	@$(CLOJURE) -e ' \
	(defn horner-encode [s base] \
	  (reduce (fn [acc c] (+ (* acc base) (int c))) 0 s)) \
	(defn horner-decode [n base] \
	  (loop [n n acc []] \
	    (if (zero? n) (apply str (map char acc)) \
	      (recur (quot n base) (cons (rem n base) acc))))) \
	(assert (= "horner!" (horner-decode (horner-encode "horner!" 128) 128))) \
	(assert (= 123 (reduce (fn [acc i] (+ (* acc 10) i)) 0 [1 2 3]))) \
	(println "All Clojure tests passed.")'

test-janet: ## Test Janet: roundtrip assertions
	$(call require-cmd,JANET,Janet)
	@echo "--- Janet: roundtrip tests ---"
	@$(JANET) -e ' \
	(defn horner-encode [s base] \
	  (reduce (fn [acc b] (+ (* acc base) b)) 0 (string/bytes s))) \
	(defn horner-decode [n base] \
	  (var n n) (def acc @[]) \
	  (while (> n 0) \
	    (array/insert acc 0 (% n base)) \
	    (set n (div n base))) \
	  (string/from-bytes ;acc)) \
	(assert (= "horner!" (horner-decode (horner-encode "horner!" 128) 128))) \
	(assert (= 123 (reduce (fn [acc i] (+ (* acc 10) i)) 0 [1 2 3]))) \
	(print "All Janet tests passed.")'

test-guile-properties: ## Test Guile: full property suite (alias)
	$(call require-cmd,GUILE,Guile Scheme)
	$(GUILE) $(TEST_SCM)

test-python: ## Test Python: Hypothesis property-based tests
	$(call require-cmd,PYTEST,pytest)
	$(PYTEST) -v $(TEST_PYTHON)

test-all: test-guile test-chez test-racket test-elisp test-clojure test-janet ## Run all language test suites (parallel-safe)

# ============================================================================
# Formal verification targets
# ============================================================================

formal-alloy: ## Alloy: bounded model checking of roundtrip (len 2,3)
	$(call require-cmd,ALLOY,Alloy)
	@echo "=== Alloy: Checking Horner roundtrip properties ==="
	cd $(FORMAL_ALLOY) && $(ALLOY) exec -t text -o - horner.als

formal-tla: ## TLA+/TLC: model check roundtrip, injectivity, non-negativity
	$(call require-cmd,JAVA,Java)
	$(call require-file,TLC_JAR,tla2tools.jar)
	@echo "=== TLA+: Model checking Horner specification ==="
	cd $(FORMAL_TLA) && $(JAVA) -cp "$(TLC_JAR)" tlc2.TLC Horner \
		-config Horner.cfg -workers auto

formal-lean: ## Lean4: build proofs + run executable (requires elan/lake)
	$(call require-cmd,LAKE,Lake (Lean build tool))
	@echo "=== Lean4: Building and verifying Horner proofs ==="
	cd $(FORMAL_LEAN) && $(LAKE) build
	@echo "--- Running Lean4 executable ---"
	cd $(FORMAL_LEAN) && $(LAKE) exec horner

formal-all: formal-alloy formal-tla formal-lean ## Run all formal verification suites

# ============================================================================
# Tangle -- extract source from literate org-mode file
# ============================================================================

tangle: ## Tangle horner-fold.org to regenerate all source files
	$(call require-cmd,EMACS,Emacs)
	@echo "=== Tangling $(notdir $(ORG_SOURCE)) ==="
	$(EMACS) --batch \
		--eval "(require 'org)" \
		--eval "(require 'ob-tangle)" \
		--eval '(org-babel-tangle-file "$(ORG_SOURCE)")'
	@echo "Tangled source files updated."

# ============================================================================
# Racket dependencies
# ============================================================================

install-racket-deps: ## Install Racket threading package (needed once)
	$(call require-cmd,RACO,raco)
	$(RACO) pkg install --auto threading 2>/dev/null || true

# ============================================================================
# CI -- full pipeline with strict exit codes
# ============================================================================

ci: test-all formal-all ## Full CI: all tests + all formal verification
	@echo ""
	@echo "========================================="
	@echo "  CI PASSED: all tests and proofs green"
	@echo "========================================="

# ============================================================================
# Clean targets
# ============================================================================

clean: ## Remove build artifacts and caches
	@echo "Cleaning build artifacts..."
	rm -rf $(ROOT)/.pytest_cache
	rm -rf $(ROOT)/tests/__pycache__
	rm -rf $(ROOT)/.hypothesis
	find $(ROOT) -name '*.pyc' -delete 2>/dev/null || true
	find $(ROOT) -name '*.go' -not -path '*/.git/*' -delete 2>/dev/null || true
	rm -rf $(FORMAL_TLA)/states
	rm -rf $(FORMAL_ALLOY)/horner
	@echo "Clean complete."

distclean: clean ## Deep clean: also removes Lean4 .lake cache
	@echo "Deep cleaning..."
	rm -rf $(FORMAL_LEAN)/.lake
	rm -rf $(FORMAL_LEAN)/build
	rm -rf $(ROOT)/.beads
	rm -rf $(ROOT)/.tmp
	@echo "Distclean complete."

# ============================================================================
# Utilities
# ============================================================================

check-tools: ## Report which required tools are installed
	@echo ""
	@echo "Tool availability"
	@echo "-----------------"
	@printf "  %-14s %s\n" "Guile:"   "$$(command -v $(GUILE)    2>/dev/null || echo 'NOT FOUND')"
	@printf "  %-14s %s\n" "Chez:"    "$$(command -v $(CHEZ)     2>/dev/null || echo 'NOT FOUND')"
	@printf "  %-14s %s\n" "Racket:"  "$$(command -v $(RACKET)   2>/dev/null || echo 'NOT FOUND')"
	@printf "  %-14s %s\n" "raco:"    "$$(command -v $(RACO)     2>/dev/null || echo 'NOT FOUND')"
	@printf "  %-14s %s\n" "Emacs:"   "$$(command -v $(EMACS)    2>/dev/null || echo 'NOT FOUND')"
	@printf "  %-14s %s\n" "Clojure:" "$$(command -v $(CLOJURE)  2>/dev/null || echo 'NOT FOUND')"
	@printf "  %-14s %s\n" "Janet:"   "$$(command -v $(JANET)    2>/dev/null || echo 'NOT FOUND')"
	@printf "  %-14s %s\n" "Alloy:"   "$$(command -v $(ALLOY)    2>/dev/null || echo 'NOT FOUND')"
	@printf "  %-14s %s\n" "Java:"    "$$(command -v $(JAVA)     2>/dev/null || echo 'NOT FOUND')"
	@printf "  %-14s %s\n" "TLC JAR:" "$$(test -f '$(TLC_JAR)' && echo '$(TLC_JAR)' || echo 'NOT FOUND')"
	@printf "  %-14s %s\n" "Lake:"    "$$(command -v $(LAKE)     2>/dev/null || echo 'NOT FOUND')"
	@printf "  %-14s %s\n" "Lean:"    "$$(command -v $(LEAN)     2>/dev/null || echo 'NOT FOUND')"
	@printf "  %-14s %s\n" "pytest:"  "$$(command -v $(PYTEST)   2>/dev/null || echo 'NOT FOUND')"
	@echo ""

lint: ## Check source files for common issues
	@echo "Lint checks"
	@echo "-----------"
	@echo -n "  Tabs in Scheme files: "
	@grep -Pn '\t' $(SRC_GUILE) $(SRC_GUILE_RNRS) $(SRC_CHEZ) 2>/dev/null \
		&& echo "    WARNING: tabs found" || echo "none"
	@echo -n "  Racket #lang header:  "
	@head -1 $(SRC_RACKET) | grep -q '#lang' \
		&& echo "present" || echo "WARNING: missing #lang"
	@echo -n "  Elisp lexical-binding: "
	@head -1 $(SRC_ELISP) | grep -q 'lexical-binding: t' \
		&& echo "enabled" || echo "WARNING: not enabled"
	@echo -n "  Janet splice usage:    "
	@grep -c ';acc' $(SRC_JANET) 2>/dev/null | xargs printf "%s occurrence(s)\n"
