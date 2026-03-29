---
title: std.file
description: File I/O — read, write, append, and manage files on the filesystem.
---

The `std.file` module provides functions for reading and writing files. All file operations return error unions to handle I/O failures.

## Import

```toke
I=file:std.file;
```

## Functions

### file.read

Reads the entire contents of a file as a string.

```toke
F=read(path: Str): Str!Err;
```

**Parameters:**

| Name   | Type  | Description          |
|--------|-------|----------------------|
| `path` | `Str` | Path to the file     |

**Returns:** `Str!Err` — the file contents, or an error if the file cannot be read.

**Errors:** Returns an error if the file does not exist, is not readable, or an I/O error occurs.

**Example:**

```toke
let content = file.read("config.txt")!;
```

---

### file.write

Writes a string to a file, creating it if it does not exist or truncating it if it does.

```toke
F=write(path: Str; content: Str): void!Err;
```

**Parameters:**

| Name      | Type  | Description           |
|-----------|-------|-----------------------|
| `path`    | `Str` | Path to the file      |
| `content` | `Str` | Content to write      |

**Returns:** `void!Err` — void on success, or an error if the write fails.

**Errors:** Returns an error if the file cannot be opened for writing or an I/O error occurs.

**Example:**

```toke
file.write("output.txt", "hello world")!;
```

---

### file.append

Appends a string to the end of a file, creating it if it does not exist.

```toke
F=append(path: Str; content: Str): void!Err;
```

**Parameters:**

| Name      | Type  | Description           |
|-----------|-------|-----------------------|
| `path`    | `Str` | Path to the file      |
| `content` | `Str` | Content to append     |

**Returns:** `void!Err` — void on success, or an error if the append fails.

**Errors:** Returns an error if the file cannot be opened for appending or an I/O error occurs.

---

### file.exists

Checks whether a file exists at the given path.

```toke
F=exists(path: Str): bool;
```

**Parameters:**

| Name   | Type  | Description      |
|--------|-------|------------------|
| `path` | `Str` | Path to check    |

**Returns:** `bool` — `true` if the file exists.

**Example:**

```toke
?(file.exists("config.txt")) {
    let cfg = file.read("config.txt")!
} : {
    file.write("config.txt", "defaults")!
};
```

---

### file.remove

Deletes a file from the filesystem.

```toke
F=remove(path: Str): void!Err;
```

**Parameters:**

| Name   | Type  | Description          |
|--------|-------|----------------------|
| `path` | `Str` | Path to the file     |

**Returns:** `void!Err` — void on success, or an error if the file cannot be deleted.

**Errors:** Returns an error if the file does not exist or cannot be removed.

---

### file.read_lines

Reads a file and returns its contents as an array of lines.

```toke
F=read_lines(path: Str): [Str]!Err;
```

**Parameters:**

| Name   | Type  | Description          |
|--------|-------|----------------------|
| `path` | `Str` | Path to the file     |

**Returns:** `[Str]!Err` — an array of lines, or an error if the file cannot be read.

**Example:**

```toke
let lines = file.read_lines("data.csv")!;
```
