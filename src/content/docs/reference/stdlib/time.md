---
title: std.time
description: Time operations — get the current time, measure durations, and sleep.
---

The `std.time` module provides functions for getting the current time, measuring durations, formatting timestamps, and pausing execution.

## Import

```toke
I=time:std.time;
```

## Functions

### time.now

Returns the current Unix timestamp in seconds.

```toke
F=now(): i64;
```

**Returns:** `i64` — seconds since the Unix epoch (1970-01-01 00:00:00 UTC).

**Example:**

```toke
let ts = time.now();
```

---

### time.now_ms

Returns the current Unix timestamp in milliseconds.

```toke
F=now_ms(): i64;
```

**Returns:** `i64` — milliseconds since the Unix epoch.

**Example:**

```toke
let start = time.now_ms();
// ... do work ...
let elapsed = time.now_ms() - start;
```

---

### time.sleep

Pauses execution for the specified number of milliseconds.

```toke
F=sleep(ms: i64): void;
```

**Parameters:**

| Name | Type  | Description                        |
|------|-------|------------------------------------|
| `ms` | `i64` | Duration to sleep in milliseconds  |

**Returns:** `void`

**Example:**

```toke
time.sleep(1000);  // sleep for 1 second
```

---

### time.format

Formats a Unix timestamp as an ISO 8601 string.

```toke
F=format(timestamp: i64): Str;
```

**Parameters:**

| Name        | Type  | Description                |
|-------------|-------|----------------------------|
| `timestamp` | `i64` | Unix timestamp in seconds  |

**Returns:** `Str` — ISO 8601 formatted string (e.g., `"2025-01-15T09:30:00Z"`).

**Example:**

```toke
let formatted = time.format(time.now());
```

---

### time.parse

Parses an ISO 8601 string into a Unix timestamp.

```toke
F=parse(s: Str): i64!Err;
```

**Parameters:**

| Name | Type  | Description                      |
|------|-------|----------------------------------|
| `s`  | `Str` | ISO 8601 formatted time string   |

**Returns:** `i64!Err` — Unix timestamp in seconds, or an error if the string is not valid.

**Errors:** Returns an error if the input string is not a valid ISO 8601 timestamp.

**Example:**

```toke
let ts = time.parse("2025-01-15T09:30:00Z")!;
```
