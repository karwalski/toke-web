---
title: "Lesson 9: Standard Library Deep Dive"
description: "A practical tour of the standard library modules with working examples for each."
---

**Estimated time: ~25 minutes**

The toke standard library provides modules covering the most common programming tasks. Each module is imported with `i=alias:std.module;` and accessed through the alias.

> **Note:** Of the modules documented below, 11 have C runtime implementations today (str, file, json, http, db, crypto, env, process, log, time, test). Three modules (io, math, net) are planned but not yet implemented -- they are included here as part of the design vision.

## std.io -- Console I/O

> **Status: Planned** -- not yet implemented. The API below is part of the design vision but has no compiler or runtime backing today.

```
i=io:std.io;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `println` | `(s:$str):void` | Print string with newline |
| `print` | `(s:$str):void` | Print string without newline |
| `readline` | `():$str` | Read one line from stdin |
| `eprintln` | `(s:$str):void` | Print to stderr with newline |

**Example: interactive prompt**

```
m=prompt;
i=io:std.io;

f=main():i64{
  io.print("Enter your name: ");
  let name=io.readline();
  io.println("Hello, \(name)!");
  <0;
};
```

## std.str -- String operations

```
i=str:std.str;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `len` | `(s:$str):u64` | String length in bytes |
| `slice` | `(s:$str;start:u64;length:u64):$str` | Extract substring |
| `contains` | `(s:$str;sub:$str):bool` | Check if substring exists |
| `indexOf` | `(s:$str;sub:$str):i64` | Find substring position (-1 if not found) |
| `replace` | `(s:$str;old:$str;new:$str):$str` | Replace all occurrences |
| `split` | `(s:$str;delim:$str):@($str)` | Split into array |
| `join` | `(parts:@($str);delim:$str):$str` | Join array into string |
| `upper` | `(s:$str):$str` | Convert to uppercase |
| `lower` | `(s:$str):$str` | Convert to lowercase |
| `trim` | `(s:$str):$str` | Remove leading/trailing whitespace |
| `startsWith` | `(s:$str;prefix:$str):bool` | Check prefix |
| `endsWith` | `(s:$str;suffix:$str):bool` | Check suffix |
| `repeat` | `(s:$str;n:u64):$str` | Repeat string n times |
| `fromInt` | `(n:i64):$str` | Convert integer to string |
| `toInt` | `(s:$str):i64!$strerr` | Parse string to integer |

**Example: parse a key=value config line**

```
f=parseLine(line:$str):@($str){
  let parts=str.split(line;"=");
  <@(str.trim(parts.0);str.trim(parts.1));
};
```

## std.file -- File system

```
i=file:std.file;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `read` | `(path:$str):$str!$fileerr` | Read entire file as string |
| `write` | `(path:$str;content:$str):void!$fileerr` | Write string to file (overwrite) |
| `append` | `(path:$str;content:$str):void!$fileerr` | Append string to file |
| `exists` | `(path:$str):bool` | Check if file exists |
| `delete` | `(path:$str):void!$fileerr` | Delete a file |
| `readBytes` | `(path:$str):@(u8)!$fileerr` | Read file as byte array |
| `writeBytes` | `(path:$str;data:@(u8)):void!$fileerr` | Write byte array to file |
| `listDir` | `(path:$str):@($str)!$fileerr` | List directory entries |

**Example: copy a file**

```
f=copyFile(src:$str;dst:$str):void!$fileerr{
  let content=file.read(src)!$fileerr;
  file.write(dst;content)!$fileerr;
};
```

## std.json -- JSON

```
i=json:std.json;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `enc` | `(val:T):$str` | Encode any type to JSON string |
| `dec` | `(s:$str):T!$jsonerr` | Decode JSON string to typed value |
| `get` | `(obj:T;key:$str):T!$jsonerr` | Extract a field from decoded JSON |
| `pretty` | `(val:T):$str` | Encode with indentation |

**Example: JSON round-trip**

```
t=$config{host:$str;port:i64;debug:bool};

f=save(c:$config;path:$str):void!$apperr{
  let data=json.enc(c);
  file.write(path;data)!$apperr;
};

f=load(path:$str):$config!$apperr{
  let data=file.read(path)!$apperr;
  let cfg=json.dec(data)!$apperr;
  <cfg;
};
```

