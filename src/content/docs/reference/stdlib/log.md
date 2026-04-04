---
title: "std.log"
description: "Structured logging -- NDJSON log output to stderr with level filtering."
---

**Status: Implemented** -- C runtime backing.

The `std.log` module provides structured logging functions that emit NDJSON (newline-delimited JSON) to stderr. Each log line includes a timestamp, level, message, and optional key-value fields.

Log output is filtered by level. The threshold is controlled by the `TK_LOG_LEVEL` environment variable or programmatically. Levels in ascending order: `DEBUG`, `INFO`, `WARN`, `ERROR`. The default level when `TK_LOG_LEVEL` is unset is `INFO`.

All functions return `bool` -- `true` if the log line was emitted, `false` if it was filtered by the current level.

## Functions

### log.info(msg: $str; fields: @(@($str))): bool

Emits an INFO-level log line. The `fields` parameter is an array of key-value string pairs providing structured context.

```toke
log.info("request received"; @(@("request_id"; "abc123"); @("user"; "alice")));
(* stderr: {"level":"info" "msg":"request received" "request_id":"abc123" "user":"alice" "ts":...} *)
```

### log.warn(msg: $str; fields: @(@($str))): bool

Emits a WARN-level log line. Same signature and semantics as `log.info`.

```toke
log.warn("rate limit exceeded"; @(@("code"; "429")));
```

### log.error(msg: $str; fields: @(@($str))): bool

Emits an ERROR-level log line. Same signature and semantics as `log.info`.

```toke
log.error("file not found"; @(@("errno"; "ENOENT")));
```

## Level Filtering

| TK_LOG_LEVEL | log.info | log.warn | log.error |
|--------------|----------|----------|-----------|
| DEBUG | emitted | emitted | emitted |
| INFO (default) | emitted | emitted | emitted |
| WARN | filtered | emitted | emitted |
| ERROR | filtered | filtered | emitted |

When a log call is filtered, it returns `false` and no output is written to stderr.

## Output Format

Each log line is a single JSON object on one line (NDJSON), written to stderr. Fields include:

| Key | Type | Description |
|-----|------|-------------|
| level | $str | `"info"`, `"warn"`, or `"error"` |
| msg | $str | The log message (JSON-escaped) |
| ts | u64 | Unix timestamp in milliseconds |
| *(custom)* | $str | Any additional fields from the `fields` parameter |

## Usage Examples

```toke
(* Log with structured context *)
let start = time.now();
let result = db.one("SELECT * FROM users WHERE id=1"; @());
let elapsed = time.since(start);

result|{
  Ok:r  log.info("query succeeded";@(
    @("elapsed_ms";str.fromInt(elapsed));
    @("table";"users")
  ));
  Err:e  log.error("query failed";@(
    @("elapsed_ms";str.fromInt(elapsed));
    @("table";"users")
  ))
};
```
