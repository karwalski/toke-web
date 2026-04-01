---
title: "std.db"
description: "Database operations -- SQL queries via SQLite with typed row accessors."
---

**Status: Implemented** -- C runtime backing, available in Phase 2.

The `std.db` module provides functions for querying a SQL database. It uses a single implicit connection opened with `db.open` and closed with `db.close`. Query results are returned as `$row` values, with typed accessor functions to extract column values.

The current implementation uses SQLite as the backend.

## Types

### $row

Represents a single row returned from a query. Column values are accessed by name using the `row.*` accessor functions.

## Functions

### db.open(dsn: $str): bool

Opens a database connection using the given data source name. For SQLite, this is a file path or `":memory:"` for an in-memory database. Returns `true` on success, `false` on failure.

```toke
db.open(":memory:");
db.open("/tmp/app.db");
```

### db.close(): void

Closes the current database connection and releases all associated resources.

```toke
db.close();
```

### db.exec(sql: $str; params: @($str)): u64!$dberr

Executes a SQL statement that does not return rows (e.g., `INSERT`, `UPDATE`, `DELETE`, `CREATE TABLE`). Returns the number of rows affected. The `params` array provides positional bind parameters.

```toke
db.exec("CREATE TABLE t(id INTEGER; name TEXT)"; @());
let n = db.exec("INSERT INTO t VALUES(1;'hello')"; @());
(* n = ok(1) *)
```

### db.one(sql: $str; params: @($str)): $row!$dberr

Executes a query and returns the first row. Returns `$dberr.$notfound` if no rows match, or `$dberr.$query` if the SQL is invalid.

```toke
let row = db.one("SELECT id;name FROM t WHERE id=1"; @());
(* row = ok($row{...}) *)
```

### db.many(sql: $str; params: @($str)): @($row)!$dberr

Executes a query and returns all matching rows as an array. Returns `$dberr.$query` if the SQL is invalid.

```toke
let rows = db.many("SELECT * FROM t"; @());
(* rows = ok(@($row; $row; ...)) *)
```

### row.str(r: $row; col: $str): $str!$dberr

Extracts the value of column `col` from `r` as a string. Returns `$dberr.$notfound` if the column does not exist in the row.

```toke
let name = row.str(r; "name");  (* name = ok("hello") *)
```

### row.u64(r: $row; col: $str): u64!$dberr

Extracts the value of column `col` from `r` as an unsigned 64-bit integer. Returns `$dberr.$notfound` if the column does not exist.

```toke
let id = row.u64(r; "id");  (* id = ok(1) *)
```

### row.i64(r: $row; col: $str): i64!$dberr

Extracts the value of column `col` from `r` as a signed 64-bit integer. Returns `$dberr.$notfound` if the column does not exist.

```toke
let val = row.i64(r; "balance");  (* val = ok(-100) *)
```

### row.f64(r: $row; col: $str): f64!$dberr

Extracts the value of column `col` from `r` as a 64-bit float. Returns `$dberr.$notfound` if the column does not exist.

```toke
let price = row.f64(r; "price");  (* price = ok(19.99) *)
```

### row.bool(r: $row; col: $str): bool!$dberr

Extracts the value of column `col` from `r` as a boolean. Returns `$dberr.$notfound` if the column does not exist.

```toke
let active = row.bool(r; "active");  (* active = ok(true) *)
```

## Usage Examples

```toke
(* Open an in-memory database; create a table; insert and query *)
db.open(":memory:");
db.exec("CREATE TABLE users(id INTEGER; name TEXT; active INTEGER)"; @());
db.exec("INSERT INTO users VALUES(1;'alice';1)"; @());

let row = db.one("SELECT * FROM users WHERE id=1"; @());
if row.ok? =
  let name = row.str(row!; "name") |{ "unknown" };
  log.info("found user"; @(@("name"; name)))
el =
  log.warn("user not found"; @());

db.close();
```

## Error Types

### $dberr

A sum type representing database operation failures.

| Variant | Field Type | Meaning |
|---------|------------|---------|
| $connection | $str | Failed to connect to the database |
| $query | $str | The SQL statement is invalid |
| $notfound | $str | No matching row or column found |
| $constraint | $str | A database constraint was violated (e.g., unique, foreign key) |
