---
title: "std.yaml"
description: "YAML encoding and decoding -- parse YAML mappings and sequences, extract typed fields by key."
---

**Status: Implemented** -- C runtime backing.

The `std.yaml` module provides functions for parsing and emitting YAML, one of toke's secondary serialization formats. It handles flat key-value mappings, simple sequences, and scalar types. YAML is particularly suited for nested configuration data where its indentation-based structure provides natural readability.

YAML is a **secondary format** in toke's serialization hierarchy: TOON (default) > YAML (secondary) > JSON (secondary). See [Data Formats](/reference/data-formats) for the full strategy.

## Types

### $yaml

An opaque wrapper around a raw YAML string. Obtained by calling `yaml.dec` on valid YAML input.

| Field | Type | Meaning |
|-------|------|---------|
| raw | $str | The underlying YAML string |

## Functions

### yaml.enc(v: $str): $str

Encodes a value as a YAML string, adding quotes if the value contains special characters (`:`, `#`, `[`, `]`, etc.).

```toke
let y = yaml.enc("hello");       (* y = "hello" *)
let q = yaml.enc("key: value");  (* q = "\"key: value\"" *)
```

### yaml.dec(s: $str): $yaml!$yamlerr

Parses a YAML string into a `$yaml` value. Returns `$yamlerr.$parse` if the input is empty or invalid.

```toke
let y = yaml.dec("name: Alice\nage: 30\n");
(* y = ok($yaml{...}) *)
```

### yaml.str(y: $yaml; key: $str): $str!$yamlerr

Extracts a string value by key. Automatically strips surrounding quotes.

```toke
let name = yaml.str(y; "name");  (* name = ok("Alice") *)
```

### yaml.i64(y: $yaml; key: $str): i64!$yamlerr

Extracts a signed 64-bit integer by key.

```toke
let age = yaml.i64(y; "age");  (* age = ok(30) *)
```

### yaml.f64(y: $yaml; key: $str): f64!$yamlerr

Extracts a 64-bit float by key.

```toke
let pi = yaml.f64(y; "pi");  (* pi = ok(3.14) *)
```

### yaml.bool(y: $yaml; key: $str): bool!$yamlerr

Extracts a boolean by key. Accepts `true`/`false` and YAML-style `yes`/`no`.

```toke
let active = yaml.bool(y; "active");   (* active = ok(true) *)
let enabled = yaml.bool(y; "enabled"); (* accepts "yes" as true *)
```

### yaml.arr(y: $yaml; key: $str): @($yaml)!$yamlerr

Extracts a YAML sequence as an array of `$yaml` values.

```toke
let y = yaml.dec("items:\n  - apple\n  - banana\n");
let items = yaml.arr(y; "items");
(* items = ok(@($yaml; $yaml)) *)
```

### yaml.fromJson(json: $str): $str

Converts a JSON string to YAML format.

```toke
let j = "{\"name\":\"Alice\",\"age\":30}";
let y = yaml.fromJson(j);
(* y = "name: Alice\nage: 30" *)
```

### yaml.toJson(yaml: $str): $str

Converts YAML format back to JSON.

```toke
let y = "name: Alice\nage: 30\n";
let j = yaml.toJson(y);
(* j = "{\"name\":\"Alice\",\"age\":30}" *)
```

## Usage Examples

```toke
(* Parse a YAML configuration file *)
let raw=file.read("config.yaml")|{Ok:s s;Err:e ""};
let config=yaml.dec(raw)|{Ok:c c;Err:e yaml.dec("")!$yamlerr};
let host=yaml.str(config;"host")|{Ok:s s;Err:e "localhost"};
let port=yaml.i64(config;"port")|{Ok:n n;Err:e 8080};
let debug=yaml.bool(config;"debug")|{Ok:b b;Err:e false};

(* Convert between formats *)
let jsondata=yaml.toJson("key: value\ncount: 42\n");
```

## Error Types

### $yamlerr

A sum type representing YAML operation failures.

| Variant | Field Type | Meaning |
|---------|------------|---------|
| $parse | $str | The input string is not valid YAML |
| $type | $str | The value exists but is not the expected type |
| $missing | $str | The requested key does not exist in the mapping |
