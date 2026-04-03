---
title: "std.toon"
description: "TOON (Token-Oriented Object Notation) encoding and decoding -- the default serialization format for toke, optimised for LLM token efficiency."
---

**Status: Implemented** -- C runtime backing.

The `std.toon` module provides functions for parsing and emitting TOON (Token-Oriented Object Notation), toke's default serialization format. TOON achieves 30--60% fewer tokens than JSON for uniform tabular data by declaring field names once in a schema header and using pipe-delimited value rows.

TOON is the **primary format** in toke's serialization hierarchy: TOON (default) > YAML (secondary) > JSON (secondary). See [Data Formats](/reference/data-formats) for the full strategy.

### TOON format

```
users[3]{id,name,active}:
1|Alice|true
2|Bob|false
3|Carol|true
```

## Types

### $toon

An opaque wrapper around a raw TOON string. Obtained by calling `toon.dec` on valid TOON input. Field access is performed via typed accessor functions (`toon.str`, `toon.i64`, etc.).

| Field | Type | Meaning |
|-------|------|---------|
| raw | $str | The underlying TOON string |

## Functions

### toon.enc(v: $str): $str

Encodes a value to its TOON string representation.

```toke
let t = toon.enc("hello");  (* t = "hello" *)
```

### toon.dec(s: $str): $toon!$toonerr

Parses a TOON string into a `$toon` value. Returns `$toonerr.$parse` if the input is not valid TOON.

```toke
let t = toon.dec("data[2]{id,name}:\n1|Alice\n2|Bob\n");
(* t = ok($toon{...}) *)
```

### toon.str(t: $toon; key: $str): $str!$toonerr

Extracts a string value from the first TOON row by field name. Returns `$toonerr.$missing` if the field does not exist.

```toke
let name = toon.str(t; "name");  (* name = ok("Alice") *)
```

### toon.i64(t: $toon; key: $str): i64!$toonerr

Extracts a signed 64-bit integer by field name. Returns `$toonerr.$type` if the value is not a number.

```toke
let id = toon.i64(t; "id");  (* id = ok(1) *)
```

### toon.f64(t: $toon; key: $str): f64!$toonerr

Extracts a 64-bit float by field name.

```toke
let x = toon.f64(t; "x");  (* x = ok(3.14) *)
```

### toon.bool(t: $toon; key: $str): bool!$toonerr

Extracts a boolean by field name.

```toke
let active = toon.bool(t; "active");  (* active = ok(true) *)
```

### toon.arr(t: $toon; key: $str): @($toon)!$toonerr

Extracts all rows for a given field as a `$toon` array.

```toke
let names = toon.arr(t; "name");
(* names = ok(@($toon; $toon; $toon)) *)
```

### toon.from_json(json: $str): $str

Converts a JSON array of objects to TOON format.

```toke
let j = "[{\"id\":1,\"name\":\"Alice\"},{\"id\":2,\"name\":\"Bob\"}]";
let t = toon.from_json(j);
(* t = "data[2]{id,name}:\n1|Alice\n2|Bob\n" *)
```

### toon.to_json(toon: $str): $str

Converts TOON format back to JSON.

```toke
let t = "data[2]{id,name}:\n1|Alice\n2|Bob\n";
let j = toon.to_json(t);
(* j = "[{\"id\":1,\"name\":\"Alice\"},{\"id\":2,\"name\":\"Bob\"}]" *)
```

## Usage Examples

```toke
(* Convert API response from JSON to TOON for token-efficient storage *)
let payload = http.get("https://api.example.com/users").body;
let compact = toon.from_json(payload);

(* Parse TOON data and extract fields *)
let data = toon.dec(compact) |{ toon.dec("{err}:\nparse error") };
let name = toon.str(data; "name") |{ "unknown" };
let age = toon.i64(data; "age") |{ 0 };
```

## Error Types

### $toonerr

A sum type representing TOON operation failures.

| Variant | Field Type | Meaning |
|---------|------------|---------|
| $parse | $str | The input string is not valid TOON |
| $type | $str | The value exists but is not the expected type |
| $missing | $str | The requested field does not exist in the schema |
