TOKE = /Users/matthew.watt/tk/toke/toke
TOKE_STDLIB = /Users/matthew.watt/tk/toke/src/stdlib
BIN = ./website

TOKE_VENDOR = /Users/matthew.watt/tk/toke/stdlib/vendor
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

# --- Documentation checks ---

DOCS_DIR = /Users/matthew.watt/tk/docs
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

.PHONY: all run run-http dev certs clean check-docs check-docs-examples check-docs-runtime deploy deploy-content deploy-auto