## std.http -- HTTP server and client

```
i=http:std.http;
```

### Client functions

| Function | Signature | Purpose |
|----------|-----------|---------|
| `get` | `(url:$str):http.$res!http.$err` | HTTP GET request |
| `post` | `(url:$str;body:$str):http.$res!http.$err` | HTTP POST request |
| `put` | `(url:$str;body:$str):http.$res!http.$err` | HTTP PUT request |
| `delete` | `(url:$str):http.$res!http.$err` | HTTP DELETE request |

### Server types and functions

| Type/Function | Purpose |
|---------------|---------|
| `http.$req` | Incoming request (method, path, body, headers) |
| `http.$res` | Response (status, body, headers) |
| `http.$res.ok(body:$str)` | Create 200 response |
| `http.$res.status(code:i32;body:$str)` | Create response with status |
| `http.serve(port:i32;handler:f)` | Start HTTP server |

**Example: simple HTTP server**

```
m=server;
i=http:std.http;
i=json:std.json;

t=$apierr{
  $notfound:$str;
  $badrequest:$str
};

f=handle(req:http.$req):http.$res{
  if(req.path="/health"){
    <http.$res.ok("ok");
  };
  if(req.path="/echo"){
    <http.$res.ok(req.body);
  };
  <http.$res.status(404;"not found");
};

f=main():i64{
  http.serve(8080;handle);
  <0;
};
```

**Example: HTTP client**

```
m=client;
i=http:std.http;
i=io:std.io;

f=main():i64{
  http.get("https://api.example.com/data")|{
    Ok:res  io.println("Status: \(res.status as $str)\nBody: \(res.body)");
    Err:e   io.println("Request failed");
  };
  <0;
};
```

## std.db -- Database access

```
i=db:std.db;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `open` | `(path:$str):db.$conn!db.$err` | Open SQLite database |
| `exec` | `(conn:db.$conn;sql:$str;params:@($str)):db.$result!db.$err` | Execute statement |
| `query` | `(conn:db.$conn;sql:$str;params:@($str)):@(db.$row)!db.$err` | Query rows |
| `one` | `(conn:db.$conn;sql:$str;params:@($str)):db.$row!db.$err` | Query single row |
| `close` | `(conn:db.$conn):void` | Close connection |

**Example: SQLite CRUD**

```
m=todos;
i=db:std.db;

t=$todo{id:u64;title:$str;done:bool};
t=$todoerr{$dberr:$str;$notfound:u64};

f=init(conn:db.$conn):void!$todoerr{
  db.exec(conn;"CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY, title TEXT, done INTEGER)";@())!$todoerr;
};

f=add(conn:db.$conn;title:$str):$todo!$todoerr{
  let r=db.exec(conn;"INSERT INTO todos (title,done) VALUES (?,0)";@(title))!$todoerr;
  <$todo{id:r.lastId;title:title;done:false};
};

f=list(conn:db.$conn):@($todo)!$todoerr{
  let rows=db.query(conn;"SELECT id,title,done FROM todos";@())!$todoerr;
  let result=mut.@();
  lp(let i=0;i<rows.len;i=i+1){
    let r=rows.get(i);
    result=result.push($todo{
      id:r.u64("id");
      title:r.str("title");
      done:r.i64("done")=1
    });
  };
  <result;
};
```

## std.crypto -- Cryptographic utilities

```
i=crypto:std.crypto;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `sha256` | `(data:$str):$str` | SHA-256 hash (hex string) |
| `sha512` | `(data:$str):$str` | SHA-512 hash (hex string) |
| `hmac` | `(key:$str;data:$str;algo:$str):$str` | HMAC signature |
| `randomBytes` | `(n:u64):@(u8)` | Cryptographic random bytes |
| `uuid` | `():$str` | Generate UUID v4 |

**Example: hash a password**

```
f=hashPassword(password:$str;salt:$str):$str{
  <crypto.sha256(salt+password);
};
```

## std.process -- External commands

```
i=proc:std.process;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `run` | `(cmd:$str;args:@($str)):proc.$output!proc.$err` | Run command and capture output |
| `exec` | `(cmd:$str;args:@($str)):i32!proc.$err` | Run command and return exit code |
| `env` | `(key:$str):$str` | Get environment variable |

**Example: run a shell command**

```
m=runner;
i=proc:std.process;
i=io:std.io;

