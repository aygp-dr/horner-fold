# GNU Make Function Reference

## String Functions

| Function | Signature | Description |
|---|---|---|
| `subst` | `$(subst from,to,text)` | Replace all occurrences of `from` with `to` in `text` |
| `patsubst` | `$(patsubst pattern,replacement,text)` | Pattern substitution. `%` is the wildcard |
| `strip` | `$(strip text)` | Remove leading/trailing whitespace, collapse internal |
| `findstring` | `$(findstring find,text)` | Returns `find` if it appears in `text`, else empty |
| `filter` | `$(filter patterns,text)` | Keep words matching any pattern |
| `filter-out` | `$(filter-out patterns,text)` | Remove words matching any pattern |
| `sort` | `$(sort list)` | Sort words lexicographically AND deduplicate |
| `word` | `$(word n,text)` | Return the nth word (1-indexed) |
| `wordlist` | `$(wordlist s,e,text)` | Return words s through e |
| `words` | `$(words text)` | Count words |
| `firstword` | `$(firstword text)` | First word (equivalent to `$(word 1,text)`) |
| `lastword` | `$(lastword text)` | Last word (GNU Make 3.81+) |

## File Name Functions

| Function | Signature | Description |
|---|---|---|
| `dir` | `$(dir names)` | Extract directory part (`src/foo.c` -> `src/`) |
| `notdir` | `$(notdir names)` | Extract non-directory part (`src/foo.c` -> `foo.c`) |
| `suffix` | `$(suffix names)` | Extract suffix (`.c`, `.o`) |
| `basename` | `$(basename names)` | Remove suffix |
| `addsuffix` | `$(addsuffix suffix,names)` | Append suffix to each word |
| `addprefix` | `$(addprefix prefix,names)` | Prepend prefix to each word |
| `join` | `$(join list1,list2)` | Pairwise concatenation |
| `wildcard` | `$(wildcard pattern)` | Shell glob expansion at parse time |
| `realpath` | `$(realpath names)` | Canonical absolute path (GNU Make 3.81+) |
| `abspath` | `$(abspath names)` | Absolute path without resolving symlinks |

## Conditional Functions

| Function | Signature | Description |
|---|---|---|
| `if` | `$(if cond,then,else)` | Non-empty string is true. Short-circuits |
| `or` | `$(or a,b,c)` | First non-empty argument (GNU Make 3.81+) |
| `and` | `$(and a,b,c)` | Last argument if all non-empty, else empty |

## Iteration and Higher-Order

| Function | Signature | Description |
|---|---|---|
| `foreach` | `$(foreach var,list,body)` | Map: expand body for each word in list |
| `call` | `$(call fn,a,b,c)` | Expand variable `fn` with `$(1)=a`, `$(2)=b`, `$(3)=c` |
| `eval` | `$(eval text)` | Parse text as Makefile syntax. Returns empty |
| `value` | `$(value var)` | Raw unexpanded value of a variable |

## Shell and System

| Function | Signature | Description |
|---|---|---|
| `shell` | `$(shell cmd)` | Run cmd in sh, return stdout. Newlines become spaces |
| `info` | `$(info text)` | Print to stdout at parse time. Returns empty |
| `warning` | `$(warning text)` | Print to stderr with file:line prefix |
| `error` | `$(error text)` | Print to stderr and abort |
| `file` | `$(file op,name,text)` | Read/write files (GNU Make 4.0+) |

## Variable Inspection

| Function | Signature | Description |
|---|---|---|
| `origin` | `$(origin var)` | How var was defined: undefined, default, environment, file, command line, override, automatic |
| `flavor` | `$(flavor var)` | Variable type: undefined, recursive, simple |

## Automatic Variables (in recipes only)

| Variable | Meaning |
|---|---|
| `$@` | Target name |
| `$<` | First prerequisite |
| `$^` | All prerequisites (deduplicated) |
| `$+` | All prerequisites (with duplicates) |
| `$?` | Prerequisites newer than target |
| `$*` | Stem matched by `%` in pattern rules |
| `$(@D)`, `$(@F)` | Directory and filename parts of `$@` |
