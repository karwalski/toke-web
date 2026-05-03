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

clean:
	rm -f $(BIN) main.ll

.PHONY: all run run-http certs clean
