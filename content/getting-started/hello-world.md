---
title: Hello World
slug: hello-world
section: getting-started
order: 1
description: Write, compile, and run your first toke program.
---

## The program

Create a file called `hello.tk`:

```
m=hello;
i=io:std.io;

f=main():i64{
  io.println("Hello, world!");
  <0;
};
```

Every toke file begins with a module declaration (`m=`). Imports use `i=alias:module.path;`. Functions are declared with `f=`. The `<` operator returns a value.

## Compile and run

```bash
./build/tkc hello.tk -o hello
./hello
```

Output:
```
Hello, world!
```

## Next: Fibonacci

```
m=fib;

f=fib(n:i64):i64{
  if(n<2){<n;};
  <fib(n-1)+fib(n-2);
};

f=main():i64{
  <fib(10);
};
```

Run: `./fib; echo $?` → `55`
