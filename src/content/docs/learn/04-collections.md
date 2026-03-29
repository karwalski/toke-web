---
title: "Lesson 4: Collections"
description: "Work with arrays and maps — literals, indexing, common operations, and iteration patterns."
---

**Estimated time: ~25 minutes**

## Arrays

An array is an ordered, dynamically-sized sequence of elements of the same type.

### Array literals

Array literals use square brackets with semicolons separating elements:

```
let nums=[1;2;3;4;5];
let names=["Alice";"Bob";"Charlie"];
let empty=[];
```

Note the last line -- an empty array literal `[]` has element type `unknown` until constrained by context such as a type annotation or assignment.

### Array types

The type of an array is written `[T]` where `T` is the element type:

The parameter type `[Str]` denotes an array of strings. The return type `[i64]` denotes an array of integers.

```
F=process(items:[Str]):void{
};

F=makeNumbers():[i64]{
  <[10;20;30];
};
```

### Array length

Every array has a `.len` member that returns the number of elements as `u64`:

```
let arr=[1;2;3];
let size=arr.len;
```

### Indexing

Access elements by index using square brackets. Indices are zero-based:

```
let arr=[10;20;30];
let first=arr[0];
let second=arr[1];
let third=arr[2];
```

Out-of-bounds access is a runtime trap (RT001) -- the program terminates with a structured error. There is no silent undefined behaviour.

### Iterating over arrays

Use `lp` with an index variable:

```
F=printAll(arr:[Str]):void{
  lp(let i=0;i<arr.len;i=i+1){
    io.println(arr[i]);
  };
};
```

This is the standard iteration pattern in toke. There is no `for-each` or iterator protocol in v0.1.

### Building arrays

To build an array dynamically, start with an empty array and use append operations:

```
F=range(n:i64):[i64]{
  let result=mut.[];
  lp(let i=0;i<n;i=i+1){
    result=result.push(i);
  };
  <result;
};
```

## Maps

A map is an unordered collection of key-value pairs.

### Map literals

Map literals use square brackets with `key:value` pairs separated by semicolons:

```
let ages=["Alice":30;"Bob":25;"Charlie":35];
let config=["host":"localhost";"port":"8080"];
let empty=[];
```

### Map types

The type of a map is written `[K:V]` where `K` is the key type and `V` is the value type:

```
F=process(lookup:[Str:i64]):void{
};
```

### Map operations

Maps support these core operations:

#### Get a value

```
let ages=["Alice":30;"Bob":25];
let age=ages.get("Alice");
```

Accessing a key that does not exist is a runtime trap. Use `.contains` to check first.

#### Check if a key exists

```
if(ages.contains("Alice")){
  let age=ages.get("Alice");
  io.println("Alice is \(age as Str)");
};
```

#### Put a key-value pair

```
let ages=mut.["Alice":30;"Bob":25];
ages=ages.put("Charlie";35);
```

#### Delete a key

```
ages=ages.delete("Bob");
```

#### Get the size

```
let count=ages.len;
```

### Iterating over maps

To iterate over a map, retrieve its keys and iterate over that array:

```
F=printMap(m:[Str:i64]):void{
  let keys=m.keys;
  lp(let i=0;i<keys.len;i=i+1){
    let k=keys[i];
    let v=m.get(k);
    io.println("\(k): \(v as Str)");
  };
};
```

## Practical patterns

### Frequency counter

Count how many times each word appears:

```
M=freq;
I=io:std.io;

F=countFreq(words:[Str]):[Str:i64]{
  let freq=mut.[];
  lp(let i=0;i<words.len;i=i+1){
    let w=words[i];
    if(freq.contains(w)){
      let cur=freq.get(w);
      freq=freq.put(w;cur+1);
    }el{
      freq=freq.put(w;1);
    };
  };
  <freq;
};
```

### Finding a value in an array

```
F=contains(arr:[i64];target:i64):bool{
  lp(let i=0;i<arr.len;i=i+1){
    if(arr[i]=target){
      <true;
    };
  };
  <false;
};
```

Note: equality comparison in toke uses `=` (single equals) in expression context. The parser distinguishes assignment (statement position) from comparison (expression position) by context.

### Array reversal

```
F=reverse(arr:[i64]):[i64]{
  let result=mut.[];
  let i=mut.arr.len;
  lp(let x=0;i>0;x=0){
    i=i-1;
    result=result.push(arr[i]);
  };
  <result;
};
```

## Exercises

### Exercise 1: Sum and average

Write two functions:
- `F=sum(arr:[i64]):i64` -- returns the sum of all elements
- `F=average(arr:[i64]):f64` -- returns the average as a float (use `as f64` to cast the sum and length)

### Exercise 2: Frequency counter

Write a complete program with module `freq` that:
1. Takes an array of strings `["apple";"banana";"apple";"cherry";"banana";"apple"]`
2. Counts the frequency of each word using a map
3. Prints each word and its count

### Exercise 3: Array reversal

Write `F=reverse(arr:[Str]):[Str]` that returns a new array with elements in reverse order. Test it with `["a";"b";"c";"d"]`.

### Exercise 4: Merge maps

Write `F=merge(a:[Str:i64];b:[Str:i64]):[Str:i64]` that returns a new map containing all keys from both maps. If a key exists in both, use the value from `b`.

## Key takeaways

- Array literals: `[1;2;3]`, type: `[i64]`
- Map literals: `["a":1;"b":2]`, type: `[Str:i64]`
- `.len` gives the size of arrays and maps
- Array indexing: `arr[i]` (zero-based, bounds-checked)
- Map operations: `.get`, `.put`, `.delete`, `.contains`, `.keys`
- Iterate with `lp` and an index variable
- Out-of-bounds access is a runtime trap, not undefined behaviour

## Next

[Lesson 5: Error Handling](/learn/05-errors/) -- error types, propagation, and recovery.
