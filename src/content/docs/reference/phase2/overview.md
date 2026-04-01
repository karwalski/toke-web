---
title: "Phase 2 Profile Overview"
description: "How Phase 2 differs from Phase 1 — reduced character set, new sigils, and the purpose-built tokenizer."
---

Phase 2 is a reduced-character profile of the toke language designed for use with the purpose-built BPE tokenizer. It expresses the same semantics as Phase 1 but uses only **56 characters**, enabling significantly higher token density during LLM inference.

Phase 2 is the production encoding. Phase 1 (80 characters) was used during corpus generation to leverage existing LLM tokenizers, and programs are mechanically transformed to Phase 2 for training and inference.

:::note
Phase 2 source is **not** valid Phase 1 source, and vice versa. The compiler accepts `--profile1` (default) or `--profile2` to select the active profile.
:::

## Why Two Profiles?

Phase 1 uses existing LLM tokenizers (like cl100k_base) which were not designed for toke. It needs uppercase letters for type names and brackets for arrays because these are what existing tokenizers handle well.

Phase 2 drops uppercase letters entirely and replaces bracket-heavy syntax with sigils (`$` for types, `@` for arrays). A purpose-built tokenizer trained on toke source can merge these patterns into single vocabulary entries — `$user`, `$str`, `@(` — achieving 2.5-4x better token density than Phase 1 with cl100k_base.

## Character Set Comparison

| Class | Phase 1 (80 chars) | Phase 2 (56 chars) | Change |
|-------|--------------------|--------------------|--------|
| Lowercase | a-z (26) | a-z (26) | Same |
| Uppercase | A-Z (26) | — | Removed |
| Digits | 0-9 (10) | 0-9 (10) | Same |
| Symbols | 18 | 18 | `[` `]` removed; `$` `@` added |
| Reserved | — | `^` `~` (2) | Reserved for v0.2 |
| **Total** | **80** | **56** | **-24** |

## Transformation Rules

Every Phase 1 program can be mechanically transformed to Phase 2. The transformation is deterministic and reversible.

### 1. Type sigil: uppercase becomes `$lowercase`

Phase 1 uses uppercase-initial identifiers for types. Phase 2 prefixes them with `$` and lowercases.

<div class="hero-comparison">
<div>

**Phase 1**
```
T=User{id:u64;name:Str};
T=ApiErr{NotFound:u64;Timeout:Str};
```

</div>
<div>

**Phase 2**
```
t=$user{id:u64;name:$str};
t=$apierr{$notfound:u64;$timeout:$str};
```

</div>
</div>

This applies to all type positions: declarations, annotations, struct literals, match arms, and error types.

### 2. Array literals: `[...]` becomes `@(...)`

<div class="hero-comparison">
<div>

**Phase 1**
```
let nums=[1;2;3];
let names=["alice";"bob"];
```

</div>
<div>

**Phase 2**
```
let nums=@(1;2;3);
let names=@("alice";"bob");
```

</div>
</div>

### 3. Array indexing: `a[n]` becomes `a.get(n)`

<div class="hero-comparison">
<div>

**Phase 1**
```
let first=arr[0];
let item=arr[i];
```

</div>
<div>

**Phase 2**
```
let first=arr.0;
let item=arr.get(i);
```

</div>
</div>

Constant indices use dot notation (`arr.0`, `arr.1`). Variable indices use `.get(n)`.

### 4. Map types: `[K:V]` becomes `$(K:V)`

<div class="hero-comparison">
<div>

**Phase 1**
```
let ages=[Str:i64]["alice":30;"bob":25];
```

</div>
<div>

**Phase 2**
```
let ages=$($str:i64)("alice":30;"bob":25);
```

</div>
</div>

### 5. Identifiers

Phase 1 identifiers may begin with uppercase or lowercase. Phase 2 identifiers are lowercase only. All user-defined identifiers that began with uppercase in Phase 1 are lowercased and prefixed with `$` in Phase 2.

## Complete Example

<div class="hero-comparison">
<div>

**Phase 1**
```
M=fib;

F=fib(n:i64):i64{
  if(n<2){<n};
  <fib(n-1)+fib(n-2);
};

F=main():i64{
  <fib(10);
};
```

</div>
<div>

**Phase 2**
```
m=fib;

f=fib(n:i64):i64{
  if(n<2){<n};
  <fib(n-1)+fib(n-2);
};

f=main():i64{
  <fib(10);
};
```

</div>
</div>

This example shows that even simple programs differ between profiles: Phase 2 lowercases the `M=`, `F=` keywords to `m=`, `f=`. The bigger differences emerge in programs that use the type system and collections.

<div class="hero-comparison">
<div>

**Phase 1**
```
M=api;
I=http:std.http;
I=json:std.json;

T=ApiErr{
  NotFound:u64;
  BadRequest:Str
};

F=handle(req:http.Req):http.Res!ApiErr{
  let id=json.dec(req.body)!ApiErr;
  let users=["alice":1;"bob":2];
  <http.Res.ok(json.enc(users));
};
```

</div>
<div>

**Phase 2**
```
m=api;
i=http:std.http;
i=json:std.json;

t=$apierr{
  $notfound:u64;
  $badrequest:$str
};

f=handle(req:http.$req):http.$res!$apierr{
  let id=json.dec(req.body)!$apierr.$badrequest;
  let users=$($str:i64)("alice":1;"bob":2);
  <http.$res.ok(json.enc(users));
};
```

</div>
</div>

## Token Efficiency

The purpose-built Phase 2 tokenizer merges common patterns into single vocabulary entries:

| Pattern | Phase 1 tokens (cl100k) | Phase 2 tokens (toke BPE) |
|---------|------------------------|--------------------------|
| `$user` | 2-3 | 1 |
| `$str` | 2 | 1 |
| `@(` | 2 | 1 |
| `f=` | 2 | 1 |
| `!$err` | 3 | 1 |
| `<$res.ok` | 4-5 | 1-2 |

The target vocabulary size is 32,768 tokens. The tokenizer specification is finalised after Phase 1 corpus generation is complete.

## What Stays the Same

Everything not listed above is identical between profiles:

- Keywords: `f`, `t`, `i`, `m`, `if`, `el`, `lp`, `br`, `let`, `mut`, `as`, `rt`
- Operators: `+`, `-`, `*`, `/`, `<`, `>`, `=`, `!`, `|`
- Delimiters: `(`, `)`, `{`, `}`, `;`, `:`, `.`
- Control flow: `if(){}`, `el{}`, `lp(){}`, `br`
- Functions, modules, imports, error handling, match expressions
- The entire standard library API
- All semantic rules, type checking, and error codes

## See Also

- [Type System](/reference/types/) — production type reference (Phase 2 notation)
- [Phase 2 Type Details](/reference/phase2/types/) — Phase 2 type transformation details
- [Grammar](/reference/grammar/) — production grammar reference (Phase 2 notation)
- [Phase 2 Grammar Details](/reference/phase2/grammar/) — Phase 2 grammar transformation details
- [Design Principles](/about/design/) — why toke has two profiles
