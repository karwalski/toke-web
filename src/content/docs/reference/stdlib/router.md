---
title: "std.router"
description: "HTTP request router with path parameters and middleware support."
---

**Status: Implemented** -- C runtime backing.

The `std.router` module provides a declarative HTTP router. Register routes by method and path pattern, attach middleware, and serve the application.

## Types

### $router

Opaque handle to a router instance.

### $ctx

| Field | Type | Meaning |
|-------|------|---------|
| req | http.$Req | The incoming HTTP request |
| params | @(@($str)) | Path parameters extracted from the route pattern |
| state | @(@($str)) | Per-request state set by middleware |

### $handler

Opaque handle to a route handler function.

### $middleware

Opaque handle to a middleware function.

### $routererr

| Field | Type | Meaning |
|-------|------|---------|
| msg | $str | Error description |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `router.new` | | `$router` | Create a new router |
| `router.get` | `r: $router; path: $str; h: $handler` | `void` | Register a GET route |
| `router.post` | `r: $router; path: $str; h: $handler` | `void` | Register a POST route |
| `router.put` | `r: $router; path: $str; h: $handler` | `void` | Register a PUT route |
| `router.delete` | `r: $router; path: $str; h: $handler` | `void` | Register a DELETE route |
| `router.use` | `r: $router; mw: $middleware` | `void` | Attach middleware to the router |
| `router.serve` | `r: $router; host: $str; port: u64` | `void!$routererr` | Start serving HTTP on host:port |

## Usage

```toke
use std.router
use std.http

f=hello(ctx:router.$ctx):http.$res{
  <http.$res.ok("hello world")
}

f=main():i64{
  let r = router.new()
  router.get(r; "/hello"; hello)
  router.serve(r; "0.0.0.0"; 8080)
  <0
}
```

## Dependencies

- `std.http` -- request and response types.
