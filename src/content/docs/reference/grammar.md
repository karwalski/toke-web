---
title: Grammar
description: Formal grammar reference for the toke language — EBNF production rules, key productions, and operator precedence.
---

This page defines the formal grammar of toke. The grammar is LL(1)-compatible, meaning it can be parsed with a single token of lookahead and no backtracking.

## EBNF Notation

The grammar uses standard EBNF notation:

| Notation    | Meaning                           |
|-------------|-----------------------------------|
| `=`         | Definition                        |
| `,`         | Concatenation                     |
| `\|`        | Alternation                       |
| `[ ... ]`   | Optional (zero or one)            |
| `{ ... }`   | Repetition (zero or more)         |
| `( ... )`   | Grouping                          |
| `"..."`     | Terminal string                   |
| `(*...*)`   | Comment                           |

## Production Rules

### Module Structure

```ebnf
Module      = ModuleDecl , { ImportDecl } , { TypeDecl } , { ConstDecl } , { FuncDecl } ;

ModuleDecl  = "m" , "=" , Ident , ";" ;

ImportDecl  = "i" , "=" , Ident , ":" , ModulePath , [ VersionStr ] , ";" ;

ModulePath  = Ident , { "." , Ident } ;

VersionStr  = StringLit ;
```

Declarations must appear in this exact order: module, imports, types, constants, functions. Violating this order produces error [E2001](/reference/errors/#e2001).

### Type Declarations

```ebnf
TypeDecl    = "t" , "=" , "$" , Ident , "{" , FieldList , "}" , ";" ;

FieldList   = Field , { ";" , Field } , [ ";" ] ;

Field       = Ident , ":" , TypeExpr ;
```

### Constant Declarations

```ebnf
ConstDecl   = "c" , "=" , Ident , [ ":" , TypeExpr ] , Expr , ";" ;
```

### Function Declarations

```ebnf
FuncDecl    = "f" , "=" , Ident , "(" , [ ParamList ] , ")" ,
              [ ":" , TypeExpr ] , ( Block | ";" ) ;

ParamList   = Param , { ";" , Param } ;

Param       = Ident , ":" , TypeExpr ;

Block       = "{" , StmtList , "}" ;
```

A function declaration without a body (terminated by `;` instead of a block) is an **extern declaration** for FFI.

### Type Expressions

```ebnf
TypeExpr    = PrimType
            | "@" , "(" , TypeExpr , ")"                   (* array *)
            | "$" , "(" , TypeExpr , ":" , TypeExpr , ")"  (* map *)
            | TypeExpr , "!" , Ident                       (* error union *)
            | "*" , TypeExpr                               (* pointer, FFI only *)
            | "$" , Ident                                  (* named type / struct *)
            ;

PrimType    = "i64" | "u64" | "f64" | "bool" | "$str" | "void" ;
```

### Statements

```ebnf
StmtList    = { Stmt , [ ";" ] } ;

Stmt        = LetStmt
            | MutStmt
            | AssignStmt
            | ReturnStmt
            | IfStmt
            | MatchExpr
            | LoopStmt
            | ArenaStmt
            | ExprStmt
            ;

LetStmt     = "let" , Ident , [ ":" , TypeExpr ] , "=" , Expr ;

MutStmt     = "mut" , Ident , [ ":" , TypeExpr ] , "=" , Expr ;

AssignStmt  = Ident , "=" , Expr ;

ReturnStmt  = "<" , Expr ;

IfStmt      = "?" , "(" , Expr , ")" , Block , [ ":" , Block ] ;

LoopStmt    = "lp" , "(" , [ LoopInit ] , ";" , [ Expr ] , ";" , [ Expr ] , ")" , Block ;

LoopInit    = ( "let" | "mut" ) , Ident , [ ":" , TypeExpr ] , "=" , Expr ;

ArenaStmt   = "{" , "arena" , StmtList , "}" ;

ExprStmt    = Expr ;
```

### Expressions

```ebnf
Expr        = UnaryExpr , [ BinOp , Expr ]
            | CallExpr
            | FieldExpr
            | CastExpr
            | PropagateExpr
            | MatchExpr
            | Literal
            | Ident
            | "(" , Expr , ")"
            ;

UnaryExpr   = [ "-" ] , PrimaryExpr ;

BinOp       = "+" | "-" | "*" | "/" | "<" | ">" | "==" | "&&" | "||" ;

CallExpr    = Ident , "(" , [ ArgList ] , ")" ;

ArgList     = Expr , { "," , Expr } ;

FieldExpr   = Expr , "." , Ident ;

CastExpr    = Expr , "as" , TypeExpr ;

PropagateExpr = Expr , "!" ;

MatchExpr   = "match" , Expr , "{" , MatchArm , { ";" , MatchArm } , [ ";" ] , "}" ;

MatchArm    = Pattern , "=>" , ( Expr | Block ) ;

Pattern     = Literal | Ident | "_" ;
```

### Literals

```ebnf
IntLit      = Digit , { Digit } ;

FloatLit    = Digit , { Digit } , "." , Digit , { Digit } ;

StringLit   = '"' , { StringChar } , '"' ;

StringChar  = (* any ASCII character except '"' and '\' *)
            | EscapeSeq ;

EscapeSeq   = '\' , ( '"' | '\' | 'n' | 't' | 'r' | '0' | HexEscape ) ;

HexEscape   = 'x' , HexDigit , HexDigit ;

BoolLit     = "true" | "false" ;

ArrayLit    = "@" , "(" , [ Expr , { ";" , Expr } , [ ";" ] ] , ")" ;

MapLit      = "$" , "(" , MapEntry , { ";" , MapEntry } , [ ";" ] , ")" ;

MapEntry    = Expr , ":" , Expr ;

StructLit   = "$" , Ident , "{" , FieldInit , { ";" , FieldInit } , [ ";" ] , "}" ;

FieldInit   = Ident , ":" , Expr ;

Ident       = Letter , { Letter | Digit } ;

Letter      = "a" .. "z" ;

Digit       = "0" .. "9" ;

HexDigit    = Digit | "a" .. "f" | "A" .. "F" ;
```

## Key Productions Explained

### Module

Every toke source file is a `Module`. It begins with a mandatory module declaration (`m=name;`) followed by optional imports, type declarations, constants, and function declarations — in that strict order.

```toke
m=myapp;
i=io:std.file;
t=Config{port: i64; host: $str};
f=main(): void { };
```

### FuncDecl

Functions are declared with `f=name(params):ReturnType { body }`. A function without a body is an extern (FFI) declaration. The return statement uses `<` instead of a `return` keyword.

```toke
f=add(a: i64; b: i64): i64 { < a + b };
f=puts(s: *u8): void;
```

### TypeExpr

Type expressions describe the type of a value. They can be primitives, arrays (`@(T)`), maps (`$(K:V)`), error unions (`T!Err`), pointers (`*T`, FFI only), or named struct types (`$name`).

### Stmt

Statements within a block are separated by semicolons. The trailing semicolon before a closing `}` or at end-of-file may be omitted (trailing-semicolon elision).

### Expr

Expressions produce values. The `<` return statement, `match` expressions, `as` casts, and the `!` propagation operator are all expression forms.

## LL(1) Property

The toke grammar is designed to be LL(1)-parseable:

- **Single token lookahead.** At every decision point in the grammar, the parser can determine which production to use by examining only the current token.
- **No backtracking.** The parser never needs to speculatively try a production and then undo work.
- **Predictable performance.** Parsing time is linear in the number of tokens.

Key design choices that enable LL(1) parsing:

- Declaration prefixes (`m=`, `i=`, `t=`, `c=`, `f=`) are unique single-token lookaheads.
- Statement prefixes (`let`, `mut`, `<`, `?`, `lp`, `match`, `{arena`) are distinct.
- The `<` return operator avoids ambiguity with the comparison `<` because return always appears at statement position.

## Operator Precedence

Operators are listed from highest to lowest precedence:

| Precedence | Operator(s)        | Associativity | Description              |
|------------|--------------------|---------------|--------------------------|
| 1 (highest)| `.`                | Left          | Field access             |
| 2          | `()`               | Left          | Function call            |
| 3          | `!` (postfix)      | Left          | Error propagation        |
| 4          | `-` (unary)        | Right         | Negation                 |
| 5          | `as`               | Left          | Type cast                |
| 6          | `*`, `/`           | Left          | Multiplication, division |
| 7          | `+`, `-`           | Left          | Addition, subtraction    |
| 8          | `<`, `>`, `==`     | Left          | Comparison               |
| 9          | `&&`               | Left          | Logical AND              |
| 10 (lowest)| `\|\|`             | Left          | Logical OR               |

### Precedence examples

```toke
a + b * c
x.len + 1
value!Err + 1
x as f64 + 1.0
a > 0
```
