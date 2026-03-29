---
title: "Lesson 8: Advanced Topics"
description: "Explore FFI with extern functions, pointer types, async with spawn and await, tasks, casts, and arena blocks."
---

**Estimated time: ~25 minutes**

## Foreign function interface (FFI)

toke compiles to native binaries, which means it can call C functions directly. This is how the standard library is implemented -- toke source calls into C runtime support.

### Extern function declarations

An extern function is declared with `F=` but has no body:

```
F=cstrlen(s:*u8):u64;
```

The missing body tells the compiler this function is defined externally (in C or another language) and will be provided at link time.

### Calling extern functions

Once declared, extern functions are called like any other function:

```
M=ffidemo;

F=cstrlen(s:*u8):u64;
F=cputs(s:*u8):i32;

F=main():i64{
  let msg="Hello from C\0";
  cputs(msg as *u8);
  <0;
};
```

Note the `\0` at the end of the string -- C functions expect null-terminated strings.

### Linking

When using FFI, you tell the compiler which libraries to link:

```bash
tkc ffidemo.tk -lc -o ffidemo
```

The `-lc` flag links the C standard library.

## Pointer types

Pointer types are written `*T` where `T` is the pointed-to type:

| Type | Meaning |
|------|---------|
| `*u8` | Pointer to a byte (used for C strings) |
| `*i32` | Pointer to a 32-bit integer |
| `*void` | Opaque pointer (void pointer) |

### Pointers are FFI-only

In pure toke code, you never need pointers. All memory access is through named fields, array indices, and function calls. Pointers exist solely for interoperability with C libraries.

### Safety warning

Pointer operations bypass toke's safety guarantees. A null pointer dereference through FFI produces runtime trap RT004. Memory accessed through pointers is not arena-managed -- the programmer is responsible for correct lifetime management at the FFI boundary.

## Type casts with `as`

The `as` keyword performs explicit type conversion:

```
let x=42;
let y=x as f64;
let z=3.14 as i64;
let wide=narrow as i64;
```

### Cast rules

- **Numeric widening** (i32 to i64, f32 to f64): always safe
- **Numeric narrowing** (i64 to i32, f64 to f32): compiles with warning W1001, runtime trap if value does not fit
- **Int to float** (i64 to f64): may lose precision for very large integers
- **Float to int** (f64 to i64): truncates toward zero
- **To Str** (`x as Str`): converts numbers to their string representation
- **Pointer casts** (`s as *u8`): for FFI use only

There are **no implicit conversions** in toke. Every conversion must use `as`. This is enforced by the compiler -- passing an `i32` where `i64` is expected is a type error (E4020).

## Async: spawn and await

toke supports concurrent execution through spawning tasks.

### Spawning a task

The `spawn` function starts a function as a concurrent task:

```
let task=spawn(fetchData);
```

This returns a `Task` value immediately. The spawned function runs concurrently.

### Awaiting a task

The `await` function blocks until a task completes and returns its result:

```
let result=await(task);
```

### The Task type

A `Task` is parameterised by the return type of the spawned function. If `fetchData` returns `Str!HttpErr`, then `spawn(fetchData)` returns `Task<Str!HttpErr>`, and `await(task)` produces the `Str!HttpErr` result.

### Concurrent HTTP requests

```
M=parallel;
I=http:std.http;
I=io:std.io;

F=fetch(url:Str):Str!http.Err{
  let res=http.get(url)!http.Err;
  <res.body;
};

F=main():i64{
  let t1=spawn(fetch);
  let t2=spawn(fetch);
  let t3=spawn(fetch);

  let users=await(t1);
  let posts=await(t2);
  let comments=await(t3);

  users|{
    Ok:data  io.println("Users: \(data)");
    Err:e    io.println("Failed to fetch users");
  };
  <0;
};
```

All three HTTP requests run concurrently. The `await` calls block until each completes. The total time is roughly the time of the slowest request, not the sum of all three.

### Concurrency notes

Concurrency semantics are partially specified in toke v0.1. The key guarantees:

- Spawned tasks run independently
- `await` blocks the current task until the spawned task completes
- There is no shared mutable state between tasks (no data races by construction)
- Communication between tasks happens through the return value

Full concurrency semantics (channels, select, structured concurrency) are deferred to v0.2.

## Arena blocks

:::note
Arena blocks (`{arena ...}`) are a planned Phase 2 feature. The syntax is supported by the parser but arena-based allocation is not yet implemented in the compiler backend.
:::

By default, all allocations within a function are freed when the function returns. Arena blocks create shorter-lived allocation regions:

```
F=processLargeData(items:[Str]):Str{
  let result=mut."";
  lp(let i=0;i<items.len;i=i+1){
    {arena
      let temp=str.upper(items[i]);
      let processed=str.replace(temp;" ";"-");
      result=result+processed+"\n";
    };
  };
  <result;
};
```

The `{arena ... }` block allocates `temp` and `processed` within a sub-arena. When the block exits, those allocations are freed immediately -- not at function exit. The `result` variable, bound outside the arena, survives.

### Why use arena blocks?

In a loop processing large data, allocations can accumulate. Without arena blocks, every temporary string, array, or struct lives until the function returns. Arena blocks let you free temporaries per iteration, keeping memory usage bounded.

### Arena safety

Returning a reference to an arena-allocated value across the arena boundary is a compile error (E5001):

```
{arena
  let temp=[1;2;3];
  result=temp;
};
```

The compiler prevents use-after-free at the arena boundary.

## Module versioning (future)

Import declarations will support version strings in a future specification:

```
I=http:std.http "1.2";
```

This pins the import to a specific version of the module. Version resolution and package registry semantics are deferred to a later version of the spec.

## Exercises

### Exercise 1: Cast practice

Write a function `F=stats(arr:[i64]):void` that computes and prints:
- The sum (as i64)
- The count (as i64)
- The average (as f64 -- cast sum and count before dividing)

### Exercise 2: Concurrent fetches

Write a program that spawns three tasks to simulate parallel work. Each task should call a function that returns a string after doing some computation. Await all three and print the results.

### Exercise 3: Arena usage

Write a function that processes an array of 1000 strings. Use an arena block inside the loop to ensure temporary allocations are freed per iteration. Print the final aggregated result.

## Key takeaways

- Extern functions (`F=` with no body) declare C functions for FFI
- Pointer types (`*T`) are for FFI only -- not used in pure toke code
- `as` performs explicit type casts -- no implicit conversions exist
- `spawn(func)` starts concurrent tasks; `await(task)` retrieves their results
- `Task` is the type of a spawned computation
- `{arena ... }` creates a sub-arena for temporary allocations
- Arena-allocated values cannot escape their arena (compile-time check)

## Next

[Lesson 9: Standard Library Deep Dive](/learn/09-stdlib/) -- a tour of every standard library module.
