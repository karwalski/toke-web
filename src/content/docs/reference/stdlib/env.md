---
title: std.env
description: Environment variables — read and write environment variables.
---

The `std.env` module provides functions for reading and setting environment variables.

## Import

```toke
I=env:std.env;
```

## Functions

### env.get

Reads the value of an environment variable.

```toke
F=get(key: Str): Str!Err;
```

**Parameters:**

| Name  | Type  | Description                    |
|-------|-------|--------------------------------|
| `key` | `Str` | The environment variable name  |

**Returns:** `Str!Err` — the value of the environment variable, or an error if it is not set.

**Errors:** Returns an error if the environment variable is not defined.

**Example:**

```toke
let home = env.get("HOME")!;
```

---

### env.set

Sets the value of an environment variable for the current process.

```toke
F=set(key: Str; value: Str): void;
```

**Parameters:**

| Name    | Type  | Description                    |
|---------|-------|--------------------------------|
| `key`   | `Str` | The environment variable name  |
| `value` | `Str` | The value to set               |

**Returns:** `void`

**Example:**

```toke
env.set("APP_MODE", "production");
```

---

### env.has

Tests whether an environment variable is set.

```toke
F=has(key: Str): bool;
```

**Parameters:**

| Name  | Type  | Description                    |
|-------|-------|--------------------------------|
| `key` | `Str` | The environment variable name  |

**Returns:** `bool` — `true` if the variable is set.

**Example:**

```toke
?(env.has("DEBUG")) {
    log.info("debug mode enabled")
};
```

---

### env.get_or

Reads the value of an environment variable, returning a default if not set.

```toke
F=get_or(key: Str; default: Str): Str;
```

**Parameters:**

| Name      | Type  | Description                    |
|-----------|-------|--------------------------------|
| `key`     | `Str` | The environment variable name  |
| `default` | `Str` | The fallback value             |

**Returns:** `Str` — the environment variable value, or `default` if not set.

**Example:**

```toke
let port = env.get_or("PORT", "8080");
```
