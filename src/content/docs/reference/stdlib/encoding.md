---
title: "std.encoding"
description: "Base64, hex, and URL encoding/decoding."
---

**Status: Implemented** -- C runtime backing.

The `std.encoding` module provides functions for encoding and decoding binary data to and from common text representations: Base64, Base64-URL, hexadecimal, and percent-encoded URLs.

## Types

### $EncodingErr

| Field | Type | Meaning |
|-------|------|---------|
| msg | $str | Human-readable error description |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `encoding.b64encode` | `data: @($byte)` | `$str` | Encode bytes to standard Base64 |
| `encoding.b64urlencode` | `data: @($byte)` | `$str` | Encode bytes to URL-safe Base64 |
| `encoding.b64decode` | `s: $str` | `@($byte)!$EncodingErr` | Decode standard Base64 to bytes |
| `encoding.b64urldecode` | `s: $str` | `@($byte)!$EncodingErr` | Decode URL-safe Base64 to bytes |
| `encoding.hexencode` | `data: @($byte)` | `$str` | Encode bytes to lowercase hex string |
| `encoding.hexdecode` | `s: $str` | `@($byte)!$EncodingErr` | Decode hex string to bytes |
| `encoding.urlencode` | `s: $str` | `$str` | Percent-encode a string for use in URLs |
| `encoding.urldecode` | `s: $str` | `$str!$EncodingErr` | Decode a percent-encoded string |

## Usage

```toke
use std.encoding

f=main():i64{
  let raw = "Hello, toke!"
  let b64 = encoding.b64encode(raw.bytes)
  let hex = encoding.hexencode(raw.bytes)
  let url = encoding.urlencode("key=value&foo=bar baz")
  <0
}
```

## Dependencies

None.
