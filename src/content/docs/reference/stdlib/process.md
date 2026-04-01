---
title: "std.process"
description: "Process management -- spawn child processes, read output, wait for completion, and send signals."
---

**Status: Implemented** -- C runtime backing, available in Phase 2.

The `std.process` module provides functions for spawning child processes, reading their output, waiting for completion, and sending signals. Process handles are opaque values obtained from `process.spawn`.

## Types

### $handle

An opaque handle representing a running child process. Obtained from `process.spawn` and passed to `process.wait`, `process.stdout`, and `process.kill`.

## Functions

### process.spawn(cmd: @($str)): $handle!$processerr

Spawns a child process. The first element of `cmd` is the executable path or name; subsequent elements are arguments. Returns a `$handle` on success, or `$processerr.$notfound` if the executable cannot be found, `$processerr.$permission` if execution is denied.

```toke
let h = process.spawn(@("echo"; "hello toke"));
(* h = ok($handle{...}) *)

let e = process.spawn(@("/nonexistentbinary"));
(* e = err($processerr.$notfound{...}) *)
```

### process.wait(h: $handle): i32!$processerr

Blocks until the child process exits and returns its exit code. Safe to call multiple times on the same handle (returns the cached exit code on subsequent calls). Returns `$processerr.$io` if waiting fails.

```toke
let code = process.wait(h);  (* code = ok(0) *)
```

### process.stdout(h: $handle): $str!$processerr

Reads all stdout output from the child process. Drains the pipe on the first call; subsequent calls return an empty string. Returns `$processerr.$io` if the read fails.

```toke
let h = process.spawn(@("echo"; "hello toke"));
let out = process.stdout(h);  (* out = ok("hello toke\n") *)
```

### process.kill(h: $handle): bool

Sends SIGTERM to the child process. Returns `true` if the signal was sent successfully, `false` if the process could not be signalled (e.g., already exited or null handle). This function is infallible.

```toke
let h = process.spawn(@("sleep"; "60"));
let ok = process.kill(h);   (* ok = true *)
process.wait(h);             (* reap the process *)
```

## Usage Examples

```toke
(* Run a command and capture its output *)
let h = process.spawn(@("ls"; "-la"; "/tmp")) |{
  log.error("failed to spawn ls"; @());
};
let output = process.stdout(h) |{ "" };
let code = process.wait(h) |{ -1 };

if code == 0 =
  log.info("ls succeeded"; @(@("output"; output)))
el =
  log.error("ls failed"; @(@("code"; str.fromInt(code))));
```

## Error Types

### $processerr

A sum type representing process operation failures.

| Variant | Meaning |
|---------|---------|
| $notfound | The executable was not found |
| $permission | Permission denied when attempting to execute |
| $io | An I/O error occurred during pipe read, write, or wait |
