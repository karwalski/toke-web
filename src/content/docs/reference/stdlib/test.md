---
title: "std.test"
description: "Test assertions -- assert conditions and string equality for writing tests."
---

**Status: Implemented** -- C runtime backing, available in Phase 2.

The `std.test` module provides assertion functions for writing tests. All functions return `bool` -- `true` (1) on pass, `false` (0) on fail. Failed assertions emit a structured diagnostic to stderr. These functions do not halt execution; the test continues after a failed assertion.

## Functions

### test.assert(cond: bool; msg: $str): bool

Passes if `cond` is `true`. On failure, emits a diagnostic containing `msg` to stderr and returns `false`.

```toke
test.assert(str.len("hi") == 2; "length should be 2");
test.assert(file.exists("/tmp/data.txt"); "file should exist");
```

### test.assertEq(a: $str; b: $str; msg: $str): bool

Passes if strings `a` and `b` are equal. On failure, emits a diagnostic showing both values and `msg` to stderr and returns `false`.

```toke
test.assertEq(str.upper("hello"); "HELLO"; "upper should produce HELLO");
test.assertEq(""; ""; "empty strings are equal");
```

### test.assertNe(a: $str; b: $str; msg: $str): bool

Passes if strings `a` and `b` are not equal. On failure, emits a diagnostic showing both values and `msg` to stderr and returns `false`.

```toke
test.assertNe("foo"; "bar"; "foo and bar should differ");
test.assertNe(""; "x"; "empty and non-empty differ");
```

## Usage Examples

```toke
(* Test string operations *)
test.assertEq(str.trim("  hi  "); "hi"; "trim removes whitespace");
test.assert(str.contains("foobar"; "oba"); "contains finds substring");

(* Test with computed values *)
let parts = str.split("a:b:c"; ":");
test.assertEq(str.fromInt(str.len(parts)); "3"; "split produces 3 parts");

(* Test error cases *)
let result = str.toInt("not a number");
test.assert(result.err?; "toInt rejects non-numeric input");
```

## Diagnostic Output

When an assertion fails, a structured diagnostic is written to stderr. This output is consumed by the toke test runner to produce formatted failure reports.
