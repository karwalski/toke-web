---
title: std.str
description: String operations — concatenation, searching, splitting, and transformation functions.
---

The `std.str` module provides functions for working with immutable `Str` values. Since toke strings are immutable, all operations return new strings rather than modifying in place.

## Import

```toke
I=str:std.str;
```

## Functions

### str.concat

Concatenates two strings.

```toke
F=concat(a: Str; b: Str): Str;
```

**Parameters:**

| Name | Type  | Description         |
|------|-------|---------------------|
| `a`  | `Str` | The first string    |
| `b`  | `Str` | The second string   |

**Returns:** `Str` — a new string containing `a` followed by `b`.

**Example:**

```toke
let greeting = str.concat("hello, ", "world");
// greeting = "hello, world"
```

---

### str.len

Returns the byte length of a string.

```toke
F=len(s: Str): u64;
```

**Parameters:**

| Name | Type  | Description      |
|------|-------|------------------|
| `s`  | `Str` | The input string |

**Returns:** `u64` — the number of bytes in the string.

**Example:**

```toke
let n = str.len("hello");
// n = 5
```

---

### str.contains

Tests whether a string contains a substring.

```toke
F=contains(haystack: Str; needle: Str): bool;
```

**Parameters:**

| Name       | Type  | Description              |
|------------|-------|--------------------------|
| `haystack` | `Str` | The string to search in  |
| `needle`   | `Str` | The substring to find    |

**Returns:** `bool` — `true` if `needle` is found within `haystack`.

**Example:**

```toke
let found = str.contains("hello world", "world");
// found = true
```

---

### str.starts_with

Tests whether a string starts with a prefix.

```toke
F=starts_with(s: Str; prefix: Str): bool;
```

**Parameters:**

| Name     | Type  | Description          |
|----------|-------|----------------------|
| `s`      | `Str` | The string to check  |
| `prefix` | `Str` | The prefix to test   |

**Returns:** `bool` — `true` if `s` begins with `prefix`.

**Example:**

```toke
let yes = str.starts_with("/api/users", "/api");
// yes = true
```

---

### str.ends_with

Tests whether a string ends with a suffix.

```toke
F=ends_with(s: Str; suffix: Str): bool;
```

**Parameters:**

| Name     | Type  | Description          |
|----------|-------|----------------------|
| `s`      | `Str` | The string to check  |
| `suffix` | `Str` | The suffix to test   |

**Returns:** `bool` — `true` if `s` ends with `suffix`.

**Example:**

```toke
let yes = str.ends_with("file.toke", ".toke");
// yes = true
```

---

### str.split

Splits a string by a delimiter into an array of substrings.

```toke
F=split(s: Str; delim: Str): [Str];
```

**Parameters:**

| Name    | Type  | Description           |
|---------|-------|-----------------------|
| `s`     | `Str` | The string to split   |
| `delim` | `Str` | The delimiter string  |

**Returns:** `[Str]` — an array of substrings.

**Example:**

```toke
let parts = str.split("a,b,c", ",");
// parts = ["a"; "b"; "c"]
```

---

### str.trim

Removes leading and trailing whitespace from a string.

```toke
F=trim(s: Str): Str;
```

**Parameters:**

| Name | Type  | Description            |
|------|-------|------------------------|
| `s`  | `Str` | The string to trim     |

**Returns:** `Str` — the trimmed string.

**Example:**

```toke
let clean = str.trim("  hello  ");
// clean = "hello"
```

---

### str.to_upper

Converts a string to uppercase.

```toke
F=to_upper(s: Str): Str;
```

**Parameters:**

| Name | Type  | Description              |
|------|-------|--------------------------|
| `s`  | `Str` | The string to convert    |

**Returns:** `Str` — the uppercase string.

---

### str.to_lower

Converts a string to lowercase.

```toke
F=to_lower(s: Str): Str;
```

**Parameters:**

| Name | Type  | Description              |
|------|-------|--------------------------|
| `s`  | `Str` | The string to convert    |

**Returns:** `Str` — the lowercase string.

---

### str.replace

Replaces all occurrences of a substring.

```toke
F=replace(s: Str; old: Str; new: Str): Str;
```

**Parameters:**

| Name  | Type  | Description                 |
|-------|-------|-----------------------------|
| `s`   | `Str` | The input string            |
| `old` | `Str` | The substring to replace    |
| `new` | `Str` | The replacement string      |

**Returns:** `Str` — a new string with all occurrences replaced.

**Example:**

```toke
let result = str.replace("foo bar foo", "foo", "baz");
// result = "baz bar baz"
```

---

### str.substr

Extracts a substring by byte offset and length.

```toke
F=substr(s: Str; start: u64; length: u64): Str;
```

**Parameters:**

| Name     | Type  | Description                    |
|----------|-------|--------------------------------|
| `s`      | `Str` | The input string               |
| `start`  | `u64` | Starting byte offset (0-based) |
| `length` | `u64` | Number of bytes to extract     |

**Returns:** `Str` — the extracted substring.

**Example:**

```toke
let sub = str.substr("hello world", 6 as u64, 5 as u64);
// sub = "world"
```

---

### str.index_of

Finds the byte offset of the first occurrence of a substring.

```toke
F=index_of(haystack: Str; needle: Str): i64;
```

**Parameters:**

| Name       | Type  | Description              |
|------------|-------|--------------------------|
| `haystack` | `Str` | The string to search in  |
| `needle`   | `Str` | The substring to find    |

**Returns:** `i64` — the byte offset of the first occurrence, or `-1` if not found.

**Example:**

```toke
let pos = str.index_of("hello world", "world");
// pos = 6
```
