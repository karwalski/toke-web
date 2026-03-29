---
title: "Lesson 6: Strings and I/O"
description: "Work with the Str type, string operations from std.str, file I/O with std.file, and JSON with std.json."
---

**Estimated time: ~20 minutes**

## The Str type

Strings in toke are UTF-8 encoded, heap-allocated values of type `Str`. String literals are delimited by double quotes:

```
let greeting="Hello, world!";
let empty="";
let with_escape="Line one\nLine two";
```

### Escape sequences

| Sequence | Meaning |
|----------|---------|
| `\"` | Literal double quote |
| `\\` | Literal backslash |
| `\n` | Newline |
| `\t` | Tab |
| `\r` | Carriage return |
| `\0` | Null byte |
| `\xNN` | Byte with hex value NN |

### String interpolation

Insert expressions into strings with `\(expr)`:

```
let name="Alice";
let age=30;
let msg="Name: \(name), Age: \(age as Str)";
```

The expression inside `\(...)` must resolve to a `Str`-compatible type. Use `as Str` to convert numbers.

## String operations with std.str

Import the string module to access string functions:

```
I=str:std.str;
```

### Length

```
let s="Hello";
let n=str.len(s);
```

### Slicing

Extract a substring by start index and length:

```
let s="Hello, world!";
let hello=str.slice(s;0;5);
let world=str.slice(s;7;5);
```

### Search

```
let found=str.contains(s;"world");
let idx=str.indexOf(s;"world");
```

### Replace

```
let result=str.replace("Hello, world!";"world";"toke");
```

### Split and join

```
let parts=str.split("a,b,c";",");
let joined=str.join(parts;"-");
```

### Case conversion

```
let upper=str.upper("hello");
let lower=str.lower("HELLO");
```

### Trim

```
let trimmed=str.trim("  hello  ");
```

## Console I/O with std.io

```
I=io:std.io;
```

### Printing

```
io.println("Hello, world!");
io.print("Enter your name: ");
```

### Reading input

```
let line=io.readline();
```

## File I/O with std.file

```
I=file:std.file;
```

### Reading a file

```
T=FileErr{
  NotFound:Str;
  ReadFailed:Str
};

F=readConfig(path:Str):Str!FileErr{
  let content=file.read(path)!FileErr;
  <content;
};
```

`file.read` returns the entire file content as a `Str`. It is a fallible operation -- the file might not exist or might not be readable.

### Writing a file

```
F=saveData(path:Str;data:Str):void!FileErr{
  file.write(path;data)!FileErr;
};
```

`file.write` creates the file if it does not exist, or overwrites it if it does.

### Appending to a file

```
F=log(path:Str;msg:Str):void!FileErr{
  file.append(path;msg)!FileErr;
};
```

### Checking if a file exists

```
let exists=file.exists("config.json");
```

## JSON with std.json

```
I=json:std.json;
```

### Encoding (struct to JSON string)

```
T=User{id:u64;name:Str;email:Str};

F=userToJson(u:User):Str{
  <json.enc(u);
};
```

### Decoding (JSON string to struct)

```
T=JsonErr{
  ParseFailed:Str;
  MissingField:Str
};

F=jsonToUser(s:Str):User!JsonErr{
  let u=json.dec(s)!JsonErr;
  <u;
};
```

### Working with dynamic JSON

For JSON whose structure you do not know at compile time, use `json.get` to extract fields:

```
F=getName(raw:Str):Str!JsonErr{
  let obj=json.dec(raw)!JsonErr;
  let name=json.get(obj;"name")!JsonErr;
  <name as Str;
};
```

## Practical example: word counter

Here is a complete program that reads a file and counts word frequencies:

```
M=wc;
I=io:std.io;
I=file:std.file;
I=str:std.str;

T=WcErr{
  FileErr:Str
};

F=countWords(text:Str):[Str:i64]{
  let words=str.split(text;" ");
  let freq=mut.[];
  lp(let i=0;i<words.len;i=i+1){
    let w=str.lower(str.trim(words[i]));
    if(str.len(w)>0){
      if(freq.contains(w)){
        freq=freq.put(w;freq.get(w)+1);
      }el{
        freq=freq.put(w;1);
      };
    };
  };
  <freq;
};

F=main():i64{
  file.read("input.txt")|{
    Ok:content  {
      let freq=countWords(content);
      let keys=freq.keys;
      lp(let i=0;i<keys.len;i=i+1){
        let k=keys[i];
        io.println("\(k): \(freq.get(k) as Str)");
      };
    };
    Err:e  io.println("Error reading file: \(e as Str)");
  };
  <0;
};
```

## Exercises

### Exercise 1: Line counter

Write a program that reads a file and prints the number of lines. Use `str.split` with `"\n"` as the delimiter.

### Exercise 2: CSV parser

Write a function `F=parseCsv(content:Str):[[Str]]` that splits a CSV string into a 2D array. Split on `"\n"` for rows and `","` for columns.

### Exercise 3: JSON round-trip

Define a `T=Config{host:Str;port:i64;debug:bool}` type. Write:
- `F=saveConfig(path:Str;c:Config):void!FileErr` that encodes to JSON and writes to a file
- `F=loadConfig(path:Str):Config!ConfigErr` that reads a file and decodes from JSON

## Key takeaways

- `Str` is UTF-8, heap-allocated, and the only string type
- String interpolation: `"text \(expr) more text"`
- `std.str` provides `len`, `slice`, `contains`, `indexOf`, `replace`, `split`, `join`, `upper`, `lower`, `trim`
- `std.io` provides `println`, `print`, `readline`
- `std.file` provides `read`, `write`, `append`, `exists`
- `std.json` provides `enc` (encode) and `dec` (decode)
- File and JSON operations are fallible -- use `!` or match to handle errors

## Next

[Lesson 7: Modules and Imports](/learn/07-modules-imports/) -- organising code across multiple files.
