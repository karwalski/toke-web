---
title: "Lesson 9: Standard Library Deep Dive"
description: "A practical tour of all 11 standard library modules with working examples for each."
---

**Estimated time: ~25 minutes**

The toke standard library provides 11 modules covering the most common programming tasks. Each module is imported with `I=alias:std.module;` and accessed through the alias.

## std.io -- Console I/O

```
I=io:std.io;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `println` | `(s:Str):void` | Print string with newline |
| `print` | `(s:Str):void` | Print string without newline |
| `readline` | `():Str` | Read one line from stdin |
| `eprintln` | `(s:Str):void` | Print to stderr with newline |

**Example: interactive prompt**

```
M=prompt;
I=io:std.io;

F=main():i64{
  io.print("Enter your name: ");
  let name=io.readline();
  io.println("Hello, \(name)!");
  <0;
};
```

## std.str -- String operations

```
I=str:std.str;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `len` | `(s:Str):u64` | String length in bytes |
| `slice` | `(s:Str;start:u64;length:u64):Str` | Extract substring |
| `contains` | `(s:Str;sub:Str):bool` | Check if substring exists |
| `indexOf` | `(s:Str;sub:Str):i64` | Find substring position (-1 if not found) |
| `replace` | `(s:Str;old:Str;new:Str):Str` | Replace all occurrences |
| `split` | `(s:Str;delim:Str):[Str]` | Split into array |
| `join` | `(parts:[Str];delim:Str):Str` | Join array into string |
| `upper` | `(s:Str):Str` | Convert to uppercase |
| `lower` | `(s:Str):Str` | Convert to lowercase |
| `trim` | `(s:Str):Str` | Remove leading/trailing whitespace |
| `startsWith` | `(s:Str;prefix:Str):bool` | Check prefix |
| `endsWith` | `(s:Str;suffix:Str):bool` | Check suffix |
| `repeat` | `(s:Str;n:u64):Str` | Repeat string n times |
| `fromInt` | `(n:i64):Str` | Convert integer to string |
| `toInt` | `(s:Str):i64!StrErr` | Parse string to integer |

**Example: parse a key=value config line**

```
F=parseLine(line:Str):[Str]{
  let parts=str.split(line;"=");
  <[str.trim(parts[0]);str.trim(parts[1])];
};
```

## std.file -- File system

```
I=file:std.file;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `read` | `(path:Str):Str!FileErr` | Read entire file as string |
| `write` | `(path:Str;content:Str):void!FileErr` | Write string to file (overwrite) |
| `append` | `(path:Str;content:Str):void!FileErr` | Append string to file |
| `exists` | `(path:Str):bool` | Check if file exists |
| `delete` | `(path:Str):void!FileErr` | Delete a file |
| `readBytes` | `(path:Str):[u8]!FileErr` | Read file as byte array |
| `writeBytes` | `(path:Str;data:[u8]):void!FileErr` | Write byte array to file |
| `listDir` | `(path:Str):[Str]!FileErr` | List directory entries |

**Example: copy a file**

```
F=copyFile(src:Str;dst:Str):void!FileErr{
  let content=file.read(src)!FileErr;
  file.write(dst;content)!FileErr;
};
```

## std.json -- JSON

```
I=json:std.json;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `enc` | `(val:T):Str` | Encode any type to JSON string |
| `dec` | `(s:Str):T!JsonErr` | Decode JSON string to typed value |
| `get` | `(obj:T;key:Str):T!JsonErr` | Extract a field from decoded JSON |
| `pretty` | `(val:T):Str` | Encode with indentation |

**Example: JSON round-trip**

```
T=Config{host:Str;port:i64;debug:bool};

F=save(c:Config;path:Str):void!AppErr{
  let data=json.enc(c);
  file.write(path;data)!AppErr;
};

F=load(path:Str):Config!AppErr{
  let data=file.read(path)!AppErr;
  let cfg=json.dec(data)!AppErr;
  <cfg;
};
```

## std.http -- HTTP server and client

```
I=http:std.http;
```

### Client functions

| Function | Signature | Purpose |
|----------|-----------|---------|
| `get` | `(url:Str):http.Res!http.Err` | HTTP GET request |
| `post` | `(url:Str;body:Str):http.Res!http.Err` | HTTP POST request |
| `put` | `(url:Str;body:Str):http.Res!http.Err` | HTTP PUT request |
| `delete` | `(url:Str):http.Res!http.Err` | HTTP DELETE request |

### Server types and functions

| Type/Function | Purpose |
|---------------|---------|
| `http.Req` | Incoming request (method, path, body, headers) |
| `http.Res` | Response (status, body, headers) |
| `http.Res.ok(body:Str)` | Create 200 response |
| `http.Res.status(code:i32;body:Str)` | Create response with status |
| `http.serve(port:i32;handler:F)` | Start HTTP server |

**Example: simple HTTP server**

```
M=server;
I=http:std.http;
I=json:std.json;

T=ApiErr{
  NotFound:Str;
  BadRequest:Str
};

F=handle(req:http.Req):http.Res{
  if(req.path="/health"){
    <http.Res.ok("ok");
  };
  if(req.path="/echo"){
    <http.Res.ok(req.body);
  };
  <http.Res.status(404;"not found");
};

F=main():i64{
  http.serve(8080;handle);
  <0;
};
```

