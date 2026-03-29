---
title: "Lesson 10: Build a Complete Project"
description: "Design and build a CLI bookmark manager from scratch, applying everything from the course."
---

**Estimated time: ~30 minutes**

In this final lesson, you will build a complete toke application: a CLI bookmark manager called `bm`. It stores URLs with tags, persists data to a JSON file, and supports add, list, search, and delete operations.

This lesson ties together modules, functions, types, error handling, collections, string operations, file I/O, and JSON -- everything from the previous nine lessons.

## Project design

### Features

- **Add** a bookmark with a URL and tags
- **List** all bookmarks
- **Search** bookmarks by tag or URL substring
- **Delete** a bookmark by ID
- **Persist** data to a JSON file between runs

### Module structure

```
bm/
  main.tk       M=bm.main       -- CLI entry point and argument parsing
  store.tk      M=bm.store      -- Bookmark storage, load/save, CRUD operations
  model.tk      M=bm.model      -- Type definitions
```

Three files, each with a clear responsibility.

## Step 1: Define the model

The model module defines the core types:

`bm/model.tk`:

```
M=bm.model;

T=Bookmark{
  id:u64;
  url:Str;
  title:Str;
  tags:[Str]
};

T=BookmarkDb{
  bookmarks:[Bookmark];
  nextId:u64
};

T=BmErr{
  FileErr:Str;
  ParseErr:Str;
  NotFound:u64
};
```

`Bookmark` is a single entry. `BookmarkDb` holds the array of bookmarks and a counter for generating unique IDs. `BmErr` covers all failure modes.

The interface file for this module would be:

`bm/model.tki`:

```
M=bm.model;

T=Bookmark{id:u64;url:Str;title:Str;tags:[Str]};
T=BookmarkDb{bookmarks:[Bookmark];nextId:u64};
T=BmErr{FileErr:Str;ParseErr:Str;NotFound:u64};
```

## Step 2: Build the store

The store module handles persistence and CRUD operations:

`bm/store.tk`:

```
M=bm.store;
I=file:std.file;
I=json:std.json;
I=str:std.str;
I=m:bm.model;

F=dbPath():Str{
  <"bookmarks.json";
};

F=load():m.BookmarkDb!m.BmErr{
  if(!file.exists(dbPath())){
    <m.BookmarkDb{bookmarks:[];nextId:1};
  };
  let content=file.read(dbPath())!m.BmErr;
  let db=json.dec(content)!m.BmErr;
  <db;
};

F=save(db:m.BookmarkDb):void!m.BmErr{
  let data=json.pretty(db);
  file.write(dbPath();data)!m.BmErr;
};

F=add(db:m.BookmarkDb;url:Str;title:Str;tags:[Str]):m.BookmarkDb{
  let bm=m.Bookmark{
    id:db.nextId;
    url:url;
    title:title;
    tags:tags
  };
  let newBookmarks=db.bookmarks.push(bm);
  <m.BookmarkDb{
    bookmarks:newBookmarks;
    nextId:db.nextId+1
  };
};

F=delete(db:m.BookmarkDb;id:u64):m.BookmarkDb!m.BmErr{
  let found=mut.false;
  let result=mut.[];
  lp(let i=0;i<db.bookmarks.len;i=i+1){
    if(db.bookmarks[i].id=id){
      found=true;
    }el{
      result=result.push(db.bookmarks[i]);
    };
  };
  if(!found){
    <m.BmErr{NotFound:id};
  };
  <m.BookmarkDb{
    bookmarks:result;
    nextId:db.nextId
  };
};

F=search(db:m.BookmarkDb;query:Str):[m.Bookmark]{
  let q=str.lower(query);
  let result=mut.[];
  lp(let i=0;i<db.bookmarks.len;i=i+1){
    let bm=db.bookmarks[i];
    let matched=mut.false;
    if(str.contains(str.lower(bm.url);q)){
      matched=true;
    };
    if(str.contains(str.lower(bm.title);q)){
      matched=true;
    };
    lp(let j=0;j<bm.tags.len;j=j+1){
      if(str.contains(str.lower(bm.tags[j]);q)){
        matched=true;
      };
    };
    if(matched){
      result=result.push(bm);
    };
  };
  <result;
};
```

