---
title: "Grammar Encoding"
description: "How toke's grammar was encoded from the legacy profile to the default 56-character syntax — changed production rules and new sigil syntax."
---

This page documents the grammar differences between the default syntax and the [legacy profile](/reference/grammar/). Only changed productions are listed — all other rules are identical.

## Changed Productions

### Type Expressions

The legacy profile uses uppercase-initial identifiers and brackets for composite types. The default syntax uses `$` prefix and `@` sigil.

```ebnf
(* Legacy *)
TypeExpr    = ScalarType | ArrayType | MapType | PtrType | TypeIdent ;
ArrayType   = "[" , TypeExpr , "]" ;
MapType     = "[" , TypeExpr , ":" , TypeExpr , "]" ;
TypeIdent   = UpperIdent ;

(* Default *)
TypeExpr    = ScalarType | ArrayType | MapType | PtrType | SigilType ;
ArrayType   = "@" , TypeExpr ;
MapType     = "$" , "(" , TypeExpr , ":" , TypeExpr , ")" ;
SigilType   = "$" , LowerIdent ;
```

**Examples:**

| Concept | Legacy | Default |
|---------|---------|---------|
| String type | `Str` | `$str` |
| User-defined type | `User` | `$user` |
| Array of integers | `[i64]` | `@i64` |
| Array of strings | `[Str]` | `@$str` |
| Map | `[Str:i64]` | `$($str:i64)` |
| Nested array | `[[i64]]` | `@@i64` |

### Array Literals

```ebnf
(* Legacy *)
ArrayLit    = "[" , [ Expr , { ";" , Expr } ] , "]" ;

(* Default *)
ArrayLit    = "@" , "(" , [ Expr , { ";" , Expr } ] , ")" ;
```

| Legacy | Default |
|---------|---------|
| `[1;2;3]` | `@(1;2;3)` |
| `["a";"b"]` | `@("a";"b")` |
| `[]` | `@()` |

### Map Literals

```ebnf
(* Legacy *)
MapLit      = "[" , MapEntry , { ";" , MapEntry } , "]" ;

(* Default *)
MapLit      = "$" , "(" , MapEntry , { ";" , MapEntry } , ")" ;
```

| Legacy | Default |
|---------|---------|
| `["a":1;"b":2]` | `$("a":1;"b":2)` |

### Array Indexing

```ebnf
(* Legacy *)
IndexExpr   = PostfixExpr , "[" , Expr , "]" ;

(* Default *)
IndexExpr   = PostfixExpr , "." , "get" , "(" , Expr , ")" ;
```

| Legacy | Default |
|---------|---------|
| `arr[0]` | `arr.get(0)` |
| `arr[i]` | `arr.get(i)` |
| `arr[i+1]` | `arr.get(i+1)` |

### Identifiers

```ebnf
(* Legacy *)
Ident       = Letter , { Letter | Digit } ;
Letter      = "a".."z" | "A".."Z" ;
TypeIdent   = UpperLetter , { Letter | Digit } ;

(* Default *)
Ident       = LowerLetter , { LowerLetter | Digit } ;
LowerLetter = "a".."z" ;
SigilIdent  = "$" , LowerLetter , { LowerLetter | Digit } ;
```

There is no `TypeIdent` in the default syntax. All type references use `SigilIdent` (`$name`).

### Struct Literals

```ebnf
(* Legacy *)
StructLit   = TypeIdent , "{" , FieldInit , { ";" , FieldInit } , "}" ;

(* Default *)
StructLit   = SigilIdent , "{" , FieldInit , { ";" , FieldInit } , "}" ;
```

| Legacy | Default |
|---------|---------|
| `Point{x:1;y:2}` | `$point{x:1;y:2}` |
| `User{id:1;name:"alice"}` | `$user{id:1;name:"alice"}` |

### Match Arms

```ebnf
(* Legacy *)
MatchArm    = TypeIdent , ":" , Ident , Expr ;

(* Default *)
MatchArm    = SigilIdent , ":" , Ident , Expr ;
```

| Legacy | Default |
|---------|---------|
| `Ok:val val+1` | `$ok:val val+1` |
| `Err:e defaultVal` | `$err:e defaultval` |

## Unchanged Productions

All of the following are identical in the legacy profile and default syntax:

- **Module structure:** `m=`, `i=`, `t=`, `c=`, `f=` declarations
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

Identical to [legacy profile operator precedence](/reference/grammar/#operator-precedence). No changes.

## LL(1) Property

The default syntax preserves the LL(1) property. The new sigils introduce no ambiguity:

- `$` in expression position always begins a sigil type or map literal
- `@` in expression position always begins an array literal
- `$` in type position always begins a sigil type or map type
- `@` in type position always begins an array type

One token of lookahead after `$` or `@` disambiguates all cases.

## See Also

- [Legacy Grammar](/reference/grammar/) — the legacy profile grammar reference
- [Default Syntax Overview](/reference/phase2/overview/) — complete profile comparison
- [Default Syntax Type System](/reference/phase2/types/) — type notation differences
