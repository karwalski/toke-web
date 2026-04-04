---
title: "std.http"
description: "HTTP server and response helpers -- declarative route registration and response constructors."
---

**Status: Implemented** -- C runtime backing.

The `std.http` module provides an HTTP server framework. Handlers receive a `$req` and return a `$res`. Response constructor functions simplify building common response shapes.

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

## Server

### http.serve(port: i32; handler: f): void

Starts an HTTP server on the given port. The handler function receives a `$req` and returns a `$res`. URL path matching and dispatch is handled within the handler.

```toke
f=handle(req:http.$req):http.$res{
  if(req.path="/"){
    <http.$res.ok("hello world");
  };
  <http.$res.status(404;"not found");
};

f=main():i64{
  http.serve(8080;handle);
  <0;
};
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

### http.$res.ok(body: $str): $res

Creates a 200 OK response with the given body.

```toke
let r=http.$res.ok("hello");
(* r.status = 200; r.body = "hello" *)
```

### http.$res.json(status: u16; body: $str): $res

Creates a response with the given status code and a JSON body. Sets the `Content-Type` header to `application/json`.

```toke
let r=http.$res.json(201;"{\"created\":true}");
(* r.status = 201 *)
```

### http.$res.status(code: u16; body: $str): $res

Creates a response with the given status code and body.

```toke
let r=http.$res.status(400;"invalid input");
(* r.status = 400; r.body = "invalid input" *)
```

### http.$res.err(msg: $str): $res

Creates a 500 Internal Server Error response with the given message as the body.

```toke
let r=http.$res.err("something broke");
(* r.status = 500; r.body = "something broke" *)
```

## Usage Examples

```toke
(* A simple CRUD API *)
f=handle(req:http.$req):http.$res{
  if(req.path="/users"){
    if(req.method="GET"){
      <http.$res.ok(json.enc(db.many("SELECT * FROM users";@())));
    };
    if(req.method="POST"){
      let body=json.dec(req.body)!$apierr;
      let name=json.str(body;"name")|{Ok:s s;Err:e ""};
      db.exec("INSERT INTO users(name) VALUES(?)";@(name));
      <http.$res.json(201;"{\"ok\":true}");
    };
  };
  <http.$res.status(404;"{\"error\":\"not found\"}");
};
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
