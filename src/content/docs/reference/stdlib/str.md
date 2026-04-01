---
title: "std.str"
description: "String operations -- UTF-8 string manipulation, conversion, slicing, and transformation functions."
---

**Status: Implemented** -- C runtime backing, available in Phase 2.

The `std.str` module provides string manipulation functions for UTF-8 encoded strings. All strings in toke are immutable, null-terminated UTF-8 byte sequences. Functions that transform strings return new allocations.

## Functions

### str.len(s: $str): u64

Returns the byte length of the string `s`.

```toke
let n = str.len("hello");  (* n = 5 *)
let z = str.len("");        (* z = 0 *)
```

### str.concat(a: $str; b: $str): $str

Returns a new string formed by appending `b` to `a`.

```toke
let s = str.concat("foo"; "bar");  (* s = "foobar" *)
let t = str.concat(""; "x");       (* t = "x" *)
```

### str.slice(s: $str; start: u64; end: u64): $str!$sliceerr

Returns the substring of `s` from byte index `start` (inclusive) to `end` (exclusive). Returns `$sliceerr` if either index exceeds the string length or if `start > end`.

```toke
let r = str.slice("hello"; 1; 3);  (* r = ok("el") *)
let e = str.slice("hello"; 3; 10); (* e = err($sliceerr{...}) *)
```

### str.fromInt(n: i64): $str

Converts a signed 64-bit integer to its decimal string representation.

```toke
let s = str.fromInt(42);   (* s = "42" *)
let t = str.fromInt(-7);   (* t = "-7" *)
```

### str.fromFloat(n: f64): $str

Converts a 64-bit float to its string representation.

```toke
let s = str.fromFloat(3.14);  (* s = "3.14" *)
```

### str.toInt(s: $str): i64!$parseerr

Parses a decimal integer from the string `s`. Returns `$parseerr` if the string is not a valid integer or is empty.

```toke
let n = str.toInt("123");  (* n = ok(123) *)
let e = str.toInt("abc");  (* e = err($parseerr{...}) *)
```

### str.toFloat(s: $str): f64!$parseerr

Parses a floating-point number from the string `s`. Returns `$parseerr` if the string is not a valid number.

```toke
let f = str.toFloat("2.5");  (* f = ok(2.5) *)
let e = str.toFloat("xyz");  (* e = err($parseerr{...}) *)
```

### str.contains(s: $str; sub: $str): bool

Returns `true` if `s` contains the substring `sub`, `false` otherwise.

```toke
let y = str.contains("foobar"; "oba");  (* y = true *)
let n = str.contains("foobar"; "xyz");  (* n = false *)
```

### str.split(s: $str; sep: $str): @($str)

Splits the string `s` on each occurrence of the separator `sep` and returns an array of substrings.

```toke
let parts = str.split("a:b:c"; ":");
(* parts = @("a"; "b"; "c") *)
```

### str.trim(s: $str): $str

Returns a new string with leading and trailing whitespace removed.

```toke
let t = str.trim("  hi  ");  (* t = "hi" *)
```

### str.upper(s: $str): $str

Returns a new string with all ASCII characters converted to uppercase.

```toke
let u = str.upper("hello");  (* u = "HELLO" *)
```

### str.lower(s: $str): $str

Returns a new string with all ASCII characters converted to lowercase.

```toke
let l = str.lower("WORLD");  (* l = "world" *)
```

### str.bytes(s: $str): @($byte)

Returns the raw UTF-8 byte array of the string.

```toke
let b = str.bytes("abc");  (* b = @(97; 98; 99) *)
```

### str.fromBytes(b: @($byte)): $str!$encodingerr

Converts a byte array to a string. Returns `$encodingerr` if the bytes are not valid UTF-8.

```toke
let s = str.fromBytes(@(104; 105));  (* s = ok("hi") *)
```

## Usage Examples

```toke
(* Parse a number from user input with fallback *)
let input = str.trim(rawInput);
let val = str.toInt(input) |{ 0 };

(* Build a greeting *)
let name = str.upper(str.slice("alice"; 0; 1) |{ "" });
let rest = str.slice("alice"; 1; 5) |{ "" };
let greeting = str.concat("Hello "; str.concat(name; rest));

(* Split delimited string and process each field *)
let fields = str.split("name:age:city"; ":");
```

## Error Types

### $sliceerr

Returned by `str.slice` when indices are out of bounds.

| Field | Type | Meaning |
|-------|------|---------|
| msg | $str | Human-readable description of the error |

### $parseerr

Returned by `str.toInt` and `str.toFloat` when the input string cannot be parsed as the target numeric type.

| Field | Type | Meaning |
|-------|------|---------|
| msg | $str | Human-readable description of the parse failure |

### $encodingerr

Returned by `str.fromBytes` when the byte array is not valid UTF-8.

| Field | Type | Meaning |
|-------|------|---------|
| msg | $str | Human-readable description of the encoding error |