f=main():i64{
  proc.run("ls";@("-la";"./src"))|{
    Ok:out  io.println(out.stdout);
    Err:e   io.println("Command failed");
  };
  <0;
};
```

## std.time -- Time and dates

```
i=time:std.time;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `now` | `():u64` | Unix timestamp in seconds |
| `nowMs` | `():u64` | Unix timestamp in milliseconds |
| `format` | `(ts:u64;fmt:$str):$str` | Format timestamp |
| `sleep` | `(ms:u64):void` | Sleep for milliseconds |

**Example: timestamp a log entry**

```
f=log(msg:$str):void{
  let ts=time.format(time.now();"%Y-%m-%d %H:%M:%S");
  io.println("[\(ts)] \(msg)");
};
```

## std.math -- Mathematical functions

> **Status: Planned** -- not yet implemented. The API below is part of the design vision but has no compiler or runtime backing today.

```
i=math:std.math;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `sqrt` | `(x:f64):f64` | Square root |
| `abs` | `(x:f64):f64` | Absolute value |
| `pow` | `(base:f64;exp:f64):f64` | Exponentiation |
| `floor` | `(x:f64):f64` | Floor |
| `ceil` | `(x:f64):f64` | Ceiling |
| `min` | `(a:f64;b:f64):f64` | Minimum |
| `max` | `(a:f64;b:f64):f64` | Maximum |
| `PI` | `f64` | Pi constant |

**Example: distance formula**

```
f=distance(x1:f64;y1:f64;x2:f64;y2:f64):f64{
  let dx=x2-x1;
  let dy=y2-y1;
  <math.sqrt(dx*dx+dy*dy);
};
```

## std.net -- TCP sockets

> **Status: Planned** -- not yet implemented. The API below is part of the design vision but has no compiler or runtime backing today.

```
i=net:std.net;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `listen` | `(addr:$str;port:i32):net.$listener!net.$err` | Start TCP listener |
| `accept` | `(l:net.$listener):net.$conn!net.$err` | Accept connection |
| `connect` | `(addr:$str;port:i32):net.$conn!net.$err` | Connect to TCP server |
| `send` | `(c:net.$conn;data:$str):void!net.$err` | Send data |
| `recv` | `(c:net.$conn):$str!net.$err` | Receive data |
| `close` | `(c:net.$conn):void` | Close connection |

**Example: TCP echo server**

```
m=echo;
i=net:std.net;

f=main():i64!net.$neterr{
  let listener=net.listen("0.0.0.0";9000)!net.$neterr;
  lp(let x=0;true;x=0){
    net.accept(listener)|{
      Ok:conn  {
        net.recv(conn)|{
          Ok:data  net.send(conn;data)|{Ok:v {};Err:e {}};
          Err:e    {}
        };
        net.close(conn);
      };
      Err:e  {}
    };
  };
  <0;
};
```

## Exercises

### Exercise 1: HTTP API

Write a simple HTTP server with two endpoints:
- `GET /time` -- returns the current Unix timestamp as JSON
- `POST /hash` -- takes a string body and returns its SHA-256 hash

Use `std.http`, `std.time`, `std.crypto`, and `std.json`.

### Exercise 2: File backup tool

Write a program that:
1. Reads a file path from the command line
2. Copies the file to `{path}.bak`
3. Prints the SHA-256 hash of the file for verification

Use `std.file`, `std.crypto`, and `std.process` (for env/args).

### Exercise 3: Database explorer

Write a program that:
1. Opens a SQLite database
2. Lists all tables (query `sqlite_master`)
3. For each table, prints the row count

## Key takeaways

- 11 standard library modules with C runtime implementations cover strings, files, JSON, HTTP, database, crypto, environment, process, logging, time, and testing -- with io, math, and net planned for future releases
- All modules follow the same import pattern: `i=alias:std.module;`
- Fallible stdlib functions return `T!$err` types -- always handle the error
- The stdlib is designed for practical server-side and CLI applications
- Each module is self-contained with a small, focused API

## Next

[Lesson 10: Build a Complete Project](/learn/10-project/) -- put everything together in a real application.