Let's walk through the key functions:

- **`load`** checks if the file exists. If not, it returns an empty database with `nextId` starting at 1. Otherwise, it reads and parses the JSON file.
- **`save`** encodes the database as pretty-printed JSON and writes it to disk.
- **`add`** creates a new `Bookmark` with the next available ID, appends it to the array, and increments the counter. Note that this returns a new `BookmarkDb` -- data structures are not mutated in place.
- **`delete`** iterates through bookmarks, skipping the one to delete. If not found, it returns a `NotFound` error.
- **`search`** does a case-insensitive search across URL, title, and tags.

## Step 3: Wire up the CLI

The main module handles argument parsing and dispatches to the store:

`bm/main.tk`:

```
M=bm.main;
I=io:std.io;
I=str:std.str;
I=store:bm.store;
I=m:bm.model;

F=printBookmark(bm:m.Bookmark):void{
  let tagsStr=str.join(bm.tags;", ");
  io.println("  [\(bm.id as Str)] \(bm.title)");
  io.println("      \(bm.url)");
  if(bm.tags.len>0){
    io.println("      tags: \(tagsStr)");
  };
};

F=printBookmarks(bms:[m.Bookmark]):void{
  if(bms.len=0){
    io.println("  (no bookmarks)");
  }el{
    lp(let i=0;i<bms.len;i=i+1){
      printBookmark(bms[i]);
    };
  };
};

F=cmdAdd(url:Str;title:Str;tagStr:Str):void{
  store.load()|{
    Ok:db  {
      let tags=str.split(tagStr;",");
      let cleanTags=mut.[];
      lp(let i=0;i<tags.len;i=i+1){
        let t=str.trim(tags[i]);
        if(str.len(t)>0){
          cleanTags=cleanTags.push(t);
        };
      };
      let updated=store.add(db;url;title;cleanTags);
      store.save(updated)|{
        Ok:v   io.println("Added bookmark");
        Err:e  io.println("Error saving")
      };
    };
    Err:e  io.println("Error loading database: \(e as Str)");
  };
};

F=cmdList():void{
  store.load()|{
    Ok:db  {
      io.println("Bookmarks (\(db.bookmarks.len as Str) total):");
      printBookmarks(db.bookmarks);
    };
    Err:e  io.println("Error: \(e as Str)");
  };
};

F=cmdSearch(query:Str):void{
  store.load()|{
    Ok:db  {
      let results=store.search(db;query);
      io.println("Search results for \"\(query)\" (\(results.len as Str) found):");
      printBookmarks(results);
    };
    Err:e  io.println("Error: \(e as Str)");
  };
};

F=cmdDelete(idStr:Str):void{
  store.load()|{
    Ok:db  {
      let id=str.toInt(idStr) as u64;
      store.delete(db;id)|{
        Ok:updated  {
          store.save(updated)|{
            Ok:v   io.println("Deleted bookmark");
            Err:e  io.println("Error saving")
          };
        };
        Err:e  e|{
          NotFound:n   io.println("Bookmark not found");
          FileErr:msg  io.println("File error");
          ParseErr:msg io.println("Parse error")
        }
      };
    };
    Err:e  io.println("Error: \(e as Str)");
  };
};

F=usage():void{
  io.println("bm - bookmark manager");
  io.println("");
  io.println("Usage:");
  io.println("  bm add <url> <title> [tags]    Add a bookmark (tags: comma-separated)");
  io.println("  bm list                        List all bookmarks");
  io.println("  bm search <query>              Search bookmarks");
  io.println("  bm delete <id>                 Delete a bookmark by ID");
};

F=main():i64{
  io.println("bm - Interactive bookmark manager");
  io.println("Commands: add, list, search, delete, quit");
  io.println("");

  lp(let run=mut.true;run;run=run){
    io.print("bm> ");
    let input=str.trim(io.readline());

    if(str.startsWith(input;"add ")){
      let rest=str.slice(input;4;str.len(input)-4);
      let parts=str.split(rest;" ");
      if(parts.len<2){
        io.println("Usage: add <url> <title> [tags]");
      }el{
        let url=parts[0];
        let title=parts[1];
        let tags="";
        if(parts.len>2){
          tags=parts[2];
        };
        cmdAdd(url;title;tags);
      };
    }el{
      if(input="list"){
        cmdList();
      }el{
        if(str.startsWith(input;"search ")){
          let query=str.slice(input;7;str.len(input)-7);
          cmdSearch(query);
        }el{
          if(str.startsWith(input;"delete ")){
            let idStr=str.slice(input;7;str.len(input)-7);
            cmdDelete(idStr);
          }el{
            if(input="quit"){
              run=false;
            }el{
              if(str.len(input)>0){
                io.println("Unknown command. Try: add, list, search, delete, quit");
              };
            };
          };
        };
      };
    };
  };

  io.println("Goodbye!");
  <0;
};
```

