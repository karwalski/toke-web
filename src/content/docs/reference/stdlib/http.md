---
title: "std.http"
description: "HTTP server and response helpers -- declarative route registration and response constructors."
---

The `std.http` module provides a declarative HTTP server framework. Routes are registered using verb macros (`http.GET`, `http.POST`, etc.) that bind URL patterns to handler functions. Handlers receive a `Req` and return a `Res`. Response constructor functions simplify building common response shapes.

## Types

### Req

Represents an incoming HTTP request.

| Field | Type | Meaning |
|-------|------|---------|
| method | Str | HTTP method (e.g., `"GET"`, `"POST"`) |
| path | Str | Request path (e.g., `"/items/42"`) |
| headers | [[Str]] | Key-value pairs of request headers |
| body | Str | Request body (empty string if none) |
| params | [[Str]] | URL parameters extracted from the route pattern |

### Res

Represents an outgoing HTTP response.

| Field | Type | Meaning |
|-------|------|---------|
| status | u16 | HTTP status code |
| headers | [[Str]] | Key-value pairs of response headers |
| body | Str | Response body |

## Route Registration

Routes are registered using verb macros. Each takes a URL pattern string and a handler function. Patterns may include named parameters prefixed with `:` (e.g., `"/items/:id"`).

### http.GET(pattern: Str; handler: fn(Req): Res)

Registers a handler for GET requests matching `pattern`.

### http.POST(pattern: Str; handler: fn(Req): Res)

Registers a handler for POST requests matching `pattern`.

### http.PUT(pattern: Str; handler: fn(Req): Res)

Registers a handler for PUT requests matching `pattern`.

### http.DELETE(pattern: Str; handler: fn(Req): Res)

Registers a handler for DELETE requests matching `pattern`.

### http.PATCH(pattern: Str; handler: fn(Req): Res)

Registers a handler for PATCH requests matching `pattern`.

```toke
http.GET("/"; fn(req: Req): Res =
  http.Res.ok("hello world")
);

http.GET("/items/:id"; fn(req: Req): Res =
  let id = http.param(req; "id");
  http.Res.json(200; "{\"id\":" ++ id ++ "}")
);
```

## Accessor Functions

### http.param(req: Req; name: Str): Str!HttpErr

Extracts a named URL parameter from the request. Returns `HttpErr.NotFound` if the parameter does not exist.

```toke
let id = http.param(req; "id");  (* id = ok("42") *)
```

### http.header(req: Req; name: Str): Str!HttpErr

Extracts a header value by name (case-insensitive lookup). Returns `HttpErr.NotFound` if the header is not present.

```toke
let ct = http.header(req; "content-type");
(* ct = ok("application/json") *)
```

## Response Constructors

### http.Res.ok(body: Str): Res

Creates a 200 OK response with the given body.

```toke
let r = http.Res.ok("hello");
(* r.status = 200; r.body = "hello" *)
```

### http.Res.json(status: u16; body: Str): Res

Creates a response with the given status code and a JSON body. Sets the `Content-Type` header to `application/json`.

```toke
let r = http.Res.json(201; "{\"created\":true}");
(* r.status = 201 *)
```

### http.Res.bad(msg: Str): Res

Creates a 400 Bad Request response with the given message as the body.

```toke
let r = http.Res.bad("invalid input");
(* r.status = 400; r.body = "invalid input" *)
```

### http.Res.err(msg: Str): Res

Creates a 500 Internal Server Error response with the given message as the body.

```toke
let r = http.Res.err("something broke");
(* r.status = 500; r.body = "something broke" *)
```

## Usage Examples

```toke
(* A simple CRUD API *)
http.GET("/users/:id"; fn(req: Req): Res =
  let id = http.param(req; "id") |{ http.Res.bad("missing id") };
  let row = db.one("SELECT * FROM users WHERE id=?"; [id]);
  if row.ok? =
    let name = row.str(row!; "name") |{ "unknown" };
    http.Res.json(200; "{\"name\":\"" ++ name ++ "\"}")
  el =
    http.Res.json(404; "{\"error\":\"not found\"}")
);

http.POST("/users"; fn(req: Req): Res =
  let body = json.dec(req.body) |{ http.Res.bad("invalid json") };
  let name = json.str(body; "name") |{ http.Res.bad("missing name") };
  db.exec("INSERT INTO users(name) VALUES(?)"; [name]);
  http.Res.json(201; "{\"ok\":true}")
);
```

## Error Types

### HttpErr

A sum type representing HTTP operation failures.

| Variant | Field Type | Meaning |
|---------|------------|---------|
| BadRequest | Str | The request is malformed |
| NotFound | Str | The requested parameter or header was not found |
| Internal | Str | An internal server error occurred |
| Timeout | u32 | The operation timed out (value is timeout in milliseconds) |
