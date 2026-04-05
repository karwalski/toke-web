---
title: "std.auth"
description: "JWT signing/verification, API key generation, and bearer token extraction."
---

**Status: Implemented** -- C runtime backing.

The `std.auth` module provides authentication primitives: JWT creation and validation, API key generation, and bearer token extraction from HTTP headers.

## Types

### $JwtAlg (sum type)

| Variant | Meaning |
|---------|---------|
| Hs256 | HMAC-SHA256 |
| Hs384 | HMAC-SHA384 |
| Rs256 | RSA-SHA256 |

### $JwtClaims

| Field | Type | Meaning |
|-------|------|---------|
| sub | $str | Subject identifier |
| iss | $str | Issuer |
| exp | u64 | Expiration time (Unix epoch seconds) |
| iat | u64 | Issued-at time (Unix epoch seconds) |
| extra | @(@($str)) | Additional key-value claim pairs |

### $AuthErr

| Field | Type | Meaning |
|-------|------|---------|
| msg | $str | Error description |
| code | u64 | Error code |

### $Keystore

| Field | Type | Meaning |
|-------|------|---------|
| handle | u64 | Opaque handle to a key store |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `auth.jwtsign` | `claims: $JwtClaims; secret: @($byte); alg: $JwtAlg` | `$str!$AuthErr` | Sign claims into a JWT string |
| `auth.jwtverify` | `token: $str; secret: @($byte)` | `$JwtClaims!$AuthErr` | Verify a JWT and extract its claims |
| `auth.jwtexpired` | `claims: $JwtClaims` | `$bool` | Check whether a JWT's claims have expired |
| `auth.apikeygenerate` | `prefix: $str` | `$str` | Generate a random API key with the given prefix |
| `auth.apikeyvalidate` | `key: $str; store: $Keystore` | `$bool!$AuthErr` | Validate an API key against a key store |
| `auth.bearerextract` | `header: $str` | `$str!$AuthErr` | Extract the token from a `Bearer <token>` header value |

## Usage

```toke
use std.auth

f=main():i64{
  let claims = auth.$JwtClaims{
    sub="user:42"
    iss="myapp"
    exp=1700000000
    iat=1699990000
    extra=@()
  }
  let token = auth.jwtsign(claims; "mysecret".bytes; auth.$JwtAlg.Hs256)
  let verified = auth.jwtverify(token|{Ok:t t;Err:e ""}; "mysecret".bytes)
  <0
}
```

## Dependencies

- `std.encoding` -- Base64 encoding for JWT segments.
- `std.crypto` -- HMAC and hash functions.
