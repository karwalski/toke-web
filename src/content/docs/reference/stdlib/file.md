---
title: "std.file"
description: "File system operations -- read, write, append, delete, and list files and directories."
---

**Status: Implemented** -- C runtime backing, available in Phase 2.

The `std.file` module provides functions for reading, writing, and managing files on the local file system. All paths are UTF-8 strings. Operations that can fail return a result type with `FileErr`.

## Functions

### file.read(path: $str): $str!$fileerr

Reads the entire contents of the file at `path` and returns it as a string. Returns `$fileerr.$notfound` if the file does not exist, `$fileerr.$permission` if access is denied, or `$fileerr.$io` on other I/O failures.

```toke
let content = file.read("/tmp/data.txt");
(* content = ok("hello world") *)
```

### file.write(path: $str; content: $str): bool!$fileerr

Writes `content` to the file at `path`, creating the file if it does not exist and truncating it if it does. Returns `true` on success.

```toke
let ok = file.write("/tmp/data.txt"; "hello world");
(* ok = ok(true) *)
```

### file.append(path: $str; content: $str): bool!$fileerr

Appends `content` to the end of the file at `path`, creating the file if it does not exist. Returns `true` on success.

```toke
file.write("/tmp/log.txt"; "line 1\n");
file.append("/tmp/log.txt"; "line 2\n");
let content = file.read("/tmp/log.txt");
(* content = ok("line 1\nline 2\n") *)
```

### file.exists(path: $str): bool

Returns `true` if a file exists at `path`, `false` otherwise. This function is infallible.

```toke
let y = file.exists("/tmp/data.txt");  (* y = true *)
let n = file.exists("/tmp/nope.txt");  (* n = false *)
```

### file.delete(path: $str): bool!$fileerr

Deletes the file at `path`. Returns `true` on success. Returns `$fileerr` if the file cannot be deleted.

```toke
file.write("/tmp/temp.txt"; "data");
let ok = file.delete("/tmp/temp.txt");
(* ok = ok(true) *)
```

### file.list(dir: $str): @($str)!$fileerr

Returns an array of filenames in the directory `dir`. Returns `$fileerr.$notfound` if the directory does not exist.

```toke
let entries = file.list("/tmp");
(* entries = ok(@("file1.txt"; "file2.txt"; ...)) *)
```

## Usage Examples

```toke
(* Read a config file with fallback *)
let cfg = file.read("/etc/app.conf") |{ "default=true" };

(* Write only if file does not exist *)
if file.exists("/tmp/lock") =
  log.warn("lock file exists"; @())
el =
  file.write("/tmp/lock"; "locked");

(* List and process files *)
let files = file.list("/tmp/data") |{ @() };
```

## Error Types

### $fileerr

A sum type representing file operation failures.

| Variant | Field Type | Meaning |
|---------|------------|---------|
| $notfound | $str | The file or directory does not exist |
| $permission | $str | The process lacks permission to perform the operation |
| $io | $str | A general I/O error occurred |
