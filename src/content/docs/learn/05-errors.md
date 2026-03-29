---
title: "Lesson 5: Error Handling"
description: "Learn toke's explicit error model — error types as values, the Result pattern, propagation with !, and match-based recovery."
---

**Estimated time: ~25 minutes**

## Errors are values, not exceptions

toke has no exceptions, no try/catch, no stack unwinding. Every error is a value that flows through the type system. If a function can fail, its signature says so. If you call a fallible function, you must handle the error at the call site.

This is a deliberate design choice. Exceptions hide control flow. In a language designed for machine generation, hidden control flow means hidden bugs. toke makes every error path visible.

## Error types

Errors are defined as sum types -- tagged unions where each variant represents a distinct failure mode:

```
T=MathErr{
  DivByZero:bool;
  Overflow:Str
};
```

Each variant has a name (starting with uppercase) and a payload type. Use `bool` for variants that carry no meaningful data -- the value `true` is implicit.

Here is a more realistic error type:

```
T=DbErr{
  ConnectionFailed:Str;
  QueryFailed:Str;
  NotFound:u64;
  Timeout:u32
};
```

## The `T!E` return type

When a function can fail, its return type includes the error type after `!`:

```
F=divide(a:f64;b:f64):f64!MathErr{
  if(b=0.0){
    <MathErr.DivByZero(true);
  };
  <a/b;
};
```

The signature `:f64!MathErr` means: "this function returns an `f64` on success, or a `MathErr` on failure." Under the hood, this is a `Result` type with `Ok` and `Err` variants.

A function without `!` in its return type is **total** -- it cannot fail and cannot contain error propagation. The compiler enforces this (E3001).

## Returning errors

To return an error, construct the error variant:

```
F=parse_age(s:Str):i64!ParseErr{
  let n=str.to_int(s)!ParseErr.InvalidInput;
  if(n<0){
    <ParseErr.NegativeAge(s);
  };
  if(n>150){
    <ParseErr.UnreasonableAge(s);
  };
  <n;
};
```

## Error propagation with `!`

The `!` operator is the primary way to handle errors from callees. It propagates errors upward automatically:

```
F=get_user(id:u64):User!ApiErr{
  let row=db.one("SELECT * FROM users WHERE id=?",[id])!ApiErr.DbError;
  <User{id:row.u64("id");name:row.str("name")};
};
```

Here is what `!ApiErr.DbError` does:

1. Call `db.one(...)` which returns `Result<Row, DbErr>`
2. If the result is `Ok(row)`: unwrap and continue, `row` gets the value
3. If the result is `Err(e)`: wrap the error as `ApiErr.DbError(e)` and return it from `get_user`

This is equivalent to writing:

```
let result=db.one("SELECT * FROM users WHERE id=?",[id]);
result|{
  Ok:row  row;
  Err:e   <ApiErr.DbError(e);
};
```

But the `!` version is one line instead of four. In a function with many fallible calls, this compression is significant.

### Chaining propagation

Multiple fallible calls can be chained, each with their own error mapping:

```
F=handle(req:http.Req):http.Res!ApiErr{
  let body=json.dec(req.body)!ApiErr.BadRequest;
  let user=db.get_user(body.id)!ApiErr.DbError;
  let updated=db.save(user)!ApiErr.DbError;
  <http.Res.ok(json.enc(updated));
};
```

Each `!` is a potential early return. If any call fails, the function returns immediately with the mapped error. If all succeed, execution reaches the final return.

## Matching on errors for recovery

When you need to handle errors instead of propagating them, use a match expression:

```
F=get_or_default(id:u64):User{
  db.get_user(id)|{
    Ok:user  <user;
    Err:e    <User{id:0;name:"anonymous"};
  };
};
```

This function is total (no `!` in its return type) because it handles all errors internally.

### Matching specific error variants

You can match on the error type's variants to handle different failures differently:

```
F=resilient_get(id:u64):http.Res{
  db.get_user(id)|{
    Ok:user  <http.Res.ok(json.enc(user));
    Err:e    e|{
      NotFound:_   <http.Res.status(404;"User not found");
      Timeout:_    <http.Res.status(503;"Service temporarily unavailable");
      DbError:msg  <http.Res.status(500;"Internal error: \(msg)");
    };
  };
};
```

## A complete error handling example

Here is a full program demonstrating the error model:

```
M=calc;
I=io:std.io;

T=CalcErr{
  DivByZero:bool;
  InvalidOp:Str
};

F=divide(a:f64;b:f64):f64!CalcErr{
  if(b=0.0){
    <CalcErr.DivByZero(true);
  };
  <a/b;
};

F=calc(a:f64;op:Str;b:f64):f64!CalcErr{
  if(op="+"){<a+b};
  if(op="-"){<a-b};
  if(op="*"){<a*b};
  if(op="/"){
    let result=divide(a;b)!CalcErr.DivByZero;
    <result;
  };
  <CalcErr.InvalidOp(op);
};

F=main():i64{
  calc(10.0;"/"  ;3.0)|{
    Ok:v   io.println("Result: \(v as Str)");
    Err:e  e|{
      DivByZero:_  io.println("Error: division by zero");
      InvalidOp:op io.println("Error: unknown operator \(op)");
    };
  };
  <0;
};
```

## Exercises

### Exercise 1: Safe division

Write a function `F=safe_div(a:i64;b:i64):i64!MathErr` that returns a `DivByZero` error when `b` is zero. Write a `main` function that calls it and prints either the result or an error message using match.

### Exercise 2: Lookup with error

Define an error type `T=LookupErr{NotFound:Str;EmptyMap:bool}`. Write a function `F=lookup(m:[Str:i64];key:Str):i64!LookupErr` that:
- Returns `EmptyMap` if the map has zero entries
- Returns `NotFound(key)` if the key does not exist
- Returns the value otherwise

### Exercise 3: Error chain

Write two functions:
- `F=parse_int(s:Str):i64!ParseErr` that wraps `str.to_int`
- `F=parse_and_double(s:Str):i64!CalcErr` that calls `parse_int` and propagates the error as `CalcErr.BadInput`, then doubles the result

This exercises the `!` propagation with error type mapping.

## Key takeaways

- toke has no exceptions -- errors are values in the type system
- Error types are sum types: `T=MyErr{Variant1:Type1;Variant2:Type2}`
- `:T!E` in a return type means the function can return either `T` (success) or `E` (error)
- `expr!ErrVariant` propagates errors upward, mapping to the current function's error type
- `expr|{Ok:v handle_success; Err:e handle_error}` matches on results for recovery
- Match is exhaustive -- every variant must be handled
- Functions without `!` are total and cannot propagate errors

## Next

[Lesson 6: Strings and I/O](/learn/06-strings-io/) -- string operations, file I/O, and JSON.
