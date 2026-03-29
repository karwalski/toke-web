---
title: std.process
description: Process management — execute external commands, exit the program, and access command-line arguments.
---

The `std.process` module provides functions for running external processes, exiting the current program, and reading command-line arguments.

## Import

```toke
I=proc:std.process;
```

## Functions

### process.exec

Executes an external command and returns its stdout output.

```toke
F=exec(cmd: Str): Str!Err;
```

**Parameters:**

| Name  | Type  | Description                        |
|-------|-------|------------------------------------|
| `cmd` | `Str` | The command string to execute      |

**Returns:** `Str!Err` — the command's stdout output, or an error if execution fails.

**Errors:** Returns an error if the command cannot be found, cannot be executed, or exits with a non-zero status.

**Example:**

```toke
let output = proc.exec("ls -la")!;
```

---

### process.exec_status

Executes an external command and returns its exit code.

```toke
F=exec_status(cmd: Str): i64!Err;
```

**Parameters:**

| Name  | Type  | Description                        |
|-------|-------|------------------------------------|
| `cmd` | `Str` | The command string to execute      |

**Returns:** `i64!Err` — the exit code, or an error if the command cannot be started.

**Errors:** Returns an error if the command cannot be found or cannot be executed.

---

### process.exit

Terminates the current process with the given exit code.

```toke
F=exit(code: i64): void;
```

**Parameters:**

| Name   | Type  | Description    |
|--------|-------|----------------|
| `code` | `i64` | Exit code      |

**Returns:** Does not return.

**Example:**

```toke
proc.exit(1);
```

---

### process.args

Returns the command-line arguments as an array of strings.

```toke
F=args(): [Str];
```

**Returns:** `[Str]` — array of command-line arguments. The first element is the program name.

**Example:**

```toke
let argv = proc.args();
```

---

### process.pid

Returns the process ID of the current process.

```toke
F=pid(): i64;
```

**Returns:** `i64` — the current process ID.
