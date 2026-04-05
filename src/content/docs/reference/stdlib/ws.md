---
title: "std.ws"
description: "WebSocket client for bidirectional real-time communication."
---

**Status: Implemented** -- C runtime backing.

The `std.ws` module provides a WebSocket client. Connect to a server, send and receive text or binary messages, and broadcast to multiple connections.

## Types

### $wsconn

| Field | Type | Meaning |
|-------|------|---------|
| id | u64 | Connection identifier |
| ready | $bool | Whether the connection is open and ready |

### $wsmsg

| Field | Type | Meaning |
|-------|------|---------|
| payload | @($byte) | Message payload bytes |
| fin | $bool | Whether this is the final fragment |
| opcode | u64 | WebSocket frame opcode (1=text, 2=binary) |

### $wserr

| Field | Type | Meaning |
|-------|------|---------|
| msg | $str | Error description |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `ws.connect` | `url: $str` | `$wsconn!$wserr` | Open a WebSocket connection to the given URL |
| `ws.send` | `conn: $wsconn; msg: $str` | `void!$wserr` | Send a text message |
| `ws.sendbytes` | `conn: $wsconn; data: @($byte)` | `void!$wserr` | Send a binary message |
| `ws.recv` | `conn: $wsconn` | `$wsmsg!$wserr` | Block until a message is received |
| `ws.close` | `conn: $wsconn` | `void` | Close the connection |
| `ws.broadcast` | `conns: @($wsconn); msg: $str` | `void` | Send a text message to all connections |

## Usage

```toke
use std.ws

f=main():i64{
  let conn = ws.connect("ws://localhost:8080/chat")|{Ok:c c;Err:e <1}
  ws.send(conn; "hello")
  let msg = ws.recv(conn)|{Ok:m m;Err:e <1}
  ws.close(conn)
  <0
}
```

## Dependencies

None.
