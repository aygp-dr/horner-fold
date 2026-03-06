---
name: gnu-makefile
description: Write, review, and debug GNU Makefiles. Use when creating or modifying Makefiles, debugging make errors, or when the user mentions make, gmake, or build systems using Make. Covers evaluation semantics, variable assignment, $(call), $(eval), recipe syntax, and common pitfalls.
compatibility: Requires GNU Make (gmake on macOS/FreeBSD)
metadata:
  author: jwalsh
  version: "1.0"
---

# GNU Makefile Skill

## Evaluation Model

Make has two evaluation phases: parse time (when the file is read) and recipe time (when targets are built). Most bugs come from confusing the two.

### Variable Assignment
- `=` (recursive/deferred): template, expands at use site. Required for functions using `$(1)`, `$(2)`.
- `:=` (simple/immediate): expands once at parse time. Use for data, constants, precomputed values.
- `?=` (conditional): assign only if not already set.
- `+=` (append): adds to existing value, inherits flavor from original.

### The Staging Footgun

Deferred (`=`) variables are stage-1 templates. Immediate (`:=`) variables are stage-0 values. Confusing the two is the most common Make bug:

```makefile
# WRONG: $(1) unbound at parse time, silently empty
_result := $(call my_func,$(input))

# RIGHT: freeze after calling
_result := $(call my_func,value)

# RIGHT: keep deferred if needs call-time binding
result = $(call my_func,$(1))
```

### $(call) Semantics
- `$(call fn,a,b,c)` binds `$(1)=a`, `$(2)=b`, `$(3)=c` then expands variable `fn`.
- Positional params are dynamically scoped -- they leak into nested expansions of deferred variables.
- Extra arguments silently ignored. Missing arguments expand to empty.
- Functions are strings naming other variables. No closures, no currying.

### $(eval) as Splice
- Expands its argument, parses the result as Makefile syntax, returns empty string.
- It is a side effect, not a value.
- Use `:=` inside eval to freeze: `$(eval VAR := $(call f,x))`.
- Variables set via eval are global and not reentrant.

## Recipe Syntax
- Recipe lines MUST start with a literal tab, never spaces.
- Each line runs in a separate shell invocation.
- `@` suppresses command echo. `-` ignores errors.
- `$$` passes a single `$` to the shell: `@echo $$HOME`.
- Multi-line: use `&&` to chain, or `\` for continuation (same shell).

## Validation Checklist

When writing or reviewing, check:
1. Tabs not spaces in recipes
2. `.PHONY` for non-file targets
3. `:=` for data, `=` for functions -- never reversed
4. `$(shell)` results frozen with `:=`
5. `$$` in recipes for shell variables
6. No circular dependencies
7. `$(call)` argument count matches function arity
8. `$(eval)` variables won't collide in iteration
9. POSIX sh in `$(shell)` calls (avoid bashisms)
10. Default goal is correct (`.DEFAULT_GOAL` or first target)

## Debugging

```makefile
# Inline diagnostics (parse-time)
$(info DEBUG: var=$(VAR))
$(warning something unexpected)
$(error fatal: missing VAR)
```

```bash
# From shell
gmake -n target          # dry run
gmake -p | grep '^VAR'   # print variable database
gmake --trace target     # trace rule execution (GNU Make 4.1+)
```

## Anti-Patterns
- Recursive make (`$(MAKE) -C subdir`) when `include` would suffice
- `$(shell)` in deferred variables (re-runs on every expansion)
- `export` of large variables into recipe environment
- `.SECONDARY` / `.PRECIOUS` to mask dependency errors
- Rules unsafe under `make -j` (missing inter-target dependencies)

## Platform Notes

On macOS/FreeBSD, use `gmake` not `make` (BSD make has different syntax). See [evaluation reference](references/evaluation.md) for the full function reference and [patterns](references/patterns.md) for common idioms.
