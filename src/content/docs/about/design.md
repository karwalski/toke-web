---
title: Design Principles
description: The character set, grammar, keywords, and tradeoffs behind toke's language design.
---

toke's design follows a single rule: where any implementation decision conflicts with a design principle, the principle takes precedence over convenience. These are the principles.

## Machine-First Syntax

The language defines exactly one canonical syntactic form for each construct. Synonym constructs, optional delimiters, and style-variant spellings are prohibited. There is one way to declare a function, one way to return a value, one way to define a type. The model never chooses between equivalent forms.

## The 80-Character Profile

toke Phase 1 uses exactly 80 structural ASCII characters. No character outside this set may appear in a structural position. Arbitrary UTF-8 is permitted inside string literal content.

| Class | Characters | Count |
|---|---|---|
| Lowercase | `a-z` | 26 |
| Uppercase | `A-Z` | 26 |
| Digits | `0-9` | 10 |
| Symbols | `( ) { } [ ] = : . ; + - * / < > ! \| "` | 18-19 |

**What is excluded:** whitespace is structurally meaningless (the semicolon is the universal separator). There is no comment syntax -- documentation lives outside source files. The characters `@`, `#`, `$`, `%`, `^`, `&`, `~`, backtick, backslash, single-quote, comma, and question-mark do not appear in structural positions.

**Why restricted:** every character in the set must be necessary. Every token in generated output must carry semantic information. A smaller, predictable character set means fewer token boundary splits in BPE tokenizers and a tighter generation space for the model.

Phase 2 reduces the set further to 56 characters by replacing uppercase letters with sigil prefixes (`$user` instead of `User`) that BPE training absorbs into single merged tokens.

## LL(1) Grammar

The toke grammar is LL(1): the parser requires exactly one token of lookahead. No backtracking. No context-sensitive disambiguation. A valid toke source file parses to exactly one unambiguous syntax tree.

This matters for two reasons:

1. **Single-pass parsing.** The compiler processes source in one forward pass. No multi-pass resolution, no deferred disambiguation. Compilation is fast and predictable.
2. **Reduced generation space.** At every syntactic position, there is exactly one valid interpretation. The set of syntactically invalid programs the model can generate is as small as the grammar allows.

## 12 Keywords

toke reserves exactly 12 identifiers as keywords. For comparison, Python has 35 and JavaScript has 64.

| Keyword | Role | Why it exists |
|---|---|---|
| `M` | Module declaration | Every source file begins with `M=module.path;`. Identifies the compilation unit. |
| `F` | Function definition | `F=name(args):ReturnType{body};` -- the only way to define a function. |
| `T` | Type definition | `T=Name{fields};` -- the only way to define a struct type. |
| `I` | Import declaration | `I=alias:module.path;` -- explicit aliased imports, no wildcards. |
| `if` | Conditional branch | `if condition{body}` -- standard conditional. |
| `el` | Else branch | Follows the closing `}` of an `if` block. Two characters instead of four. |
| `lp` | Loop | The single loop construct. No `for`, `while`, `do`, or `foreach` variants. |
| `br` | Break | Exits the innermost `lp` block. |
| `let` | Immutable binding | `let x:i64 = 42;` -- binds a value that cannot be reassigned. |
| `mut` | Mutable qualifier | `let mut x:i64 = 0;` -- marks a binding as reassignable. |
| `as` | Explicit type cast | No implicit conversions. Every cast is visible in the source. |
| `rt` | Return (long form) | Equivalent to the `<` operator. Two characters instead of six. |

Single uppercase characters for declarations (`M`, `F`, `T`, `I`). Two-character lowercase for control flow (`if`, `el`, `lp`, `br`). Three-character lowercase for bindings (`let`, `mut`). Every keyword is as short as it can be while remaining unambiguous.

## Explicit Everything

toke prohibits implicit behaviour at every level:

- **No implicit returns.** Every function body must contain an explicit return (`<` or `rt`).
- **No optional semicolons.** The semicolon is the universal statement terminator. It is always required.
- **No significant whitespace.** Two programs that differ only in whitespace between tokens are lexically identical.
- **No implicit conversions.** Type casts use `as` and are always visible in the source.
- **No undefined behaviour.** Every operation in a well-typed program has a defined result or a defined trap.
- **No hidden state.** No context-sensitive semantic changes. No global mutable state without explicit declaration.

## Strong Explicit Typing

All values, interfaces, and function signatures have explicitly stated types. There is no type inference in Phase 1. The model always knows what type it is working with, and the compiler always has enough information to validate without cross-file analysis beyond declared imports.

## Structured Error Handling

Errors in toke are values, not exceptions. There is no `try`/`catch`, no `throw`, no stack unwinding.

Functions that can fail return a result-or-error type. The `!` operator propagates errors to the caller. The compiler enforces that every error path is handled explicitly. This means:

- The model never forgets a `try` block.
- Error handling is visible in the type signature.
- The compiler can verify error handling completeness statically.

## Arena Memory Discipline

Memory allocation follows a lexical arena discipline. All heap allocations within a function body or explicit arena block are freed deterministically when the scope exits. No garbage collector. No reference counting. No manual `free()` calls. Memory safety is enforced by scope rules, not by runtime overhead.

## Structured Diagnostics

The compiler emits all diagnostics as structured JSON with a stable schema. Every diagnostic includes:

- A stable error code
- A machine-parseable source location (file, line, column, span)
- A severity level
- A suggested fix, where one is mechanically derivable

This means the generate-compile-repair loop does not require the model to parse English error messages. Repair can be partially mechanical -- the compiler tells the model exactly what is wrong and, in many cases, exactly how to fix it.

## The Tradeoff

toke is more concise than Python, but not less readable. The syntax is compressed, not obfuscated. A developer can read `F=fib(n:i64):i64{?n<2{<n};<fib(n-1)+fib(n-2)};` and understand it -- it is a function named `fib` that takes an integer and returns an integer.

The real tradeoff is breadth. toke does not have the ecosystem of Python or the flexibility of JavaScript. It is not designed to. It is designed to do one thing exceptionally well: be the most efficient language an LLM can generate, compile, and repair.

Human readability is a requirement, not a casualty. But where human convenience conflicts with token efficiency -- verbose keywords, optional syntax, synonym constructs -- token efficiency wins.
