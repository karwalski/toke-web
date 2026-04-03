---
title: "std.http"
description: "HTTP server and response helpers -- declarative route registration and response constructors."
---

**Status: Implemented** -- C runtime backing.

The `std.http` module provides a declarative HTTP server framework. Routes are registered using verb macros (`http.GET`, `http.POST`, etc.) that bind URL patterns to handler functions. Handlers receive a `$req` and return a `$res`. Response constructor functions simplify building common response shapes.

## Types

### $req

Represents an incoming HTTP request.

| Field | Type | Meaning |
|-------|------|---------|
| method | $str | HTTP method (e.g., `"GET"`, `"POST"`) |
| path | $str | Request path (e.g., `"/items/42"`) |
| headers | @(@($str)) | Key-value pairs of request headers |
| body | $str | Request body (empty string if none) |
| params | @(@($str)) | URL parameters extracted from the route pattern |

### $res

Represents an outgoing HTTP response.

| Field | Type | Meaning |
|-------|------|---------|
| status | u16 | HTTP status code |
| headers | @(@($str)) | Key-value pairs of response headers |
| body | $str | Response body |

## Route Registration

Routes are registered using verb macros. Each takes a URL pattern string and a handler function. Patterns may include named parameters prefixed with `:` (e.g., `"/items/:id"`).

### http.GET(pattern: $str; handler: fn($req): $res)

Registers a handler for GET requests matching `pattern`.

### http.POST(pattern: $str; handler: fn($req): $res)

Registers a handler for POST requests matching `pattern`.

### http.PUT(pattern: $str; handler: fn($req): $res)

Registers a handler for PUT requests matching `pattern`.

### http.DELETE(pattern: $str; handler: fn($req): $res)

Registers a handler for DELETE requests matching `pattern`.

### http.PATCH(pattern: $str; handler: fn($req): $res)

Registers a handler for PATCH requests matching `pattern`.

```toke
http.GET("/"; fn(req: $req): $res =
  http.Res.ok("hello world")
);

http.GET("/items/:id"; fn(req: $req): $res =
  let id = http.param(req; "id");
  http.Res.json(200; "{\"id\":" ++ id ++ "}")
);
```

## Accessor Functions

### http.param(req: $req; name: $str): $str!$httperr

Extracts a named URL parameter from the request. Returns `$httperr.$notfound` if the parameter does not exist.

```toke
let id = http.param(req; "id");  (* id = ok("42") *)
```

### http.header(req: $req; name: $str): $str!$httperr

Extracts a header value by name (case-insensitive lookup). Returns `$httperr.$notfound` if the header is not present.

```toke
let ct = http.header(req; "content-type");
(* ct = ok("application/json") *)
```

## Response Constructors

### http.Res.ok(body: $str): $res

Creates a 200 OK response with the given body.

```toke
let r = http.Res.ok("hello");
(* r.status = 200; r.body = "hello" *)
```

### http.Res.json(status: u16; body: $str): $res

Creates a response with the given status code and a JSON body. Sets the `Content-Type` header to `application/json`.

```toke
let r = http.Res.json(201; "{\"created\":true}");
(* r.status = 201 *)
```

### http.Res.bad(msg: $str): $res

Creates a 400 Bad Request response with the given message as the body.

```toke
let r = http.Res.bad("invalid input");
(* r.status = 400; r.body = "invalid input" *)
```

### http.Res.err(msg: $str): $res

Creates a 500 Internal Server Error response with the given message as the body.

```toke
let r = http.Res.err("something broke");
(* r.status = 500; r.body = "something broke" *)
```

## Usage Examples

```toke
(* A simple CRUD API *)
http.GET("/users/:id"; fn(req: $req): $res =
  let id = http.param(req; "id") |{ http.Res.bad("missing id") };
  let row = db.one("SELECT * FROM users WHERE id=?"; @(id));
  if row.ok? =
    let name = row.str(row!; "name") |{ "unknown" };
    http.Res.json(200; "{\"name\":\"" ++ name ++ "\"}")
  el =
    http.Res.json(404; "{\"error\":\"not found\"}")
);

http.POST("/users"; fn(req: $req): $res =
  let body = json.dec(req.body) |{ http.Res.bad("invalid json") };
  let name = json.str(body; "name") |{ http.Res.bad("missing name") };
  db.exec("INSERT INTO users(name) VALUES(?)"; @(name));
  http.Res.json(201; "{\"ok\":true}")
);
```

## Error Types

### $httperr

A sum type representing HTTP operation failures.

| Variant | Field Type | Meaning |
|---------|------------|---------|
| $badrequest | $str | The request is malformed |
| $notfound | $str | The requested parameter or header was not found |
| $internal | $str | An internal server error occurred |
| $timeout | u32 | The operation timed out (value is timeout in milliseconds) |
