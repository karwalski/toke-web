TKC = /Users/matthew.watt/tk/toke/tkc
BIN = ./website

all: $(BIN)

$(BIN): main.tk
	$(TKC) --out $(BIN) main.tk

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
	rm -f $(BIN)

.PHONY: all run run-http certs clean
