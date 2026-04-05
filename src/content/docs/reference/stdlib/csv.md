---
title: "std.csv"
description: "Streaming CSV reader and writer with configurable delimiters."
---

**Status: Implemented** -- C runtime backing.

The `std.csv` module provides streaming CSV parsing and writing. Create a reader or writer with a custom separator, iterate rows, and extract headers.

## Types

### $csvrow

| Field | Type | Meaning |
|-------|------|---------|
| fields | @($str) | Field values for one row |

### $csvreader

Opaque streaming reader handle. Created by `csv.reader`.

### $csvwriter

Opaque streaming writer handle. Created by `csv.writer`.

### $csverr

| Field | Type | Meaning |
|-------|------|---------|
| msg | $str | Error description |
| line | u64 | Line number where the error occurred |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `csv.reader` | `data: @($byte); sep: u8` | `$csvreader` | Create a CSV reader with the given separator |
| `csv.next` | `r: $csvreader` | `$csvrow!$csverr` | Read the next row |
| `csv.header` | `r: $csvreader` | `@($str)!$csverr` | Read and return the header row |
| `csv.writer` | `sep: u8` | `$csvwriter` | Create a CSV writer with the given separator |
| `csv.writerow` | `w: $csvwriter; fields: @($str)` | `void` | Write a row of fields |
| `csv.flush` | `w: $csvwriter` | `@($byte)` | Flush the writer and return all bytes written |
| `csv.parse` | `data: @($byte)` | `@($csvrow)!$csverr` | Parse all rows at once (comma delimiter) |

## Usage

```toke
use std.csv

f=main():i64{
  let data = "name,age\nAlice,30\nBob,25".bytes
  let rows = csv.parse(data)|{Ok:r r;Err:e @()}
  (* rows.len = 2, rows.0.fields = @("name";"age") is the header *)
  <0
}
```

## Dependencies

None.
