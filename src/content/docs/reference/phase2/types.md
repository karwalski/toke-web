---
title: "Type Encoding"
description: "How toke's type system uses sigil-prefixed names and a reduced character set — the encoding transformation from the corpus-generation profile."
---

This page documents the Phase 2 type system. Phase 2 uses the same semantic rules as [Phase 1](/reference/types/) but with a different surface syntax: all type names are lowercased and prefixed with `$`.

## Primitive Types

| Phase 1 | Phase 2 | Size | Range / Values |
|---------|---------|------|----------------|
| `i64` | `i64` | 64 bits | -2^63 to 2^63-1 |
| `u64` | `u64` | 64 bits | 0 to 2^64-1 |
| `f64` | `f64` | 64 bits | IEEE 754 double |
| `bool` | `bool` | 1 byte | `true`, `false` |
| `Str` | `$str` | pointer | Immutable UTF-8 string |
| `void` | `void` | 0 bytes | Unit type |

Lowercase primitives (`i64`, `u64`, `f64`, `bool`, `void`) are unchanged. Only `Str` becomes `$str` because it begins with uppercase in Phase 1.

## Composite Types

### Arrays

| Aspect | Phase 1 | Phase 2 |
|--------|---------|---------|
| Type notation | `[T]` | `@T` or `@($type)` |
| Literal | `[1;2;3]` | `@(1;2;3)` |
| Empty literal | `[]` | `@()` |
| Constant index | `arr[0]` | `arr.0` |
| Variable index | `arr[i]` | `arr.get(i)` |
| Length | `arr.len` | `arr.len` |

```
let nums=@(1;2;3);
let first=nums.0;
let n=nums.get(i);
let size=nums.len;
```

### Maps

| Aspect | Phase 1 | Phase 2 |
|--------|---------|---------|
| Type notation | `[K:V]` | `$(K:V)` |
| Literal | `["a":1;"b":2]` | `$("a":1;"b":2)` |
| Operations | `.get()`, `.put()`, `.contains()`, `.delete()`, `.len` | Same |

```
let ages=$($str:i64)("alice":30;"bob":25);
let age=ages.get("alice");
```

### Error Unions

Identical syntax to Phase 1, except type names use `$` prefix:

```
f=readfile(path:$str):$str!$fileerr{
  let content=file.read(path)!$fileerr;
  <content;
};
```

## Struct and Sum Types

Type declarations use `$` prefix for the type name and for any uppercase-initial field names (sum type variants):

<div class="hero-comparison">
<div>

**Phase 1**
```
T=Point{x:f64;y:f64};
T=Shape{
  Circle:f64;
  Rect:Point
};
```

</div>
<div>

**Phase 2**
```
t=$point{x:f64;y:f64};
t=$shape{
  $circle:f64;
  $rect:$point
};
```

</div>
</div>

Struct field access is unchanged (`p.x`, `p.y`). Match arms use the `$`-prefixed variant names:

```
s|{
  $circle:r  3.14*r*r;
  $rect:p    p.x*p.y
};
```

## Special Types

### Task

```
f=work():i64{<42};
let t=spawn(work);
let result=await(t);
```

`Task` is an internal type and does not appear in source — no `$` transformation needed.

### Pointers (FFI)

```
f=malloc(size:u64):*u8;
f=free(ptr:*u8):void;
```

Pointer types use the same `*T` syntax. Only the inner type is transformed if it is uppercase.

## Type Inference

All inference rules from [Phase 1](/reference/types/#type-inference) apply identically. The inferred types simply use Phase 2 notation:

| Expression | Inferred Type |
|------------|---------------|
| `42` | `i64` |
| `3.14` | `f64` |
| `"hello"` | `$str` |
| `true` | `bool` |
| `@(1;2;3)` | `@i64` |
| `$("a":1)` | `$($str:i64)` |
| `$point{x:0.0;y:0.0}` | `$point` |

## Cast Expressions

```
let x=42;
let y=x as f64;
let s="hello" as $str;
```

The `as` keyword and all cast rules are identical to Phase 1.

## See Also

- [Type System](/reference/types/) — production type reference
- [Phase 2 Overview](/reference/phase2/overview/) — complete profile comparison
- [Phase 2 Grammar](/reference/phase2/grammar/) — production rule differences
