---
title: "std.encrypt"
description: "AES-256-GCM symmetric encryption, X25519 key exchange, Ed25519 signatures, and HKDF key derivation."
---

**Status: Implemented** -- C runtime backing.

The `std.encrypt` module provides high-level cryptographic primitives: authenticated encryption (AES-256-GCM), Diffie-Hellman key agreement (X25519), digital signatures (Ed25519), and key derivation (HKDF-SHA256).

## Types

### $DecryptResult

| Field | Type | Meaning |
|-------|------|---------|
| ok | @($byte) | Decrypted plaintext on success |
| err | $str | Error message on failure |

### $Keypair

| Field | Type | Meaning |
|-------|------|---------|
| pubkey | @($byte) | Public key bytes |
| privkey | @($byte) | Private key bytes |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `encrypt.aes256gcm_encrypt` | `key: @($byte); nonce: @($byte); plaintext: @($byte); aad: @($byte)` | `@($byte)` | Encrypt with AES-256-GCM; returns ciphertext+tag |
| `encrypt.aes256gcm_decrypt` | `key: @($byte); nonce: @($byte); ciphertext: @($byte); aad: @($byte)` | `$DecryptResult` | Decrypt with AES-256-GCM |
| `encrypt.aes256gcm_keygen` | | `@($byte)` | Generate a random 256-bit key |
| `encrypt.aes256gcm_noncegen` | | `@($byte)` | Generate a random 96-bit nonce |
| `encrypt.x25519_keypair` | | `$Keypair` | Generate an X25519 key pair |
| `encrypt.x25519_dh` | `privkey: @($byte); pubkey: @($byte)` | `@($byte)` | Compute shared secret via Diffie-Hellman |
| `encrypt.ed25519_keypair` | | `$Keypair` | Generate an Ed25519 signing key pair |
| `encrypt.ed25519_sign` | `privkey: @($byte); msg: @($byte)` | `@($byte)` | Sign a message with Ed25519 |
| `encrypt.ed25519_verify` | `pubkey: @($byte); msg: @($byte); sig: @($byte)` | `$bool` | Verify an Ed25519 signature |
| `encrypt.hkdf_sha256` | `ikm: @($byte); salt: @($byte); info: @($byte); len: u64` | `@($byte)` | Derive a key using HKDF-SHA256 |
| `encrypt.tls_cert_fingerprint` | `host: $str` | `@($byte)` | Get the SHA-256 fingerprint of a TLS certificate |

## Usage

```toke
use std.encrypt

f=main():i64{
  let key = encrypt.aes256gcm_keygen()
  let nonce = encrypt.aes256gcm_noncegen()
  let ct = encrypt.aes256gcm_encrypt(key; nonce; "secret".bytes; @())
  let pt = encrypt.aes256gcm_decrypt(key; nonce; ct; @())
  <0
}
```

## Dependencies

- `std.crypto` -- hash primitives used internally.
