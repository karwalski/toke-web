---
title: std.test
description: Testing assertions — assert equality, truthiness, and failure conditions in tests.
---

The `std.test` module provides assertion functions for writing tests. When an assertion fails, it terminates the test with a diagnostic message.

## Import

```toke
I=test:std.test;
```

## Functions

### test.assert

Asserts that a condition is true.

```toke
F=assert(cond: bool; msg: Str): void;
```

**Parameters:**

| Name   | Type   | Description                             |
|--------|--------|-----------------------------------------|
| `cond` | `bool` | The condition to check                  |
| `msg`  | `Str`  | Message to display if assertion fails   |

**Returns:** `void` — returns normally if `cond` is `true`; aborts with `msg` if `false`.

**Example:**

```toke
test.assert(x > 0, "x must be positive");
```

---

### test.assert_eq_i64

Asserts that two `i64` values are equal.

```toke
F=assert_eq_i64(actual: i64; expected: i64; msg: Str): void;
```

**Parameters:**

| Name       | Type  | Description                           |
|------------|-------|---------------------------------------|
| `actual`   | `i64` | The actual value                      |
| `expected` | `i64` | The expected value                    |
| `msg`      | `Str` | Message to display on failure         |

**Returns:** `void`

**Example:**

```toke
test.assert_eq_i64(add(2, 3), 5, "2 + 3 should equal 5");
```

---

### test.assert_eq_str

Asserts that two `Str` values are equal.

```toke
F=assert_eq_str(actual: Str; expected: Str; msg: Str): void;
```

**Parameters:**

| Name       | Type  | Description                           |
|------------|-------|---------------------------------------|
| `actual`   | `Str` | The actual value                      |
| `expected` | `Str` | The expected value                    |
| `msg`      | `Str` | Message to display on failure         |

**Returns:** `void`

**Example:**

```toke
test.assert_eq_str(str.trim("  hi  "), "hi", "trim should remove spaces");
```

---

### test.assert_eq_f64

Asserts that two `f64` values are equal.

```toke
F=assert_eq_f64(actual: f64; expected: f64; msg: Str): void;
```

**Parameters:**

| Name       | Type  | Description                           |
|------------|-------|---------------------------------------|
| `actual`   | `f64` | The actual value                      |
| `expected` | `f64` | The expected value                    |
| `msg`      | `Str` | Message to display on failure         |

**Returns:** `void`

---

### test.assert_eq_bool

Asserts that two `bool` values are equal.

```toke
F=assert_eq_bool(actual: bool; expected: bool; msg: Str): void;
```

**Parameters:**

| Name       | Type   | Description                           |
|------------|--------|---------------------------------------|
| `actual`   | `bool` | The actual value                      |
| `expected` | `bool` | The expected value                    |
| `msg`      | `Str`  | Message to display on failure         |

**Returns:** `void`

---

### test.fail

Unconditionally fails the test with a message.

```toke
F=fail(msg: Str): void;
```

**Parameters:**

| Name  | Type  | Description                   |
|-------|-------|-------------------------------|
| `msg` | `Str` | The failure message           |

**Returns:** Does not return normally — always aborts the test.

**Example:**

```toke
match result {
    true => { };
    false => { test.fail("expected true") }
};
```