**Example: HTTP client**

```
M=client;
I=http:std.http;
I=io:std.io;

F=main():i64{
  http.get("https://api.example.com/data")|{
    Ok:res  io.println("Status: \(res.status as Str)\nBody: \(res.body)");
    Err:e   io.println("Request failed");
  };
  <0;
};
```

## std.db -- Database access

```
I=db:std.db;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `open` | `(path:Str):db.Conn!db.Err` | Open SQLite database |
| `exec` | `(conn:db.Conn;sql:Str;params:[Str]):db.Result!db.Err` | Execute statement |
| `query` | `(conn:db.Conn;sql:Str;params:[Str]):[db.Row]!db.Err` | Query rows |
| `one` | `(conn:db.Conn;sql:Str;params:[Str]):db.Row!db.Err` | Query single row |
| `close` | `(conn:db.Conn):void` | Close connection |

**Example: SQLite CRUD**

```
M=todos;
I=db:std.db;

T=Todo{id:u64;title:Str;done:bool};
T=TodoErr{DbErr:Str;NotFound:u64};

F=init(conn:db.Conn):void!TodoErr{
  db.exec(conn;"CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY, title TEXT, done INTEGER)";[])!TodoErr;
};

F=add(conn:db.Conn;title:Str):Todo!TodoErr{
  let r=db.exec(conn;"INSERT INTO todos (title,done) VALUES (?,0)";[title])!TodoErr;
  <Todo{id:r.lastId;title:title;done:false};
};

F=list(conn:db.Conn):[Todo]!TodoErr{
  let rows=db.query(conn;"SELECT id,title,done FROM todos";[])!TodoErr;
  let result=mut.[];
  lp(let i=0;i<rows.len;i=i+1){
    let r=rows[i];
    result=result.push(Todo{
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
I=crypto:std.crypto;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `sha256` | `(data:Str):Str` | SHA-256 hash (hex string) |
| `sha512` | `(data:Str):Str` | SHA-512 hash (hex string) |
| `hmac` | `(key:Str;data:Str;algo:Str):Str` | HMAC signature |
| `randomBytes` | `(n:u64):[u8]` | Cryptographic random bytes |
| `uuid` | `():Str` | Generate UUID v4 |

**Example: hash a password**

```
F=hashPassword(password:Str;salt:Str):Str{
  <crypto.sha256(salt+password);
};
```

## std.process -- External commands

```
I=proc:std.process;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `run` | `(cmd:Str;args:[Str]):proc.Output!proc.Err` | Run command and capture output |
| `exec` | `(cmd:Str;args:[Str]):i32!proc.Err` | Run command and return exit code |
| `env` | `(key:Str):Str` | Get environment variable |

**Example: run a shell command**

```
M=runner;
I=proc:std.process;
I=io:std.io;

F=main():i64{
  proc.run("ls";["-la";"./src"])|{
    Ok:out  io.println(out.stdout);
    Err:e   io.println("Command failed");
  };
  <0;
};
```

## std.time -- Time and dates

```
I=time:std.time;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `now` | `():u64` | Unix timestamp in seconds |
| `nowMs` | `():u64` | Unix timestamp in milliseconds |
| `format` | `(ts:u64;fmt:Str):Str` | Format timestamp |
| `sleep` | `(ms:u64):void` | Sleep for milliseconds |

**Example: timestamp a log entry**

```
F=log(msg:Str):void{
  let ts=time.format(time.now();"%Y-%m-%d %H:%M:%S");
  io.println("[\(ts)] \(msg)");
};
```

## std.math -- Mathematical functions

```
I=math:std.math;
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
F=distance(x1:f64;y1:f64;x2:f64;y2:f64):f64{
  let dx=x2-x1;
  let dy=y2-y1;
  <math.sqrt(dx*dx+dy*dy);
};
```

## std.net -- TCP sockets

```
I=net:std.net;
```

| Function | Signature | Purpose |
|----------|-----------|---------|
| `listen` | `(addr:Str;port:i32):net.Listener!net.Err` | Start TCP listener |
| `accept` | `(l:net.Listener):net.Conn!net.Err` | Accept connection |
| `connect` | `(addr:Str;port:i32):net.Conn!net.Err` | Connect to TCP server |
| `send` | `(c:net.Conn;data:Str):void!net.Err` | Send data |
| `recv` | `(c:net.Conn):Str!net.Err` | Receive data |
| `close` | `(c:net.Conn):void` | Close connection |

**Example: TCP echo server**

```
M=echo;
I=net:std.net;

F=main():i64!net.NetErr{
  let listener=net.listen("0.0.0.0";9000)!net.NetErr;
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

- 11 standard library modules cover I/O, strings, files, JSON, HTTP, database, crypto, process, time, math, and networking
- All modules follow the same import pattern: `I=alias:std.module;`
- Fallible stdlib functions return `T!Err` types -- always handle the error
- The stdlib is designed for practical server-side and CLI applications
- Each module is self-contained with a small, focused API

## Next

[Lesson 10: Build a Complete Project](/learn/10-project/) -- put everything together in a real application.
