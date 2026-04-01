---
title: "Phase 2 Grammar"
description: "Grammar reference for toke Phase 2 — production rule changes from Phase 1, new sigil syntax, and array transformation."
---

This page documents the grammar differences between Phase 2 and [Phase 1](/reference/grammar/). Only changed productions are listed — all other rules are identical.

:::tip
If you are new to toke, start with the [Grammar reference](/reference/grammar/) which now uses Phase 2 notation.
:::

## Changed Productions

### Type Expressions

Phase 1 uses uppercase-initial identifiers and brackets for composite types. Phase 2 uses `$` prefix and `@` sigil.

```ebnf
(* Phase 1 *)
TypeExpr    = ScalarType | ArrayType | MapType | PtrType | TypeIdent ;
ArrayType   = "[" , TypeExpr , "]" ;
MapType     = "[" , TypeExpr , ":" , TypeExpr , "]" ;
TypeIdent   = UpperIdent ;

(* Phase 2 *)
TypeExpr    = ScalarType | ArrayType | MapType | PtrType | SigilType ;
ArrayType   = "@" , TypeExpr ;
MapType     = "$" , "(" , TypeExpr , ":" , TypeExpr , ")" ;
SigilType   = "$" , LowerIdent ;
```

**Examples:**

| Concept | Phase 1 | Phase 2 |
|---------|---------|---------|
| String type | `Str` | `$str` |
| User-defined type | `User` | `$user` |
| Array of integers | `[i64]` | `@i64` |
| Array of strings | `[Str]` | `@$str` |
| Map | `[Str:i64]` | `$($str:i64)` |
| Nested array | `[[i64]]` | `@@i64` |

### Array Literals

```ebnf
(* Phase 1 *)
ArrayLit    = "[" , [ Expr , { ";" , Expr } ] , "]" ;

(* Phase 2 *)
ArrayLit    = "@" , "(" , [ Expr , { ";" , Expr } ] , ")" ;
```

| Phase 1 | Phase 2 |
|---------|---------|
| `[1;2;3]` | `@(1;2;3)` |
| `["a";"b"]` | `@("a";"b")` |
| `[]` | `@()` |

### Map Literals

```ebnf
(* Phase 1 *)
MapLit      = "[" , MapEntry , { ";" , MapEntry } , "]" ;

(* Phase 2 *)
MapLit      = "$" , "(" , MapEntry , { ";" , MapEntry } , ")" ;
```

| Phase 1 | Phase 2 |
|---------|---------|
| `["a":1;"b":2]` | `$("a":1;"b":2)` |

### Array Indexing

```ebnf
(* Phase 1 *)
IndexExpr   = PostfixExpr , "[" , Expr , "]" ;

(* Phase 2 -- constant index *)
IndexExpr   = PostfixExpr , "." , IntLit ;

(* Phase 2 -- variable index *)
IndexExpr   = PostfixExpr , "." , "get" , "(" , Expr , ")" ;
```

| Phase 1 | Phase 2 |
|---------|---------|
| `arr[0]` | `arr.0` |
| `arr[i]` | `arr.get(i)` |
| `arr[i+1]` | `arr.get(i+1)` |

### Identifiers

```ebnf
(* Phase 1 *)
Ident       = Letter , { Letter | Digit } ;
Letter      = "a".."z" | "A".."Z" ;
TypeIdent   = UpperLetter , { Letter | Digit } ;

(* Phase 2 *)
Ident       = LowerLetter , { LowerLetter | Digit } ;
LowerLetter = "a".."z" ;
SigilIdent  = "$" , LowerLetter , { LowerLetter | Digit } ;
```

There is no `TypeIdent` in Phase 2. All type references use `SigilIdent` (`$name`).

### Struct Literals

```ebnf
(* Phase 1 *)
StructLit   = TypeIdent , "{" , FieldInit , { ";" , FieldInit } , "}" ;

(* Phase 2 *)
StructLit   = SigilIdent , "{" , FieldInit , { ";" , FieldInit } , "}" ;
```

| Phase 1 | Phase 2 |
|---------|---------|
| `Point{x:1;y:2}` | `$point{x:1;y:2}` |
| `User{id:1;name:"alice"}` | `$user{id:1;name:"alice"}` |

### Match Arms

```ebnf
(* Phase 1 *)
MatchArm    = TypeIdent , ":" , Ident , Expr ;

(* Phase 2 *)
MatchArm    = SigilIdent , ":" , Ident , Expr ;
```

| Phase 1 | Phase 2 |
|---------|---------|
| `Ok:val val+1` | `$ok:val val+1` |
| `Err:e defaultVal` | `$err:e defaultval` |

## Unchanged Productions

All of the following are identical in Phase 1 and Phase 2:

- **Module structure:** `M=`, `I=`, `T=`, `C=`, `F=` declarations
- **Function declarations:** parameter lists, return types, bodies
- **Statements:** `let`, `mut`, assignment, return (`<`)
- **Control flow:** `if(){}`, `el{}`, `lp(){}`, `br`
- **Operators:** `+`, `-`, `*`, `/`, `<`, `>`, `=`, `!`, `|`
- **Error handling:** `!` propagation, match expressions
- **String literals:** delimiters, escape sequences, content
- **Numeric literals:** integers, floats, hex
- **Semicolons:** statement terminators, field/parameter separators
- **Comments:** none (same in both profiles)

## Operator Precedence

Identical to [Phase 1 operator precedence](/reference/grammar/#operator-precedence). No changes.

## LL(1) Property

Phase 2 preserves the LL(1) property. The new sigils introduce no ambiguity:

- `$` in expression position always begins a sigil type or map literal
- `@` in expression position always begins an array literal
- `$` in type position always begins a sigil type or map type
- `@` in type position always begins an array type

One token of lookahead after `$` or `@` disambiguates all cases.

## See Also

- [Phase 1 Grammar](/reference/grammar/) — the current default reference
- [Phase 2 Overview](/reference/phase2/overview/) — complete profile comparison
- [Phase 2 Type System](/reference/phase2/types/) — type notation differences
