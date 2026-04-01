---
title: "Lesson 1: Why toke?"
description: "Understand the problem toke solves — token-efficient code generation for LLMs — and where it fits in the ecosystem."
---

**Estimated time: ~20 minutes**

## The LLM code generation problem

Large language models generate code one token at a time. Every token costs compute, time, and money. When an LLM writes a Python function, most of those tokens are spent on syntactic boilerplate -- keywords like `def`, `return`, `import`, whitespace indentation, colons, and decorators. The actual logic is a fraction of the output.

This is not a problem with LLMs. It is a problem with the languages they are asked to generate.

## Token count: a concrete example

Consider a function that computes the nth Fibonacci number. Here it is in Python:

```python
def fib(n: int) -> int:
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)
```

Under the `cl100k_base` tokenizer (used by GPT-4 and similar models), this is approximately **156 tokens**.

Here is the same function in toke:

```
M=fib;
F=fib(n:i64):i64{
  if(n<2){<n};
  <fib(n-1)+fib(n-2);
};
```

This is approximately **47 tokens** under the same tokenizer. That is a **3.3x reduction**.

The savings come from:

- **`F=` instead of `def`** -- single-character keyword
- **`<` instead of `return`** -- one character, not six
- **`if(cond){body}` instead of `if cond:\n    body`** -- no indentation tokens, no colon
- **`i64` instead of `int`** -- explicit width, same token count
- **`;` terminates everything** -- no whitespace-as-syntax
- **No blank lines, no docstring boilerplate** -- every token carries semantics

## Why does this matter?

Three reasons:

### 1. Cost

LLM API pricing is per-token. If the same program uses 3x fewer tokens, it costs 3x less to generate. At scale -- thousands of generation calls per day -- this adds up fast.

### 2. Speed

Fewer output tokens means faster generation. An LLM generating 47 tokens finishes roughly 3x faster than one generating 156 tokens, assuming similar per-token latency.

### 3. Reliability

Shorter programs have fewer opportunities for the model to make mistakes. A 50-token program has less surface area for hallucination than a 150-token program. Additionally, toke's LL(1) grammar and structured diagnostics mean the compiler can give the LLM precise, machine-readable feedback when something goes wrong -- enabling automated repair loops.

## More comparisons

Here is a function that sums an array of integers:

**Go (approx. 89 tokens):**
```go
func sum(arr []int) int {
    total := 0
    for i := 0; i < len(arr); i++ {
        total += arr[i]
    }
    return total
}
```

**toke (approx. 38 tokens):**
```
F=sum(arr:@(i64)):i64{
  let acc=mut.0;
  lp(let i=0;i<arr.len;i=i+1){
    acc=acc+arr.get(i);
  };
  <acc;
};
```

And an HTTP handler:

**Python Flask (approx. 210 tokens):**
```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route("/user/<int:id>", methods=["GET"])
def get_user(id):
    user = db.get_user(id)
    if user is None:
        return jsonify({"error": "not found"}), 404
    return jsonify(user.to_dict())
```

**toke (approx. 65 tokens):**
```
M=api.user;
I=http:std.http;
I=db:std.db;
I=json:std.json;

F=getUser(req:http.$req):http.$res!$apierr{
  let id=req.param("id") as u64;
  let user=db.one("SELECT * FROM users WHERE id=?";@(id))!$apierr;
  <http.$res.ok(json.enc(user));
};
```

## toke's place in the ecosystem

toke is not a replacement for Python, Go, Rust, or any other language. It occupies a specific niche:

**toke is a compilation target for LLM code generation.**

The workflow looks like this:

1. An LLM receives a task description
2. It generates toke source code (fewer tokens, faster, cheaper)
3. The `tkc` compiler compiles it to a native binary
4. If compilation fails, structured diagnostics are fed back to the LLM
5. The LLM repairs and resubmits (the "repair loop")

Humans can read and write toke -- it is designed to be learnable -- but its primary optimisation target is machine generation. This is what makes it different from every other language.

## The design constraints

toke achieves token efficiency through deliberate constraints:

- **56-character set** -- lowercase letters, digits, and 18 symbols. No uppercase, no `#`, `%`, `^`, `&`, `~`
- **12 keywords** -- `F`, `T`, `I`, `M`, `if`, `el`, `lp`, `br`, `let`, `mut`, `as`, `rt`
- **One way to do everything** -- no synonym constructs, no optional syntax
- **LL(1) grammar** -- deterministic parsing with one token of lookahead
- **Semicolons terminate everything** -- no whitespace-as-syntax
- **No comments in source** -- metadata lives outside the source file
- **Explicit types everywhere** -- no type inference in v0.1

These constraints make toke predictable, parseable, and compact.

## Exercise

Take this Python function:

```python
def max_of_three(a: int, b: int, c: int) -> int:
    if a >= b and a >= c:
        return a
    elif b >= c:
        return b
    return c
```

1. Count the approximate tokens (you can use OpenAI's tokenizer tool or estimate: roughly 1 token per word/symbol/number)
2. Rewrite it in toke using what you know so far (`F=`, `if`, `el`, `<`)
3. Count the toke tokens and compare

Do not worry about getting the syntax perfectly right yet -- the next lesson covers it in detail. The goal is to build intuition for where the savings come from.

## Key takeaways

- LLMs pay per token. Verbose languages waste tokens on syntax, not logic.
- toke achieves 3-5x token reduction through deliberate syntactic compression.
- toke is a compilation target for LLM workflows, not a general-purpose replacement.
- Fewer tokens means lower cost, faster generation, and fewer errors.
- The language has 12 keywords, 56 characters, and one canonical form for every construct.

## Next

[Lesson 2: Modules and Functions](/learn/02-modules-functions/) -- write your first toke programs.
