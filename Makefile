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

# 132.44 — every toke program the site publishes must compile, and the green
# tick on /tokens is WRITTEN from that compile result rather than typed by hand.
# `--write` re-derives the badges; `--check` fails when a badge disagrees with
# the compiler. The home page's cl100k_base counts are re-derived with tiktoken
# at the same time.
site-examples:
	TKC="$(TKC)" python3 scripts/verify_site_examples.py --write

check-site-examples:
	TKC="$(TKC)" python3 scripts/verify_site_examples.py --check

# 132.36 — the stdlib module count on the home page is FILLED from the fact sheet
# the compiler repo derives from the tree, never typed. templates/index.tkt marks
# it `<!--fact:stdlib_modules-->57<!--/fact-->`; the deriving script lives in the
# toke repo, next to the tree it reads (the same arrangement as gen_llms.py, which
# reads the canonical block from $(TOKE_REPO)/docs).
FACTS_SCRIPT = $(TOKE_REPO)/scripts/verify_project_facts.py

facts:
	python3 $(FACTS_SCRIPT) --sync $(CURDIR)/templates/index.tkt

check-facts:
	python3 $(FACTS_SCRIPT) --sync-check $(CURDIR)/templates/index.tkt

# Everything a change to this repo must pass before it is deployed.
ci: check-toke check-site-examples check-facts check-roadmap check-llms docs-content build check-build-fresh check-routes
	@echo ""; echo "=== CI checks passed ==="

# --- Documentation checks (story 132.41) ---

# There is no documentation gate in this repository, deliberately.
#
# Until 132.41 there was a `check-docs` target here that looped over
# `$(TOKE_REPO)/docs/examples` — a directory that has never existed in any
# revision of either repository. The loop ran zero times, printed
# "0 passed, 0 failed (0 total)" and exited 0. It was not in `ci:` either, so
# nothing ever read the lie. It has been deleted rather than pointed somewhere
# real, because the documentation it claimed to check is NOT owned here.
#
# The real gate is in the compiler repository, where the docs live:
#
#   cd ~/tk/toke && make check-docs
#     -> scripts/check_doc_examples.py --self-test   (negative control)
#        scripts/check_doc_examples.py docs          (437 blocks, compiled AND linked)
#
# It runs in that repo's `make ci` and, since 132.41, in its GitHub workflow.
# Duplicating it here would re-create the cross-repo read that 127.88 removed
# and give the project two gates to drift apart; one gate, in the repo that
# owns the files, is the whole point.
#
# scripts/validate_examples.py was a second, weaker copy of that gate (front
# end only, an `<!-- skip-check -->` escape hatch in the prose, a header
# comment naming two trees that no longer exist) referenced by no target, no
# workflow and no script. Deleted by 132.41.
#
# What this repository DOES owe a gate is its own published toke: the samples
# in `templates/` and `static/*.html`. That is `check-site-examples`
# (scripts/verify_site_examples.py, story 132.44) — a different job needing an
# extractor that understands `.tkt` interpolation and HTML entities, which is
# why the deleted `for f in *.tk` loop could never have grown into it.

# --- Deployment ---

deploy: ## Full deploy (rebuild binary + all content)
	./scripts/deploy.sh full

deploy-content: ## Content-only deploy (templates, static, sites — no rebuild)
	./scripts/deploy.sh content

deploy-auto: ## Auto-detect deploy mode based on git changes
	./scripts/deploy.sh auto

.PHONY: site-examples check-site-examples facts check-facts all run run-http dev certs clean roadmap check-roadmap llms check-llms ci check-toke build docs-content check-build-fresh check-routes deploy deploy-content deploy-auto
