---
title: Type System
description: Complete reference for toke's type system — primitives, composites, type inference, casts, and compatibility rules.
---

toke uses a static type system with no implicit coercions. Every value has a single concrete type known at compile time. This page documents all types, inference rules, and compatibility semantics defined in Profile 1 (the current default).

:::note[Looking for Phase 2?]
Phase 2 uses `$`-prefixed type names and `@` array syntax for higher token density. See the [Phase 2 Type System](/reference/phase2/types/) reference.
:::

## Primitive Types

| Type   | Size    | Range / Values                                          | Zero Value | Literal Examples         |
|--------|---------|---------------------------------------------------------|------------|--------------------------|
| `i64`  | 64 bits | -9,223,372,036,854,775,808 to 9,223,372,036,854,775,807 | `0`        | `42`, `-1`, `0`          |
| `u64`  | 64 bits | 0 to 18,446,744,073,709,551,615                         | `0`        | `0` (via cast from i64)  |
| `f64`  | 64 bits | IEEE 754 double-precision floating point                 | `0.0`      | `3.14`, `0.0`, `-2.5`   |
| `bool` | 1 byte  | `true` or `false`                                       | `false`    | `true`, `false`          |
| `Str`  | pointer | Immutable UTF-8 string of arbitrary length              | `""`       | `"hello"`, `""`          |
| `void` | 0 bytes | Unit type — no value                                    | n/a        | (no literal form)        |

### Numeric types

A type is *numeric* if it is `i64`, `u64`, or `f64`. Arithmetic operators require both operands to be the same numeric type. There is no implicit widening or narrowing between numeric types — use `as` to cast explicitly.

```toke
let x: i64 = 42;
let y: f64 = x as f64;
let z: u64 = 100 as u64;
```

### String type

`Str` is an immutable UTF-8 string. String interpolation is not supported in Profile 1 — use `str.concat()` from the standard library instead.

```toke
let name: Str = "toke";
let greeting: Str = str.concat("hello, ", name);
```

### Boolean type

`bool` has exactly two values: `true` and `false`. These are reserved literals and cannot be used as identifiers.

## Composite Types

### Arrays — `[T]`

An ordered, homogeneous sequence of elements of type `T`.

```toke
let nums: [i64] = [1; 2; 3];
let empty: [i64] = [];
let inferred = [1; 2; 3];
```

- Element type is determined by the first element, or by annotation.
- An empty array literal `[]` has element type `unknown` until constrained by a type annotation.
- Access `.len` to get the number of elements as `u64`.

### Maps — `[K:V]`

A key-value collection where all keys have type `K` and all values have type `V`.

```toke
let ages: [Str:i64] = ["alice": 30; "bob": 25];
```

- Key and value types are determined by the first entry.
- All subsequent entries must match. Inconsistent types produce error [E4043](/reference/errors/#e4043).
- Access `.len` to get the number of entries as `u64`.

### Error Unions — `T!Err`

A sum type representing either a success value of type `T` or an error.

```toke
F=readFile(path: Str): Str!Err {
    let content = file.read(path)!Err;
    < content
};
```

- The `!` postfix operator unwraps the success value or propagates the error to the caller.
- The enclosing function must also return an error union type to use `!`.
- Applying `!` to a non-error-union value produces error [E3020](/reference/errors/#e3020).

## Special Types

### Task — `Task<T>`

The return type of `spawn(f)`, representing an asynchronous task that will produce a value of type `T`.

```toke
F=work(): i64 { < 42 };
F=main(): i64 {
    let t: Task = spawn(work);
    let result: i64 = await(t);
    < result
};
```

- `Task` is not directly writable as a type annotation — it is inferred from `spawn`.
- In Profile 1, `spawn` only accepts nullary (zero-parameter) functions.
- `await(t)` on a `Task<T>` yields type `T`.

### Pointers — `*T` (FFI only)

Raw pointer types for foreign function interface declarations.

```toke
F=malloc(size: u64): *u8;
F=free(ptr: *u8): void;
```

- Pointer types are **only** valid in extern (bodyless) function signatures.
- Using `*T` in a function with a body produces error [E2010](/reference/errors/#e2010).
- The restriction is recursive: `[*T]` and `*[T]` are also rejected in non-extern context.

### Function Types — `func`

Function declarations have type `func` internally. Functions are first-class values that can be passed to `spawn`.

### Struct Types

Named product types declared with `T=`.

```toke
T=Point{x: i64; y: i64};

F=origin(): Point {
    < Point{x: 0; y: 0}
};
```

- Two struct types are equal only if they have the same name (nominal typing).
- Field access uses dot notation: `p.x`.
- Accessing a non-existent field produces error [E4025](/reference/errors/#e4025).

## Type Inference

toke infers types for `let` and `mut` bindings when no annotation is provided.

### Inference rules

| Expression Form             | Inferred Type | Notes                          |
|-----------------------------|---------------|--------------------------------|
| Integer literal (`42`)      | `i64`         |                                |
| Floating-point literal (`3.14`) | `f64`     |                                |
| String literal (`"hello"`)  | `Str`         |                                |
| Boolean literal (`true`)    | `bool`        |                                |
| Array literal `[e1; e2]`    | `[T]`         | T = type of first element      |
| Empty array literal `[]`    | `[unknown]`   | Requires annotation            |
| Map literal `[k1:v1; k2:v2]` | `[K:V]`     | K, V from first entry          |
| Struct literal `Name{...}`  | `Name`        | Resolved via type declaration  |
| Identifier reference        | declared type | From binding, parameter, or function |
| Call expression `f(args)`   | return type   | From function declaration      |
| Field access `expr.field`   | field type    | From struct or `.len` for collections |
| Cast `expr as T`            | `T`           | Target type                    |
| `spawn(f)`                  | `Task<T>`     | T = return type of f           |
| `await(t)`                  | `T`           | T = inner type of Task         |

### Binding inference

```toke
let x = 42;
let y: f64 = 3.14;
let z = mut."hello";
```

When both annotation and initializer are present, their types must match. A mismatch produces error [E4031](/reference/errors/#e4031).

## Cast Expressions

The `as` keyword performs explicit type conversion.

```toke
let x: i64 = 42;
let y: f64 = x as f64;
let z: u64 = x as u64;
```

In Profile 1, all casts are unconditionally allowed. A future profile may restrict which type pairs are castable.

## Type Compatibility

### Equality rules

Two types are equal according to these rules:

| Rule | Condition |
|------|-----------|
| Identity | A type is equal to itself |
| Primitives | Same kind (`i64 == i64`, but `i64 != u64`) |
| Structs | Same name (nominal equality) |
| Pointers | `*T == *U` iff `T == U` |
| Arrays | `[T] == [U]` iff `T == U` (or either is `unknown`) |
| Maps | `[K1:V1] == [K2:V2]` iff `K1 == K2` and `V1 == V2` (or either is `unknown`) |
| Tasks | `Task<T> == Task<U>` iff `T == U` |
| Error unions | `T1!E1 == T2!E2` iff `T1 == T2` (or either is `unknown`) |
| Functions | Equal iff return types are equal |

### No implicit coercions

Profile 1 defines **no implicit coercions**. There is no automatic widening (e.g., `i64` to `f64`), no automatic narrowing, and no implicit conversion between any types. All conversions require an explicit `as` cast.

### The `unknown` type

The internal type `unknown` is a sentinel used when a sub-expression has already emitted an error. It is compatible with any type to suppress cascading errors. It never appears in well-typed programs.
