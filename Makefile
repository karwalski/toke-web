# The reference compiler. Override with TKC=/path/to/tkc (CI does).
TKC ?= $(HOME)/tk/toke/tkc
TOKE = $(TKC)
TOKE_REPO ?= $(HOME)/tk/toke
TOKE_STDLIB = $(TOKE_REPO)/src/stdlib
BIN = ./website

TOKE_VENDOR = $(TOKE_REPO)/stdlib/vendor
CFLAGS = -std=c99 -D_GNU_SOURCE -O1 -iquote $(TOKE_STDLIB) \
  -I$(TOKE_VENDOR)/cmark/src -I$(TOKE_VENDOR)/tomlc99 \
  -Wno-pedantic -DTK_HAVE_OPENSSL
LIBS = -lssl -lcrypto -lz -lm -lsqlite3 -lpthread
UNAME = $(shell uname -s)
ifeq ($(UNAME), Darwin)
  CFLAGS += -I/opt/homebrew/include
  LDFLAGS = -L/opt/homebrew/lib
endif

STDLIB_C = $(filter-out $(TOKE_STDLIB)/llm_tool.c $(TOKE_STDLIB)/secure_mem.c $(TOKE_STDLIB)/infer_stream.c,$(wildcard $(TOKE_STDLIB)/*.c))
CMARK_C = $(filter-out $(TOKE_VENDOR)/cmark/src/main.c,$(wildcard $(TOKE_VENDOR)/cmark/src/*.c))
TOML_C = $(TOKE_VENDOR)/tomlc99/toml.c
VENDOR_C = $(CMARK_C) $(TOML_C)

all: $(BIN)

main.ll: main.tk
	$(TOKE) --emit-llvm --out main.ll main.tk

$(BIN): main.ll
	clang $(CFLAGS) $(LDFLAGS) -x ir main.ll -x c $(STDLIB_C) $(VENDOR_C) -o $@ $(LIBS) -framework Security -framework CoreFoundation

run: $(BIN)
	@echo "Serving on https://staging.tokelang.dev:9443"
	$(BIN)

run-http: $(BIN)
	$(BIN) --port 9080

certs/cert.pem certs/key.pem:
	mkdir -p certs
	openssl req -x509 -newkey rsa:2048 \
	  -keyout certs/key.pem -out certs/cert.pem \
	  -days 365 -nodes \
	  -subj "/C=AU/ST=NSW/O=toke/CN=tokelang.dev" \
	  -addext "subjectAltName=DNS:tokelang.dev,DNS:www.tokelang.dev,DNS:staging.tokelang.dev,DNS:loke.tokelang.dev,DNS:localhost,IP:127.0.0.1"

certs: certs/cert.pem certs/key.pem

dev: $(BIN)
	@echo "Development server: http://localhost:3000"
	$(BIN) --http --port 3000

clean:
	rm -f $(BIN) main.ll
	rm -rf build-docs

# --- Toke source gate (story 132.17a) ---

# Every toke source the site is BUILT from must compile under the pinned
# compiler. main.tk sat at HEAD for months as v0.3 `=`-equality that tkc 2.8.0
# rejects, so the site could not be rebuilt from its own source until a worker
# migrated it by hand. This target is the gate that stops that recurring; the CI
# workflow and `make ci` both run it, and it fails the build.
TOKE_SRC = main.tk

# pages/*.tk is not compiled, but it is no longer dead (story 134.8): `ooke
# build` derives one route per pages/**/*.tk *filename* — pages/docs/about/
# [slug].tk is what makes /docs/about/<slug> a page at all — so deleting the
# tree would delete the ~195 documentation pages. Their bodies are still
# pre-v0.3 (`match`/`err(e)` syntax, an `ooke.template` import with no interface
# path) and most do not compile; that only matters for `ooke serve`/`ooke
# compile`, which the site does not use, so it is reported below rather than
# gated. Migrating the bodies is story 132.17 / 134.2 work.
TOKE_SRC_UNUSED = $(shell find pages -name '*.tk' 2>/dev/null | sort)

check-toke:
	@if [ ! -x "$(TKC)" ] && ! command -v $(TKC) >/dev/null 2>&1; then \
		echo "ERROR: tkc not found at '$(TKC)'. Set TKC=/path/to/tkc." >&2; \
		exit 1; \
	fi; \
	echo "=== tkc --check: toke sources the site is built from ==="; \
	fail=0; \
	for f in $(TOKE_SRC); do \
		if $(TKC) --check "$$f" >/dev/null 2>&1; then \
			echo "  PASS  $$f"; \
		else \
			echo "  FAIL  $$f"; $(TKC) --check "$$f" 2>&1 | head -5 | sed 's/^/        /'; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	if [ -n "$(TOKE_SRC_UNUSED)" ]; then \
		up=0; uf=0; \
		for f in $(TOKE_SRC_UNUSED); do \
			if $(TKC) --check "$$f" >/dev/null 2>&1; then up=$$((up + 1)); else uf=$$((uf + 1)); fi; \
		done; \
		echo ""; \
		echo "  note: pages/ supplies the ooke build's route names only — $$up compile, $$uf do not."; \
		echo "        Not gated: the static build reads filenames, not bodies (story 134.8)."; \
	fi; \
	echo ""; \
	if [ $$fail -ne 0 ]; then echo "check-toke FAILED ($$fail source(s))"; exit 1; fi; \
	echo "check-toke passed"

# --- Static output (story 132.17b) ---

# build/ is gitignored but the deploy rsyncs it, so it must be reproducible from
# committed sources alone. This remakes it from scratch.
build: ## Rebuild build/ from static/ and render /docs with ooke
	./scripts/build_static.sh

# content/docs/ is not authored here: it is the canonical documentation in the
# toke repo, linked in per section. `make build` cannot render the ~195
# /docs/<section>/<slug> pages without it (story 134.8).
OOKE ?= $(HOME)/tk/toke-ooke/ooke-toke

docs-content:
	TOKE_REPO="$(TOKE_REPO)" ./scripts/sync_docs_content.sh

# Fail if build/ is older than the sources it is derived from. The deploy runs
# this after rebuilding, so a stale tree can never be published.
check-build-fresh:
	@python3 scripts/check_build_fresh.py

# Start the site and assert every route it defines answers 200.
check-routes: $(BIN) build
	@./scripts/check_routes.sh

# --- Generated content ---

# The /roadmap page and the home-page milestones block are generated from ONE
# source (content/roadmap.json) so the two pages cannot disagree (story 132.9).
roadmap:
	python3 scripts/gen_roadmap.py

check-roadmap:
	python3 scripts/gen_roadmap.py --check

# /llms.txt is generated from the canonical facts block so it cannot drift.
llms:
	python3 scripts/gen_llms.py

check-llms:
	python3 scripts/gen_llms.py --check

# Everything a change to this repo must pass before it is deployed.
ci: check-toke check-roadmap check-llms docs-content build check-build-fresh check-routes
	@echo ""; echo "=== CI checks passed ==="

# --- Documentation checks ---

DOCS_DIR ?= $(TOKE_REPO)/docs
EXAMPLES_DIR = $(DOCS_DIR)/examples
ifeq ($(UNAME), Darwin)
  LINK_FRAMEWORKS = -framework Security -framework CoreFoundation
endif

check-docs: check-docs-examples check-docs-runtime
	@echo ""; echo "=== Documentation check complete ==="

check-docs-examples:
	@echo "=== Checking doc examples compile (toke --check) ==="; \
	pass=0; fail=0; total=0; \
	for f in $(EXAMPLES_DIR)/*.tk; do \
		[ -f "$$f" ] || continue; \
		total=$$((total + 1)); \
		base=$$(basename "$$f"); \
		if $(TOKE) --check "$$f" >/dev/null 2>&1; then \
			echo "  PASS  $$base"; \
			pass=$$((pass + 1)); \
		else \
			echo "  FAIL  $$base"; \
			fail=$$((fail + 1)); \
		fi; \
	done; \
	echo ""; echo "Results: $$pass passed, $$fail failed ($$total total)"; \
	[ $$fail -eq 0 ]

check-docs-runtime:
	@echo "=== Checking doc examples runtime output ==="; \
	pass=0; fail=0; skip=0; total=0; \
	for f in $(EXAMPLES_DIR)/*.tk; do \
		[ -f "$$f" ] || continue; \
		base=$$(basename "$$f" .tk); \
		expected="$(EXAMPLES_DIR)/expected/$$base.expected"; \
		if [ ! -f "$$expected" ]; then \
			skip=$$((skip + 1)); \
			continue; \
		fi; \
		total=$$((total + 1)); \
		tmpll=$$(mktemp /tmp/toke-check-XXXXXX.ll); \
		tmpbin=$$(mktemp /tmp/toke-check-XXXXXX); \
		tmpout=$$(mktemp /tmp/toke-check-XXXXXX.out); \
		if $(TOKE) --emit-llvm --out "$$tmpll" "$$f" 2>/dev/null && \
		   clang $(CFLAGS) $(LDFLAGS) -x ir "$$tmpll" -x c $(STDLIB_C) $(VENDOR_C) \
		     -o "$$tmpbin" $(LIBS) $(LINK_FRAMEWORKS) 2>/dev/null; then \
			$$tmpbin > "$$tmpout" 2>&1; \
			if diff -q "$$tmpout" "$$expected" >/dev/null 2>&1; then \
				echo "  PASS  $$base"; \
				pass=$$((pass + 1)); \
			else \
				echo "  FAIL  $$base (output mismatch)"; \
				diff "$$tmpout" "$$expected" | head -10; \
				fail=$$((fail + 1)); \
			fi; \
		else \
			echo "  FAIL  $$base (compile error)"; \
			fail=$$((fail + 1)); \
		fi; \
		rm -f "$$tmpll" "$$tmpbin" "$$tmpout"; \
	done; \
	echo ""; echo "Results: $$pass passed, $$fail failed, $$skip skipped (no .expected)"; \
	[ $$fail -eq 0 ]

# --- Deployment ---

deploy: ## Full deploy (rebuild binary + all content)
	./scripts/deploy.sh full

deploy-content: ## Content-only deploy (templates, static, sites — no rebuild)
	./scripts/deploy.sh content

deploy-auto: ## Auto-detect deploy mode based on git changes
	./scripts/deploy.sh auto

.PHONY: all run run-http dev certs clean roadmap check-roadmap llms check-llms ci check-toke build docs-content check-build-fresh check-routes check-docs check-docs-examples check-docs-runtime deploy deploy-content deploy-auto
