---
title: "std.dataframe"
description: "Columnar data frames: load from CSV, filter, group, join, and export."
---

**Status: Implemented** -- C runtime backing.

The `std.dataframe` module provides a columnar data frame for tabular data processing. Load data from CSV bytes or row arrays, then filter, group, join, slice, and export.

## Types

### $dataframe

Opaque handle to a columnar data frame.

### $series

| Field | Type | Meaning |
|-------|------|---------|
| name | $str | Column name |
| dtype | $str | Data type (`"f64"`, `"str"`, `"u64"`) |
| len | u64 | Number of values |

### $dfshape

| Field | Type | Meaning |
|-------|------|---------|
| rows | u64 | Row count |
| cols | u64 | Column count |

### $dferr

| Field | Type | Meaning |
|-------|------|---------|
| msg | $str | Error description |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `df.fromcsv` | `data: @($byte)` | `$dataframe!$dferr` | Load a data frame from CSV bytes (first row = headers) |
| `df.fromrows` | `cols: @($str); rows: @($csvrow)` | `$dataframe` | Build a data frame from column names and row arrays |
| `df.column` | `d: $dataframe; name: $str` | `@(f64)!$dferr` | Extract a numeric column as an array |
| `df.columnstr` | `d: $dataframe; name: $str` | `@($str)!$dferr` | Extract a string column as an array |
| `df.filter` | `d: $dataframe; col: $str; op: $str; val: $str` | `$dataframe!$dferr` | Filter rows where `col op val` (ops: `"="`, `"!="`, `">"`, `"<"`, `">="`, `"<="`) |
| `df.groupby` | `d: $dataframe; col: $str` | `@($dataframe)!$dferr` | Split into groups by distinct values in a column |
| `df.join` | `left: $dataframe; right: $dataframe; on: $str` | `$dataframe!$dferr` | Inner join two data frames on a shared column |
| `df.head` | `d: $dataframe; n: u64` | `$dataframe` | Take the first n rows |
| `df.shape` | `d: $dataframe` | `$dfshape` | Get the row and column counts |
| `df.tojson` | `d: $dataframe` | `@($byte)!$dferr` | Serialize to JSON bytes |
| `df.tocsv` | `d: $dataframe` | `@($byte)` | Serialize to CSV bytes |
| `df.schema` | `d: $dataframe` | `@($series)` | Get column metadata |

## Usage

```toke
use std.dataframe
use std.file

f=main():i64{
  let raw = file.read("sales.csv")|{Ok:d d;Err:e <1}
  let data = df.fromcsv(raw)|{Ok:d d;Err:e <1}
  let filtered = df.filter(data; "region"; "="; "APAC")|{Ok:d d;Err:e <1}
  let revenue = df.column(filtered; "revenue")|{Ok:v v;Err:e @()}
  <0
}
```

## Dependencies

- `std.csv` -- CSV parsing for `df.fromcsv` and row types.
