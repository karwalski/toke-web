---
title: "std.template"
description: "Compile and render {{slot}} templates, plus HTML element constructors."
---

**Status: Implemented** -- C runtime backing.

The `std.template` module compiles template strings with `{{varname}}` slots, renders them with variable bindings, and provides helper functions for constructing HTML elements and escaping content.

## Types

### $tmpl

| Field | Type | Meaning |
|-------|------|---------|
| id | u64 | Opaque compiled template handle |
| src | $str | Original template source |

### $tmplvars

| Field | Type | Meaning |
|-------|------|---------|
| entries | @($str:$str) | Variable bindings map: key to value |

### $tmplerr

| Field | Type | Meaning |
|-------|------|---------|
| msg | $str | Human-readable error message |
| pos | u64 | Byte offset in source where the error occurred |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `tpl.compile` | `src: $str` | `$tmpl!$tmplerr` | Compile a template string with `{{slot}}` placeholders |
| `tpl.render` | `t: $tmpl; vars: $tmplvars` | `$str!$tmplerr` | Render a compiled template with variable bindings |
| `tpl.vars` | `pairs: @($str:$str)` | `$tmplvars` | Construct a variable bindings map from key-value pairs |
| `tpl.html` | `tag: $str; attrs: @($str:$str); children: @($str)` | `$str` | Build an HTML element string from tag, attributes, and children |
| `tpl.escape` | `s: $str` | `$str` | HTML-escape a string (`&`, `<`, `>`, `"`, `'`) |
| `tpl.renderfile` | `path: $str; vars: $tmplvars` | `$str!$tmplerr` | Load, compile, and render a template file |

## Usage

```toke
use std.template

f=main():i64{
  let t = tpl.compile("Hello, {{name}}!")|{Ok:t t;Err:e <1}
  let vars = tpl.vars(@("name":"world"))
  let out = tpl.render(t; vars)|{Ok:s s;Err:e ""}
  (* out = "Hello, world!" *)
  <0
}
```

## Dependencies

None.
