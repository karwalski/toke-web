---
title: std.http
description: HTTP server — create HTTP servers, define routes, and handle requests.
---

The `std.http` module provides functions for building HTTP servers and handling requests.

## Import

```toke
I=http:std.http;
```

## Functions

### http.listen

Starts an HTTP server listening on the specified port.

```toke
F=listen(port: i64): void!Err;
```

**Parameters:**

| Name   | Type  | Description                 |
|--------|-------|-----------------------------|
| `port` | `i64` | The port number to bind to  |

**Returns:** `void!Err` — blocks while serving; returns an error if the server cannot start.

**Errors:** Returns an error if the port is already in use or cannot be bound.

**Example:**

```toke
http.listen(8080)!;
```

---

### http.route

Registers a handler function for an HTTP route.

```toke
F=route(method: Str; path: Str; handler: func): void;
```

**Parameters:**

| Name      | Type   | Description                              |
|-----------|--------|------------------------------------------|
| `method`  | `Str`  | HTTP method (`"GET"`, `"POST"`, etc.)    |
| `path`    | `Str`  | URL path pattern                         |
| `handler` | `func` | Handler function to call for this route  |

**Returns:** `void`

**Example:**

```toke
F=handle_index(): Str {
    < "hello from toke"
};

http.route("GET", "/", handle_index);
http.listen(8080)!;
```

---

### http.status

Sets the HTTP response status code for the current request.

```toke
F=status(code: i64): void;
```

**Parameters:**

| Name   | Type  | Description           |
|--------|-------|-----------------------|
| `code` | `i64` | HTTP status code      |

**Returns:** `void`

---

### http.header

Sets an HTTP response header for the current request.

```toke
F=header(key: Str; value: Str): void;
```

**Parameters:**

| Name    | Type  | Description        |
|---------|-------|--------------------|
| `key`   | `Str` | Header name        |
| `value` | `Str` | Header value       |

**Returns:** `void`

**Example:**

```toke
http.header("Content-Type", "application/json");
```

---

### http.body

Returns the request body as a string.

```toke
F=body(): Str;
```

**Returns:** `Str` — the raw request body.

---

### http.method

Returns the HTTP method of the current request.

```toke
F=method(): Str;
```

**Returns:** `Str` — the HTTP method (e.g., `"GET"`, `"POST"`).

---

### http.path

Returns the path of the current request.

```toke
F=path(): Str;
```

**Returns:** `Str` — the request path.
