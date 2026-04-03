---
title: "std.json"
description: "JSON encoding and decoding -- parse JSON strings and extract typed fields by key."
---

**Status: Implemented** -- C runtime backing.

The `std.json` module provides functions for parsing JSON strings into an opaque `Json` value and extracting typed fields by key. It also provides a simple encoding function for producing JSON string literals.

## Types

### $json

An opaque wrapper around a raw JSON string. Obtained by calling `json.dec` on a valid JSON input. Field access is performed via the typed accessor functions (`json.str`, `json.u64`, etc.).

| Field | Type | Meaning |
|-------|------|---------|
| raw | $str | The underlying JSON string |

## Functions

### json.enc(v: $str): $str

Encodes a string value as a JSON string literal (with surrounding double quotes and escaping).

```toke
let j = json.enc("hello");  (* j = "\"hello\"" *)
```

### json.dec(s: $str): $json!$jsonerr

Parses a JSON string into a `$json` value. Returns `$jsonerr.$parse` if the input is not valid JSON.

```toke
let j = json.dec("{\"name\":\"alice\";\"age\":30}");
(* j = ok($json{...}) *)

let e = json.dec("not json");
(* e = err($jsonerr.$parse{...}) *)
```

### json.str(j: $json; key: $str): $str!$jsonerr

Extracts a string value from the JSON object by key. Returns `$jsonerr.$missing` if the key does not exist, or `$jsonerr.$type` if the value is not a string.

```toke
let name = json.str(j; "name");  (* name = ok("alice") *)
```

### json.u64(j: $json; key: $str): u64!$jsonerr

Extracts an unsigned 64-bit integer from the JSON object by key. Returns `$jsonerr.$missing` if the key does not exist, or `$jsonerr.$type` if the value is not a number.

```toke
let age = json.u64(j; "age");  (* age = ok(30) *)
```

### json.i64(j: $json; key: $str): i64!$jsonerr

Extracts a signed 64-bit integer from the JSON object by key. Returns `$jsonerr.$missing` if the key does not exist, or `$jsonerr.$type` if the value is not a number.

```toke
let temp = json.i64(j; "temp");  (* temp = ok(-42) *)
```

### json.f64(j: $json; key: $str): f64!$jsonerr

Extracts a 64-bit float from the JSON object by key. Returns `$jsonerr.$missing` if the key does not exist, or `$jsonerr.$type` if the value is not a number.

```toke
let pi = json.f64(j; "pi");  (* pi = ok(3.14) *)
```

### json.bool(j: $json; key: $str): bool!$jsonerr

Extracts a boolean value from the JSON object by key. Returns `$jsonerr.$missing` if the key does not exist, or `$jsonerr.$type` if the value is not a boolean.

```toke
let flag = json.bool(j; "flag");  (* flag = ok(true) *)
```

### json.arr(j: $json; key: $str): @($json)!$jsonerr

Extracts a JSON array from the object by key, returning each element as a `$json` value. Returns `$jsonerr.$missing` if the key does not exist, or `$jsonerr.$type` if the value is not an array.

```toke
let items = json.arr(j; "items");  (* items = ok(@($json; $json; $json)) *)
```

## Usage Examples

```toke
(* Parse a JSON payload and extract fields *)
let body = json.dec(req.body) |{ http.Res.bad("invalid json") };
let name = json.str(body; "name") |{ "unknown" };
let age = json.u64(body; "age") |{ 0 };

(* Handle missing vs wrong type separately *)
let val = json.str(body; "email");
if val.ok? =
  log.info("email found"; @(@("email"; val!)))
el =
  log.warn("email missing"; @());
```

## Error Types

### $jsonerr

A sum type representing JSON operation failures.

| Variant | Field Type | Meaning |
|---------|------------|---------|
| $parse | $str | The input string is not valid JSON |
| $type | $str | The value exists but is not the expected type |
| $missing | $str | The requested key does not exist in the object |
