---
title: Error Codes
description: Complete reference for all toke compiler error and warning codes, grouped by compilation stage.
---

The toke compiler emits structured JSON diagnostics with stable error codes. Error codes are permanent — they are never renumbered or redefined. Each code belongs to a series that identifies the compilation stage that emits it.

## Error Code Series

| Series | Range       | Stage              |
|--------|-------------|--------------------|
| E1xxx  | 1000--1999  | Lexer              |
| E2xxx  | 2000--2999  | Parser             |
| E3xxx  | 3000--3999  | Name Resolution    |
| E4xxx  | 4000--4999  | Type Checker       |
| E5xxx  | 5000--5999  | Arena Validator    |
| E6xxx  | 6000--6999  | IR Lowerer         |
| E9xxx  | 9000--9999  | Codegen / Internal |
| W1xxx  | 1000--1999  | Warnings           |

---

## Lexer Errors (E1xxx)

### E1001

**Invalid escape sequence**

| Field    | Value |
|----------|-------|
| Severity | error |
| Stage    | lex   |

Emitted when a backslash in a string literal is followed by a character that is not one of `"`, `\`, `n`, `t`, `r`, `0`, `x`, or `(`. Also emitted when `\x` is not followed by exactly two hex digits.

```toke
f=bad(): $str { < "\q" };
```

Triggers E1001.

**Fix:** Use a valid escape sequence. Valid escapes are `\"`, `\\`, `\n`, `\t`, `\r`, `\0`, and `\xHH` (two hex digits).

---

### E1002

**Unterminated string literal**

| Field    | Value |
|----------|-------|
| Severity | error |
| Stage    | lex   |

The lexer reaches end-of-input before encountering a closing `"`.

```toke
f=bad(): $str { < "unterminated };
```

Triggers E1002.

**Fix:** Add the closing `"` to terminate the string literal.

---

### E1003

**Character outside permitted character set**

| Field    | Value |
|----------|-------|
| Severity | error |
| Stage    | lex   |

Any byte that is not whitespace, alphanumeric, or a recognized symbol triggers this error. toke uses ASCII only.

```toke
m=test;
f=bad(): i64 { < 1 };
```

The above is valid; E1003 triggers when non-ASCII characters like `£` appear in source.

**Fix:** Remove or replace the non-ASCII character with valid ASCII.

---

### E1010

**Reserved literal used as identifier**

| Field    | Value |
|----------|-------|
| Severity | error |
| Stage    | parse |

The literals `true` and `false` cannot be used as identifiers.

```toke
m=test;
f=bad(): i64 { let true = 1; < true };
```

Triggers E1010.

**Fix:** Choose a different identifier name.

---

## Lexer Warnings (W1xxx)

### W1010

**String interpolation not yet supported**

| Field    | Value   |
|----------|---------|
| Severity | warning |
| Stage    | lex     |

The `\(` sequence inside a string literal triggers this warning. String interpolation is planned for a future release.

```toke
m=test;
f=greet(): $str { < "hello \(name)" };
```

Triggers W1010.

**Fix:** Use `str.concat()` for string composition instead.

---

## Parser Errors (E2xxx)

### E2001

**Declaration ordering violation**

| Field    | Value |
|----------|-------|
| Severity | error |
| Stage    | parse |

A toke source file must follow the declaration order: `m` (module), `i` (import), `t` (type), `C` (constant), `f` (function). This error fires when a declaration appears out of order or when the `m=` declaration is missing.

```toke
f=bad(): i64 { < 0 };
```

Triggers E2001 (missing module declaration).

**Fix:** Ensure declarations appear in the required order, starting with `m=`.

---

### E2002

**Unexpected token**

| Field    | Value |
|----------|-------|
| Severity | error |
| Stage    | parse |

The parser encountered a token it cannot consume in the current grammatical context.

```toke
m=test;
f=bad(): i64 { < 1 };
```

E2002 triggers when an unexpected token appears (e.g. a stray symbol).

**Fix:** Check for typos or misplaced operators near the reported position.

---

### E2003

**Missing semicolon**

| Field    | Value |
|----------|-------|
| Severity | error |
| Stage    | parse |

A semicolon is required between consecutive statements inside a block. Semicolons may be elided before `}` or at end-of-file.

```toke
m=test;
f=bad(): i64 { let x = 1 let y = 2; < x };
```

Triggers E2003.

**Fix:** Add a `;` between the two statements.

---

### E2004

**Unclosed delimiter**

| Field    | Value |
|----------|-------|
| Severity | error |
| Stage    | parse |

A `(`, `[`, or `{` was opened but the matching closing delimiter was not found.

```toke
m=test;
f=bad(): i64 { < (1 + 2 };
```

Triggers E2004.

**Fix:** Add the matching `)`, `]`, or `}`.

---

### E2010

**Pointer type outside extern function**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

Pointer types (`*T`) are only valid in extern (bodyless) function signatures. Using `*T` in a function with a body produces this error.

```toke
m=test;
f=bad(s: *u8): i64 { < 42 };
```

Triggers E2010.

**Fix:** Either remove the pointer type or make the function an extern declaration (remove the body).

---

## Import/Module Errors (E2xxx continued)

### E2030

**Unresolved import**

| Field    | Value           |
|----------|-----------------|
| Severity | error           |
| Stage    | name_resolution |

The module path in an `i=` declaration does not resolve to any `.tki` interface file on the search path.

**Fix:** Check the module path spelling and ensure the dependency is available.

---

### E2031

**Circular import detected**

| Field    | Value           |
|----------|-----------------|
| Severity | error           |
| Stage    | name_resolution |

The import graph contains a cycle. Module A imports B which (directly or transitively) imports A.

**Fix:** Restructure modules to break the circular dependency.

---

### E2035

**Malformed version string in import**

| Field    | Value           |
|----------|-----------------|
| Severity | error           |
| Stage    | name_resolution |

The optional version string in an import declaration does not match the expected `MAJOR.MINOR` or `MAJOR.MINOR.PATCH` format.

```toke
m=test;
i=io:std.io "abc";
```

Triggers E2035.

**Fix:** Use a valid version string like `"1.0"` or `"1.0.0"`.

---

### E2036

**No compatible version found**

| Field    | Value           |
|----------|-----------------|
| Severity | error           |
| Stage    | name_resolution |

Reserved. Interface files were found but none match the requested version constraint.

---

### E2037

**Version conflict between imports**

| Field    | Value           |
|----------|-----------------|
| Severity | error           |
| Stage    | name_resolution |

Two import declarations reference the same module path with different major versions. toke does not support diamond-dependency version conflicts within a single compilation unit.

**Fix:** Align all imports of the same module to the same major version.

---

## Name Resolution Errors (E3xxx)

### E3011

**Identifier not declared**

| Field    | Value           |
|----------|-----------------|
| Severity | error           |
| Stage    | name_resolution |

A reference to an identifier that does not exist in any enclosing scope.

```toke
m=test;
f=bad(): i64 { < x };
```

Triggers E3011.

**Fix:** Declare the identifier before using it, or check for typos.

---

### E3012

**Identifier already declared in this scope**

| Field    | Value           |
|----------|-----------------|
| Severity | error           |
| Stage    | name_resolution |

A second declaration of the same name in the same scope. Shadowing across scope boundaries is allowed; duplicate declaration within one scope is not.

```toke
m=test;
f=bad(): i64 { let x = 1; let x = 2; < x };
```

Triggers E3012.

**Fix:** Use a different name for the second binding, or remove the duplicate.

---

### E3020

**`!` applied to non-error-union value**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

The propagation operator `!` can only be applied to a value whose type is an error union (`T!Err`), and only inside a function whose return type is also an error union.

**Fix:** Ensure the expression has an error union type and the enclosing function returns an error union.

---

## Type Checker Errors (E4xxx)

### E4010

**Non-exhaustive match**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

A `match` expression over a `bool` scrutinee must cover both `true` and `false`.

```toke
m=test;
f=bad(): i64 { < true|{True:v 1} };
```

Triggers E4010 (non-exhaustive match: missing arm for `false`).

**Fix:** Add the missing match arm(s) to cover all cases.

---

### E4011

**Match arms have inconsistent types**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

All arms of a `match` expression must evaluate to the same type.

**Fix:** Ensure all arms return the same type, using explicit casts if needed.

---

### E4025

**Struct has no field with that name**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

A field access expression (`expr.field`) references a field name that does not exist in the struct type.

**Fix:** Check the struct type declaration for the correct field name.

---

### E4031

**Type mismatch**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

The workhorse type error. Emitted for mismatched operands in binary expressions, mismatched function arguments, mismatched binding annotations, mismatched assignment sides, and mismatched return values.

The diagnostic may include a fix suggestion such as `"cast RHS to i64 using 'as'"`.

**Fix:** Ensure both sides of the operation have matching types. Use `as` for explicit casts.

---

### E4040

**Map key type mismatch**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

Reserved. Planned for map key type checking beyond literal consistency.

---

### E4041

**Map value type mismatch**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

Reserved. Planned for map value type checking beyond literal consistency.

---

### E4042

**Method on non-collection type**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

Reserved. Planned for calling collection methods (e.g., `.push`, `.get`) on non-collection types.

---

### E4043

**Inconsistent types in map literal**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

All entries in a map literal must have the same key type and the same value type. The first entry establishes the expected types.

```toke
m=test;
f=bad(): i64 { < $(1: 10; 2: "x") };
```

Triggers E4043.

**Fix:** Ensure all map keys have the same type and all map values have the same type.

---

### E4050

**spawn argument not a callable function**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

`spawn(f)` requires its argument to be a declared function.

**Fix:** Pass a function name (not an expression or non-function identifier) to `spawn`.

---

### E4051

**await argument not a Task**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

`await(t)` requires its argument to have type `Task<T>`.

```toke
m=test;
f=notask(): i64 { < 42 };
f=main(): i64 { < await(notask()) };
```

Triggers E4051.

**Fix:** Only call `await` on values returned by `spawn`.

---

### E4052

**Spawned function has parameters**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

`spawn` only accepts nullary (zero-parameter) functions.

**Fix:** Wrap the parameterized function in a nullary function.

---

### E4060

**FFI type mismatch**

| Field    | Value      |
|----------|------------|
| Severity | error      |
| Stage    | type_check |

Reserved. Planned for type mismatches at FFI boundaries.

---

## Arena Errors (E5xxx)

### E5001

**Value escapes arena scope**

| Field    | Value       |
|----------|-------------|
| Severity | error       |
| Stage    | arena_check |

Inside an `{arena ...}` block, assigning an arena-allocated value to a variable declared in an outer scope would create a dangling reference when the arena is freed.

```toke
m=test;
f=bad(): i64 { let x = 0; {arena x = 1}; < x };
```

Triggers E5001.

**Fix:** Do not assign arena-scoped values to variables from outer scopes.

---

## Codegen / Internal Errors (E9xxx)

### E9001

**Failed to write interface file**

| Field    | Value   |
|----------|---------|
| Severity | error   |
| Stage    | codegen |

The compiler could not open or flush the `.tki` interface file. This is an I/O error, not a source-level error.

**Fix:** Check file permissions and disk space.

---

### E9002

**LLVM IR emission failed**

| Field    | Value   |
|----------|---------|
| Severity | error   |
| Stage    | codegen |

The compiler could not create or write the `.ll` output file.

**Fix:** Check file permissions, disk space, and output directory existence.

---

### E9003

**clang invocation failed**

| Field    | Value   |
|----------|---------|
| Severity | error   |
| Stage    | codegen |

After emitting `.ll` IR, the compiler invokes `clang -O1` to produce a binary. If clang exits non-zero, this error is reported.

**Fix:** Ensure `clang` is installed and available on your PATH. Check the clang error output for details.

---

## Quick Reference Table

| Code  | Severity | Stage           | Description                                  |
|-------|----------|-----------------|----------------------------------------------|
| E1001 | error    | lex             | Invalid escape sequence                      |
| E1002 | error    | lex             | Unterminated string literal                  |
| E1003 | error    | lex             | Character outside permitted set              |
| E1010 | error    | parse           | Reserved literal used as identifier          |
| W1010 | warning  | lex             | String interpolation not yet supported       |
| E2001 | error    | parse           | Declaration ordering violation               |
| E2002 | error    | parse           | Unexpected token                             |
| E2003 | error    | parse           | Missing semicolon                            |
| E2004 | error    | parse           | Unclosed delimiter                           |
| E2010 | error    | type_check      | Pointer type outside extern function         |
| E2030 | error    | name_resolution | Unresolved import                            |
| E2031 | error    | name_resolution | Circular import detected                     |
| E2035 | error    | name_resolution | Malformed version string in import           |
| E2036 | error    | name_resolution | No compatible version found (reserved)       |
| E2037 | error    | name_resolution | Version conflict between imports             |
| E3011 | error    | name_resolution | Identifier not declared                      |
| E3012 | error    | name_resolution | Identifier already declared in scope         |
| E3020 | error    | type_check      | `!` applied to non-error-union value         |
| E4010 | error    | type_check      | Non-exhaustive match                         |
| E4011 | error    | type_check      | Match arms have inconsistent types           |
| E4025 | error    | type_check      | Struct has no field with that name           |
| E4031 | error    | type_check      | Type mismatch / implicit coercion            |
| E4040 | error    | type_check      | Map key type mismatch (reserved)             |
| E4041 | error    | type_check      | Map value type mismatch (reserved)           |
| E4042 | error    | type_check      | Method on non-collection type (reserved)     |
| E4043 | error    | type_check      | Inconsistent types in map literal            |
| E4050 | error    | type_check      | spawn argument not callable                  |
| E4051 | error    | type_check      | await argument not a Task                    |
| E4052 | error    | type_check      | Spawned function has parameters              |
| E4060 | error    | type_check      | FFI type mismatch (reserved)                 |
| E5001 | error    | arena_check     | Value escapes arena scope                    |
| E9001 | error    | codegen         | Failed to write interface file               |
| E9002 | error    | codegen         | LLVM IR emission failed                      |
| E9003 | error    | codegen         | clang invocation failed                      |
