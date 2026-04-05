---
title: "std.sse"
description: "Server-Sent Events for streaming data from server to client."
---

**Status: Implemented** -- C runtime backing.

The `std.sse` module provides Server-Sent Events (SSE) support. Emit structured events or raw data to a connected client over a long-lived HTTP connection.

## Types

### $ssectx

| Field | Type | Meaning |
|-------|------|---------|
| id | u64 | SSE connection identifier |
| open | $bool | Whether the connection is still open |

### $sseevent

| Field | Type | Meaning |
|-------|------|---------|
| id | $str | Event ID for client-side tracking |
| event | $str | Event type name |
| data | $str | Event payload |
| retry | u64 | Reconnection interval in milliseconds |

### $sseerr

| Field | Type | Meaning |
|-------|------|---------|
| msg | $str | Error description |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `sse.emit` | `ctx: $ssectx; event: $sseevent` | `void!$sseerr` | Emit a structured SSE event |
| `sse.emitdata` | `ctx: $ssectx; data: $str` | `void!$sseerr` | Emit a data-only event (no type or id) |
| `sse.close` | `ctx: $ssectx` | `void` | Close the SSE connection |
| `sse.keepalive` | `ctx: $ssectx; interval_ms: u64` | `void` | Send periodic keep-alive comments at the given interval |

## Usage

```toke
use std.sse

f=stream_handler(ctx:sse.$ssectx):void{
  let ev = sse.$sseevent{id="1";event="update";data="{\"count\":42}";retry=3000}
  sse.emit(ctx; ev)
  sse.keepalive(ctx; 15000)
}
```

## Dependencies

None.
