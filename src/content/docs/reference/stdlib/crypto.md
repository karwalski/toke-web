---
title: std.crypto
description: Cryptographic functions — hashing, HMAC, and random byte generation.
---

The `std.crypto` module provides cryptographic hashing, HMAC computation, and secure random number generation.

## Import

```toke
I=crypto:std.crypto;
```

## Functions

### crypto.sha256

Computes the SHA-256 hash of a string.

```toke
F=sha256(input: Str): Str;
```

**Parameters:**

| Name    | Type  | Description            |
|---------|-------|------------------------|
| `input` | `Str` | The string to hash     |

**Returns:** `Str` — the hex-encoded SHA-256 digest.

**Example:**

```toke
let hash = crypto.sha256("hello");
// hash = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
```

---

### crypto.sha512

Computes the SHA-512 hash of a string.

```toke
F=sha512(input: Str): Str;
```

**Parameters:**

| Name    | Type  | Description            |
|---------|-------|------------------------|
| `input` | `Str` | The string to hash     |

**Returns:** `Str` — the hex-encoded SHA-512 digest.

---

### crypto.hmac_sha256

Computes an HMAC-SHA256 message authentication code.

```toke
F=hmac_sha256(key: Str; message: Str): Str;
```

**Parameters:**

| Name      | Type  | Description         |
|-----------|-------|---------------------|
| `key`     | `Str` | The HMAC key        |
| `message` | `Str` | The message to sign |

**Returns:** `Str` — the hex-encoded HMAC-SHA256 value.

**Example:**

```toke
let mac = crypto.hmac_sha256("secret", "payload");
```

---

### crypto.random_bytes

Generates cryptographically secure random bytes, returned as a hex string.

```toke
F=random_bytes(n: u64): Str;
```

**Parameters:**

| Name | Type  | Description                   |
|------|-------|-------------------------------|
| `n`  | `u64` | Number of random bytes        |

**Returns:** `Str` — hex-encoded random bytes (length = `2 * n`).

**Example:**

```toke
let token = crypto.random_bytes(32 as u64);
// token is a 64-character hex string
```

---

### crypto.hash_eq

Compares two hash strings in constant time to prevent timing attacks.

```toke
F=hash_eq(a: Str; b: Str): bool;
```

**Parameters:**

| Name | Type  | Description          |
|------|-------|----------------------|
| `a`  | `Str` | First hash string    |
| `b`  | `Str` | Second hash string   |

**Returns:** `bool` — `true` if the strings are equal.

**Example:**

```toke
let valid = crypto.hash_eq(expected_hash, computed_hash);
```
