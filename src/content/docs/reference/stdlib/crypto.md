---
title: "std.crypto"
description: "Cryptographic hash functions -- SHA-256, HMAC-SHA-256, and hex encoding."
---

**Status: Implemented** -- C runtime backing.

The `std.crypto` module provides cryptographic hash and HMAC functions. The implementation is self-contained with no external dependencies beyond libc. All functions are infallible.

## Functions

### crypto.sha256(data: @($byte)): @($byte)

Computes the SHA-256 digest of `data`. Returns a 32-byte array containing the hash.

```toke
let hash = crypto.sha256(str.bytes("abc"));
let hex = crypto.toHex(hash);
(* hex = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" *)
```

### crypto.hmacSha256(key: @($byte); data: @($byte)): @($byte)

Computes the HMAC-SHA-256 message authentication code using the given `key` and `data`. Returns a 32-byte array containing the tag.

```toke
let key = str.bytes("key");
let msg = str.bytes("The quick brown fox jumps over the lazy dog");
let tag = crypto.hmacSha256(key; msg);
let hex = crypto.toHex(tag);
(* hex = "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8" *)
```

### crypto.toHex(data: @($byte)): $str

Converts a byte array to a lowercase hexadecimal string (2 characters per byte).

```toke
let hash = crypto.sha256(str.bytes("abc"));
let hex = crypto.toHex(hash);
(* hex is a 64-character lowercase hex string *)

let single = crypto.toHex(@(0xde));
(* single = "de" *)

let empty = crypto.toHex(@());
(* empty = "" *)
```

## Usage Examples

```toke
(* Hash a password *)
let pwHash = crypto.toHex(crypto.sha256(str.bytes("s3cret")));

(* Sign an API request with HMAC *)
let secret = str.bytes(env.get("HMAC_SECRET") |{ "default" });
let payload = str.bytes("amount=100&currency=usd");
let sig = crypto.toHex(crypto.hmacSha256(secret; payload));
log.info("signed request"; @(@("signature"; sig)));
```
