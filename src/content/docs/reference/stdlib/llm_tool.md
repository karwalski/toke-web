---
title: "std.llm.tool"
description: "Tool-use extensions for LLM clients: declare tools, handle tool calls, and submit results."
---

**Status: Implemented** -- C runtime backing.

The `std.llm.tool` module extends `std.llm` with tool-use (function calling) support. Declare tool schemas, send tool-augmented chat requests, parse tool calls from responses, and submit results back to the model.

## Types

### $tooldecl

| Field | Type | Meaning |
|-------|------|---------|
| name | $str | Tool name |
| desc | $str | Human-readable description |
| params | @($toolparam) | Parameter definitions |

### $toolparam

| Field | Type | Meaning |
|-------|------|---------|
| name | $str | Parameter name |
| type | $str | Parameter type (e.g., `"string"`, `"number"`) |
| desc | $str | Parameter description |
| required | $bool | Whether the parameter is required |

### $toolcall

| Field | Type | Meaning |
|-------|------|---------|
| name | $str | Name of the tool the model wants to call |
| args | @(@($str)) | Argument key-value pairs |
| id | $str | Call identifier for correlating results |

### $toolresult

| Field | Type | Meaning |
|-------|------|---------|
| id | $str | Matching call identifier |
| content | $str | Result content |
| error | $bool | Whether the result represents an error |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `llm.withtools` | `c: llm.$llmclient; tools: @($tooldecl)` | `llm.$llmclient` | Attach tool declarations to a client |
| `llm.chatwithtools` | `c: llm.$llmclient; msgs: @(llm.$llmmsg)` | `$toolcall!llm.$llmerr` | Chat with tool-use; returns the tool call the model wants |
| `llm.submitresult` | `c: llm.$llmclient; msgs: @(llm.$llmmsg); result: $toolresult` | `llm.$llmresp!llm.$llmerr` | Submit a tool result and get the model's final response |
| `llm.parsetoolcalls` | `raw: $str` | `$toolcall!llm.$llmerr` | Parse tool calls from a raw response string |
| `llm.resultmsgs` | `results: @($toolresult)` | `@(llm.$llmmsg)` | Convert tool results into messages for the conversation |

## Usage

```toke
use std.llm
use std.llm.tool

f=main():i64{
  let c = llm.client("openai"; "gpt-4"; env.get("OPENAI_KEY"))
  let tools = @(
    llm.tool.$tooldecl{
      name="get_weather"
      desc="Get current weather for a city"
      params=@(llm.tool.$toolparam{name="city";type="string";desc="City name";required=true})
    }
  )
  let c2 = llm.withtools(c; tools)
  let msgs = @(llm.$llmmsg{role="user";content="What is the weather in Sydney?"})
  let call = llm.chatwithtools(c2; msgs)|{Ok:tc tc;Err:e <1}
  let result = llm.tool.$toolresult{id=call.id;content="{\"temp\":22}";error=false}
  let resp = llm.submitresult(c2; msgs; result)|{Ok:r r;Err:e <1}
  <0
}
```

## Dependencies

- `std.llm` -- base LLM client and message types.
