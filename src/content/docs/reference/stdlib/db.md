---
title: std.db
description: Database operations — connect, query, and execute statements against SQL databases.
---

The `std.db` module provides functions for connecting to SQL databases, executing queries, and managing database connections.

## Import

```toke
I=db:std.db;
```

## Functions

### db.connect

Opens a connection to a database using a connection string.

```toke
F=connect(dsn: Str): i64!Err;
```

**Parameters:**

| Name  | Type  | Description                                     |
|-------|-------|-------------------------------------------------|
| `dsn` | `Str` | Data source name / connection string             |

**Returns:** `i64!Err` — a connection handle, or an error if the connection fails.

**Errors:** Returns an error if the database is unreachable or the connection string is invalid.

**Example:**

```toke
let conn = db.connect("sqlite:app.db")!;
```

---

### db.exec

Executes a SQL statement that does not return rows (INSERT, UPDATE, DELETE, CREATE).

```toke
F=exec(conn: i64; sql: Str): i64!Err;
```

**Parameters:**

| Name   | Type  | Description                          |
|--------|-------|--------------------------------------|
| `conn` | `i64` | Connection handle from `db.connect`  |
| `sql`  | `Str` | SQL statement to execute             |

**Returns:** `i64!Err` — the number of rows affected, or an error if execution fails.

**Errors:** Returns an error on SQL syntax errors or connection failures.

**Example:**

```toke
let affected = db.exec(conn, "INSERT INTO users (name) VALUES ('alice')")!;
```

---

### db.query

Executes a SQL query and returns results as a JSON-encoded string.

```toke
F=query(conn: i64; sql: Str): Str!Err;
```

**Parameters:**

| Name   | Type  | Description                          |
|--------|-------|--------------------------------------|
| `conn` | `i64` | Connection handle from `db.connect`  |
| `sql`  | `Str` | SQL query to execute                 |

**Returns:** `Str!Err` — a JSON-encoded string of query results, or an error if the query fails.

**Errors:** Returns an error on SQL syntax errors or connection failures.

**Example:**

```toke
let results = db.query(conn, "SELECT name, age FROM users")!;
```

---

### db.close

Closes a database connection.

```toke
F=close(conn: i64): void!Err;
```

**Parameters:**

| Name   | Type  | Description                          |
|--------|-------|--------------------------------------|
| `conn` | `i64` | Connection handle from `db.connect`  |

**Returns:** `void!Err` — void on success, or an error if the connection cannot be closed.

**Example:**

```toke
db.close(conn)!;
```