## Step 4: Build and run

```bash
tkc bm/model.tk bm/store.tk bm/main.tk -o bm
./bm
```

Example session:

```
bm - Interactive bookmark manager
Commands: add, list, search, delete, quit

bm> add https://toke.dev toke-website language,docs
Added bookmark [1]: toke-website
bm> add https://github.com/karwalski/toke github code,repos
Added bookmark [2]: github
bm> list
Bookmarks (2 total):
  [1] toke-website
      https://toke.dev
      tags: language, docs
  [2] github
      https://github.com/karwalski/toke
      tags: code, repos
bm> search toke
Search results for "toke" (1 found):
  [1] toke-website
      https://toke.dev
      tags: language, docs
bm> delete 1
Deleted bookmark [1]
bm> list
Bookmarks (1 total):
  [2] github
      https://github.com/karwalski/toke
      tags: code, repos
bm> quit
Goodbye!
```

## What this project demonstrates

| Concept | Where it appears |
|---------|-----------------|
| Module declarations | All three files |
| Imports | `std.file`, `std.json`, `std.str`, `std.io`, cross-module imports |
| Type declarations | `Bookmark`, `BookmarkDb`, `BmErr` |
| Functions | 12 functions across 3 modules |
| Error handling | `T!E` returns, match recovery, error variant construction |
| Collections | Arrays of bookmarks, tag arrays |
| Maps | Could extend to use maps for tag-based indexing |
| String operations | Split, join, trim, contains, startsWith, lower |
| File I/O | JSON persistence |
| JSON | Encode/decode for the bookmark database |
| Loops | Iteration over bookmarks and tags |
| Conditionals | Command routing, validation, search matching |
| Mutable bindings | Accumulators, result builders, loop control |

## Extending the project

Here are ideas if you want to keep building:

1. **Add timestamps** -- record when each bookmark was created using `std.time`
2. **Export as HTML** -- generate an HTML bookmarks file
3. **Import from browser** -- parse a browser bookmarks export
4. **HTTP API** -- wrap the store with `std.http` to serve bookmarks over HTTP
5. **Duplicate detection** -- warn when adding a URL that already exists
6. **Sort by date or title** -- implement a sorting function

## What's next

You have completed the toke training course. You now know:

- Why toke exists and the problem it solves
- The complete syntax: modules, functions, types, control flow, collections, errors
- How to use the standard library for real tasks
- How to structure multi-file projects
- How to build a complete application

### Keep going

- **[API Reference](/reference/types/)** -- detailed documentation for every type, function, and error code
- **[Standard Library Reference](/reference/stdlib/)** -- complete stdlib signatures and examples
- **[Contributing](/community/contributing/)** -- find good first issues and start contributing to toke
- **[GitHub](https://github.com/karwalski/toke)** -- browse the source for the compiler, spec, and tools

### The bigger picture

Remember: toke is designed for LLM code generation. Everything you have learned -- the compact syntax, the explicit types, the structured errors -- exists to make machine-generated code faster, cheaper, and more reliable. As you write toke, you are not just learning a language. You are learning the interface between human intent and machine execution.

Welcome to the future of generated code.
