---
title: "std.llm"
description: "LLM client for chat completions, streaming, and token counting."
---

**Status: Implemented** -- C runtime backing.

The `std.llm` module provides a provider-agnostic client for large language model APIs. Supports chat completions, streaming responses, single-prompt completions, and token counting.

## Types

### $llmclient

| Field | Type | Meaning |
|-------|------|---------|
| provider | $str | Provider name (e.g., `"openai"`, `"anthropic"`) |
| model | $str | Model identifier (e.g., `"gpt-4"`, `"claude-3"`) |

### $llmmsg

| Field | Type | Meaning |
|-------|------|---------|
| role | $str | Message role: `"system"`, `"user"`, or `"assistant"` |
| content | $str | Message content |

### $llmresp

| Field | Type | Meaning |
|-------|------|---------|
| content | $str | Response text |
| tokens_in | u64 | Input token count |
| tokens_out | u64 | Output token count |
| model | $str | Model used for the response |

### $llmerr

| Field | Type | Meaning |
|-------|------|---------|
| msg | $str | Error description |
| code | u64 | Provider error code |

### $llmstream

Opaque handle to a streaming response. Iterate with `llm.streamnext`.

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `llm.client` | `provider: $str; model: $str; apikey: $str` | `$llmclient` | Create an LLM client |
| `llm.chat` | `c: $llmclient; msgs: @($llmmsg)` | `$llmresp!$llmerr` | Send a chat completion request |
| `llm.chatstream` | `c: $llmclient; msgs: @($llmmsg)` | `$llmstream!$llmerr` | Start a streaming chat completion |
| `llm.streamnext` | `s: $llmstream` | `$str!$llmerr` | Read the next chunk from a stream (empty string = done) |
| `llm.complete` | `c: $llmclient; prompt: $str` | `$str!$llmerr` | Single-prompt completion |
| `llm.countokens` | `c: $llmclient; text: $str` | `u64` | Count tokens in text for the client's model |

## Usage

```toke
use std.llm

f=main():i64{
  let c = llm.client("openai"; "gpt-4"; env.get("OPENAI_KEY"))
  let msgs = @(
    llm.$llmmsg{role="system";content="You are helpful."}
    llm.$llmmsg{role="user";content="What is toke?"}
  )
  let resp = llm.chat(c; msgs)|{Ok:r r;Err:e <1}
  log.info(resp.content)
  <0
}
```

## Dependencies

- `std.http` -- underlying HTTP transport.
- `std.json` -- request/response serialization.
