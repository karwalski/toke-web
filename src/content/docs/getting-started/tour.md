---
title: Language Tour
description: A quick tour of all major toke language features with examples.
---

This tour covers every major feature of the toke language. Each section includes a short explanation and a working code example.

## Modules and functions

Every toke file begins with a module declaration. Functions are declared with `F=`.

```
M=math;

F=square(x:i64):i64{
  <x*x;
};

F=main():i64{
  <square(7);
};
```

Functions explicitly declare parameter types and return types. There are no optional parameters, no overloading, and no default values. Every function has exactly one signature.

## Types

toke has a small set of built-in types:

| Type | Description |
|------|-------------|
| `i8`, `i16`, `i32`, `i64` | Signed integers |
| `u8`, `u16`, `u32`, `u64` | Unsigned integers |
| `f32`, `f64` | IEEE 754 floating point |
| `bool` | Boolean (`true` or `false`) |
| `Str` | UTF-8 string |
| `void` | No value (for functions with no meaningful return) |

You can also define struct types with `T=`:

```
T=Point{x:f64;y:f64};
```

And sum types (tagged unions) for error variants and enumerations:

```
T=Shape{
  Circle:f64;
  Rect:Point
};
```

## Let bindings and mutability

Use `let` for immutable bindings and `let x=mut.` for mutable ones:

```
F=example():i64{
  let x=10;
  let y=mut.20;
  y=y+x;
  <y;
};
```

Immutable bindings cannot be reassigned. Attempting to write `x=5;` after a `let` binding is a compile error.

## If / else

Conditionals use `if()` and `el{}`:

```
F=abs(n:i64):i64{
  if(n<0){
    <0-n;
  }el{
    <n;
  };
};
```

The condition goes inside parentheses after `if`. The else branch `el{...}` is optional. You can also write single-line conditionals:

```
F=max(a:i64;b:i64):i64{
  if(a>b){<a;}el{<b;};
};
```

For chained conditions, nest inside the else branch:

```
F=classify(n:i64):Str{
  if(n<0){
    <"negative";
  }el{
    if(n=0){
      <"zero";
    }el{
      <"positive";
    };
  };
};
```

## Loops

toke has exactly one loop construct: `lp`. It takes an initialiser, a condition, and a step:

```
F=sum_to(n:i64):i64{
  let total=mut.0;
  lp(i=0;i<n;i=i+1){
    total=total+i;
  };
  <total;
};
```

Use `br;` to break out of a loop early:

```
F=find_first_negative(arr:[i64]):i64{
  let result=mut.0-1;
  lp(i=0;i<arr.len;i=i+1){
    if(arr[i]<0){
      result=i;
      br;
    };
  };
  <result;
};
```

There is no `while`, `for-each`, or `do-while`. The `lp` construct covers all looping patterns.

## Match expressions

The `|{}` operator is used for pattern matching on sum types and error results:

```
T=Color{
  Red:bool;
  Green:bool;
  Blue:bool;
  Custom:Str
};

F=to_hex(c:Color):Str{
  c|{
    Red:r <"#FF0000";
    Green:g <"#00FF00";
    Blue:b <"#0000FF";
    Custom:s <s
  };
};
```

Match is exhaustive -- the compiler rejects any match that does not cover all variants. When you add a new variant to a type, every match on that type must be updated or the program will not compile.

## Arrays and maps

Arrays use square brackets with semicolons as separators:

```
F=example():[i64]{
  let nums=[1;2;3;4;5];
  <nums;
};
```

Maps use key-value pairs:

```
F=example():[Str:i64]{
  let ages=["alice":30;"bob":25;"carol":28];
  <ages;
};
```

Access array elements by index and map elements by key:

```
F=example():i64{
  let nums=[10;20;30];
  let first=nums[0];
  <first;
};
```

Array types are written as `[ElementType]` and map types as `[KeyType:ValueType]`.

## Error handling

Functions that can fail declare an error type after `!`:

```
T=FileErr{
  NotFound:Str;
  PermDenied:Str
};

F=read_file(path:Str):Str!FileErr{
  let f=io.open(path)!FileErr.NotFound;
  let content=io.read_all(f)!FileErr.PermDenied;
  <content;
};
```

The `!` operator after a call propagates errors. If the call returns an error, the current function immediately returns that error wrapped in the specified variant. If the call succeeds, execution continues with the unwrapped value.

Use `|{}` to match on the result and handle each case:

```
F=main():i64{
  let result=read_file("config.tk");
  result|{
    Ok:content io.println(content);
    Err:e io.println("Failed to read file")
  };
  <0;
};
```

Error handling is explicit and checked by the compiler. You cannot ignore an error from a fallible function -- you must either propagate it with `!` or handle it with `|{}`.

## Imports

Import other modules with `I=`:

```
M=app;
I=io:std.io;
I=json:std.json;
I=http:std.http;

F=main():i64{
  io.println(json.enc("hello"));
  <0;
};
```

The alias before the colon is how you refer to the module in code. The path after the colon is the fully qualified module name. All imports must appear before any type or function declarations.

## Putting it together

Here is a complete program that reads numbers from the command line and prints their sum:

```
M=sum;
I=io:std.io;

F=sum(arr:[i64]):i64{
  let total=mut.0;
  lp(i=0;i<arr.len;i=i+1){
    total=total+arr[i];
  };
  <total;
};

F=main():i64{
  let args=io.args();
  let result=sum(args);
  io.println("Sum: \(result)");
  <0;
};
```

## Next steps

Learn how to organise multi-file projects in [Project Structure](/getting-started/project-structure/).
