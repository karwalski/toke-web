---
title: "Lesson 6: Strings and I/O"
description: "Work with the $str type, string operations from std.str, file I/O with std.file, and JSON with std.json."
---

**Estimated time: ~20 minutes**

## The $str type

Strings in toke are UTF-8 encoded, heap-allocated values of type `$str`. String literals are delimited by double quotes:

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
let msg="Name: \(name), Age: \(age as $str)";
```

The expression inside `\(...)` must resolve to a `$str`-compatible type. Use `as $str` to convert numbers.

## String operations with std.str

Import the string module to access string functions:

```
i=str:std.str;
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
i=io:std.io;
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
i=file:std.file;
```

### Reading a file

```
t=$fileerr{
  $notfound:$str;
  $readfailed:$str
};

f=readConfig(path:$str):$str!$fileerr{
  let content=file.read(path)!$fileerr;
  <content;
};
```

`file.read` returns the entire file content as a `$str`. It is a fallible operation -- the file might not exist or might not be readable.

### Writing a file

```
f=saveData(path:$str;data:$str):void!$fileerr{
  file.write(path;data)!$fileerr;
};
```

`file.write` creates the file if it does not exist, or overwrites it if it does.

### Appending to a file

```
f=log(path:$str;msg:$str):void!$fileerr{
  file.append(path;msg)!$fileerr;
};
```

### Checking if a file exists

```
let exists=file.exists("config.json");
```

## JSON with std.json

```
i=json:std.json;
```

### Encoding (struct to JSON string)

```
t=$user{id:u64;name:$str;email:$str};

f=userToJson(u:$user):$str{
  <json.enc(u);
};
```

### Decoding (JSON string to struct)

```
t=$jsonerr{
  $parsefailed:$str;
  $missingfield:$str
};

f=jsonToUser(s:$str):$user!$jsonerr{
  let u=json.dec(s)!$jsonerr;
  <u;
};
```

### Working with dynamic JSON

For JSON whose structure you do not know at compile time, use `json.get` to extract fields:

```
f=getName(raw:$str):$str!$jsonerr{
  let obj=json.dec(raw)!$jsonerr;
  let name=json.get(obj;"name")!$jsonerr;
  <name as $str;
};
```

## Practical example: word counter

Here is a complete program that reads a file and counts word frequencies:

```
m=wc;
i=io:std.io;
i=file:std.file;
i=str:std.str;

t=$wcerr{
  $fileerr:$str
};

f=countWords(text:$str):$($str:i64){
  let words=str.split(text;" ");
  let freq=mut.$($str:i64)();
  lp(let i=0;i<words.len;i=i+1){
    let w=str.lower(str.trim(words.get(i)));
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

f=main():i64{
  file.read("input.txt")|{
    Ok:content  {
      let freq=countWords(content);
      let keys=freq.keys;
      lp(let i=0;i<keys.len;i=i+1){
        let k=keys.get(i);
        io.println("\(k): \(freq.get(k) as $str)");
      };
    };
    Err:e  io.println("Error reading file: \(e as $str)");
  };
  <0;
};
```

## Exercises

### Exercise 1: Line counter

Write a program that reads a file and prints the number of lines. Use `str.split` with `"\n"` as the delimiter.

### Exercise 2: CSV parser

Write a function `f=parseCsv(content:$str):@(@($str))` that splits a CSV string into a 2D array. Split on `"\n"` for rows and `","` for columns.

### Exercise 3: JSON round-trip

Define a `t=$config{host:$str;port:i64;debug:bool}` type. Write:
- `f=saveConfig(path:$str;c:$config):void!$fileerr` that encodes to JSON and writes to a file
- `f=loadConfig(path:$str):$config!$configerr` that reads a file and decodes from JSON

## Key takeaways

- `$str` is UTF-8, heap-allocated, and the only string type
- String interpolation: `"text \(expr) more text"`
- `std.str` provides `len`, `slice`, `contains`, `indexOf`, `replace`, `split`, `join`, `upper`, `lower`, `trim`
- `std.io` provides `println`, `print`, `readline`
- `std.file` provides `read`, `write`, `append`, `exists`
- `std.json` provides `enc` (encode) and `dec` (decode)
- File and JSON operations are fallible -- use `!` or match to handle errors

## Next

[Lesson 7: Modules and Imports](/learn/07-modules-imports/) -- organising code across multiple files.
