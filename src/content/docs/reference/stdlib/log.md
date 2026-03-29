---
title: std.log
description: Structured logging — emit log messages at different severity levels.
---

The `std.log` module provides structured logging functions at multiple severity levels. Log output is written to stderr in a structured format.

## Import

```toke
I=log:std.log;
```

## Functions

### log.debug

Emits a debug-level log message.

```toke
F=debug(msg: Str): void;
```

**Parameters:**

| Name  | Type  | Description          |
|-------|-------|----------------------|
| `msg` | `Str` | The message to log   |

**Returns:** `void`

**Example:**

```toke
log.debug("entering request handler");
```

---

### log.info

Emits an info-level log message.

```toke
F=info(msg: Str): void;
```

**Parameters:**

| Name  | Type  | Description          |
|-------|-------|----------------------|
| `msg` | `Str` | The message to log   |

**Returns:** `void`

**Example:**

```toke
log.info("server started on port 8080");
```

---

### log.warn

Emits a warning-level log message.

```toke
F=warn(msg: Str): void;
```

**Parameters:**

| Name  | Type  | Description          |
|-------|-------|----------------------|
| `msg` | `Str` | The message to log   |

**Returns:** `void`

**Example:**

```toke
log.warn("connection pool running low");
```

---

### log.error

Emits an error-level log message.

```toke
F=error(msg: Str): void;
```

**Parameters:**

| Name  | Type  | Description          |
|-------|-------|----------------------|
| `msg` | `Str` | The message to log   |

**Returns:** `void`

**Example:**

```toke
log.error("failed to connect to database");
```

---

### log.with_field

Emits a log message with a key-value field attached.

```toke
F=with_field(level: Str; msg: Str; key: Str; value: Str): void;
```

**Parameters:**

| Name    | Type  | Description                                        |
|---------|-------|----------------------------------------------------|
| `level` | `Str` | Log level (`"debug"`, `"info"`, `"warn"`, `"error"`) |
| `msg`   | `Str` | The message to log                                 |
| `key`   | `Str` | The field name                                     |
| `value` | `Str` | The field value                                    |

**Returns:** `void`

**Example:**

```toke
log.with_field("info", "request handled", "status", "200");
```

---

### log.set_level

Sets the minimum log level. Messages below this level are suppressed.

```toke
F=set_level(level: Str): void;
```

**Parameters:**

| Name    | Type  | Description                                          |
|---------|-------|------------------------------------------------------|
| `level` | `Str` | Minimum level: `"debug"`, `"info"`, `"warn"`, `"error"` |

**Returns:** `void`

**Example:**

```toke
log.set_level("warn");  // only warn and error messages will appear
```
