---
title: std.json
description: JSON parsing and serialization — encode and decode toke values to and from JSON strings.
---

The `std.json` module provides functions for encoding toke values to JSON strings and decoding JSON strings back into toke values.

## Import

```toke
I=json:std.json;
```

## Functions

### json.encode

Serializes a value to a JSON string.

```toke
F=encode(value: Str): Str;
```

**Parameters:**

| Name    | Type  | Description                   |
|---------|-------|-------------------------------|
| `value` | `Str` | The value to encode as JSON   |

**Returns:** `Str` — the JSON-encoded string.

**Example:**

```toke
let j = json.encode("hello");
// j = "\"hello\""
```

---

### json.encode_i64

Serializes an integer to a JSON number string.

```toke
F=encode_i64(value: i64): Str;
```

**Parameters:**

| Name    | Type  | Description           |
|---------|-------|-----------------------|
| `value` | `i64` | The integer to encode |

**Returns:** `Str` — the JSON number string.

**Example:**

```toke
let j = json.encode_i64(42);
// j = "42"
```

---

### json.encode_f64

Serializes a float to a JSON number string.

```toke
F=encode_f64(value: f64): Str;
```

**Parameters:**

| Name    | Type  | Description         |
|---------|-------|---------------------|
| `value` | `f64` | The float to encode |

**Returns:** `Str` — the JSON number string.

---

### json.encode_bool

Serializes a boolean to a JSON boolean string.

```toke
F=encode_bool(value: bool): Str;
```

**Parameters:**

| Name    | Type   | Description           |
|---------|--------|-----------------------|
| `value` | `bool` | The boolean to encode |

**Returns:** `Str` — `"true"` or `"false"`.

---

### json.decode_str

Parses a JSON string value.

```toke
F=decode_str(input: Str): Str!Err;
```

**Parameters:**

| Name    | Type  | Description           |
|---------|-------|-----------------------|
| `input` | `Str` | The JSON string to parse |

**Returns:** `Str!Err` — the decoded string value, or an error if the input is not valid JSON.

**Errors:** Returns an error if the input is not a valid JSON string.

**Example:**

```toke
let name = json.decode_str("\"alice\"")!;
// name = "alice"
```

---

### json.decode_i64

Parses a JSON number as an integer.

```toke
F=decode_i64(input: Str): i64!Err;
```

**Parameters:**

| Name    | Type  | Description              |
|---------|-------|--------------------------|
| `input` | `Str` | The JSON number to parse |

**Returns:** `i64!Err` — the decoded integer, or an error if the input is not a valid JSON integer.

**Errors:** Returns an error if the input is not a valid JSON number or cannot be represented as `i64`.

---

### json.decode_f64

Parses a JSON number as a float.

```toke
F=decode_f64(input: Str): f64!Err;
```

**Parameters:**

| Name    | Type  | Description              |
|---------|-------|--------------------------|
| `input` | `Str` | The JSON number to parse |

**Returns:** `f64!Err` — the decoded float, or an error if the input is not a valid JSON number.

---

### json.decode_bool

Parses a JSON boolean.

```toke
F=decode_bool(input: Str): bool!Err;
```

**Parameters:**

| Name    | Type  | Description                |
|---------|-------|----------------------------|
| `input` | `Str` | The JSON boolean to parse  |

**Returns:** `bool!Err` — the decoded boolean, or an error if the input is not `"true"` or `"false"`.
