# Common GNU Make Patterns

## Project Template

```makefile
.DEFAULT_GOAL := all
.PHONY: all clean test lint

# ── Configuration ─────────────────────────────
CC       := gcc
CFLAGS   := -Wall -Wextra -O2
SRCS     := $(wildcard src/*.c)
OBJS     := $(SRCS:.c=.o)
TARGET   := myapp

# ── Build Rules ───────────────────────────────
all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^

src/%.o: src/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJS) $(TARGET)

test: $(TARGET)
	./$(TARGET) --test
```

## Self-Documenting Help

```makefile
.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

build: ## Build the project
	...

test: ## Run tests
	...
```

## Generated Rules

```makefile
# Define a template
define service_rule
.PHONY: $(1)-start $(1)-stop
$(1)-start:
	docker compose up -d $(1)
$(1)-stop:
	docker compose stop $(1)
endef

SERVICES := api worker redis

$(foreach s,$(SERVICES),$(eval $(call service_rule,$(s))))
```

## Dependency Tracking (C/C++)

```makefile
DEPFLAGS = -MT $@ -MMD -MP -MF deps/$*.d
DEPDIR   := deps

src/%.o: src/%.c | $(DEPDIR)
	$(CC) $(CFLAGS) $(DEPFLAGS) -c -o $@ $<

$(DEPDIR):
	mkdir -p $@

-include $(SRCS:src/%.c=deps/%.d)
```

## Recursive Wildcard (all subdirectories)

```makefile
rwildcard = $(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
ALL_GO := $(call rwildcard,.,*.go)
```

## Conditional Compilation

```makefile
ifeq ($(DEBUG),1)
  CFLAGS += -g -DDEBUG
else
  CFLAGS += -O2 -DNDEBUG
endif

# Or inline:
CFLAGS += $(if $(filter 1,$(DEBUG)),-g -DDEBUG,-O2 -DNDEBUG)
```

## Parallel-Safe Ordering

```makefile
# BAD: make -j may run test before build finishes
all: build test

# GOOD: explicit dependency
test: build
	./run-tests.sh

# GOOD: order-only prerequisite (does not trigger rebuild)
output/report.html: | output
output:
	mkdir -p $@
```

## Environment / .env Loading

```makefile
# Load .env if it exists
-include .env
export

# Or selectively:
ifneq (,$(wildcard .env))
  include .env
  export DATABASE_URL
endif
```

## Version Stamping

```makefile
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS += -X main.version=$(VERSION)
```

## Multi-Platform

```makefile
UNAME := $(shell uname -s)
ifeq ($(UNAME),Darwin)
  SED := gsed
  MAKE := gmake
else
  SED := sed
  MAKE := make
endif
```
