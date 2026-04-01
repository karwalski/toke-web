---
title: "std.time"
description: "Time functions -- current time, elapsed measurement, and timestamp formatting."
---

**Status: Implemented** -- C runtime backing, available in Phase 2.

The `std.time` module provides functions for getting the current time, measuring elapsed time, and formatting timestamps. All timestamps are Unix timestamps in milliseconds (u64). All functions are infallible.

## Functions

### time.now(): u64

Returns the current Unix timestamp in milliseconds.

```toke
let t = time.now();  (* e.g. 1705322096000 *)
```

### time.since(ts: u64): u64

Returns the number of milliseconds elapsed since the given timestamp `ts`. If `ts` is in the future, returns 0 (clamped).

```toke
let start = time.now();
(* ... do some work ... *)
let elapsed = time.since(start);
(* elapsed = number of ms since start *)
```

### time.format(ts: u64; fmt: $str): $str

Formats a millisecond Unix timestamp using strftime-compatible format codes. If `fmt` is null, falls back to an ISO-8601 style format.

**Common format codes:**

| Code | Meaning | Example |
|------|---------|---------|
| %Y | Four-digit year | 2024 |
| %m | Month (01-12) | 01 |
| %d | Day of month (01-31) | 15 |
| %H | Hour (00-23) | 12 |
| %M | Minute (00-59) | 34 |
| %S | Second (00-59) | 56 |

```toke
let ts = 1705322096000;  (* 2024-01-15 12:34:56 UTC *)
let date = time.format(ts; "%Y-%m-%d");    (* date = "2024-01-15" *)
let tm = time.format(ts; "%H:%M:%S");   (* tm = "12:34:56" *)
let custom = time.format(ts; "year=%Y");    (* custom = "year=2024" *)
```

## Usage Examples

```toke
(* Measure how long an operation takes *)
let start = time.now();
let rows = db.many("SELECT * FROM big_table"; @());
let ms = time.since(start);
log.info("query complete"; @(@("elapsed_ms"; str.fromInt(ms))));

(* Log with a formatted timestamp *)
let now = time.now();
let stamp = time.format(now; "%Y-%m-%d %H:%M:%S");
log.info("event occurred"; @(@("timestamp"; stamp)));
```
