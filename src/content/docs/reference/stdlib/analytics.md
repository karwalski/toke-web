---
title: "std.analytics"
description: "Descriptive statistics, group aggregation, time series analysis, anomaly detection, pivoting, and correlation."
---

**Status: Implemented** -- C runtime backing.

The `std.analytics` module provides higher-level analytical functions on data frames: summary statistics, grouped aggregation, time series with rolling averages, anomaly detection, pivot tables, and pairwise correlation.

## Types

### $statsrow

| Field | Type | Meaning |
|-------|------|---------|
| col | $str | Column name |
| count | u64 | Number of non-null values |
| mean | f64 | Arithmetic mean |
| stddev | f64 | Standard deviation |
| min | f64 | Minimum value |
| p25 | f64 | 25th percentile |
| p50 | f64 | 50th percentile (median) |
| p75 | f64 | 75th percentile |
| max | f64 | Maximum value |

### $groupstat

| Field | Type | Meaning |
|-------|------|---------|
| group | $str | Group key value |
| count | u64 | Number of rows in the group |
| sum | f64 | Sum of the aggregation column |
| mean | f64 | Mean of the aggregation column |

### $tspoint

| Field | Type | Meaning |
|-------|------|---------|
| ts | u64 | Timestamp (Unix epoch) |
| value | f64 | Raw value |
| rolling_mean | f64 | Rolling average at this point |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `analytics.describe` | `d: $dataframe` | `@($statsrow)!$dferr` | Compute summary statistics for all numeric columns |
| `analytics.groupstats` | `d: $dataframe; groupcol: $str; valuecol: $str` | `@($groupstat)!$dferr` | Aggregate a value column by group |
| `analytics.timeseries` | `d: $dataframe; tscol: $str; valuecol: $str; window: u64` | `@($tspoint)!$dferr` | Build a time series with rolling mean |
| `analytics.anomalies` | `d: $dataframe; col: $str; threshold: f64` | `@(u64)!$dferr` | Detect anomaly row indices (values beyond threshold standard deviations) |
| `analytics.pivot` | `d: $dataframe; rowcol: $str; colcol: $str; valuecol: $str` | `$dataframe!$dferr` | Create a pivot table |
| `analytics.corr` | `d: $dataframe; col_a: $str; col_b: $str` | `f64!$dferr` | Compute Pearson correlation between two columns |

## Usage

```toke
use std.analytics
use std.dataframe

f=main():i64{
  let data = df.fromcsv(file.read("metrics.csv")|{Ok:d d;Err:e <1})|{Ok:d d;Err:e <1}
  let stats = analytics.describe(data)|{Ok:s s;Err:e @()}
  let outliers = analytics.anomalies(data; "latency"; 3.0)|{Ok:a a;Err:e @()}
  let r = analytics.corr(data; "cpu"; "memory")|{Ok:v v;Err:e 0.0}
  <0
}
```

## Dependencies

- `std.dataframe` -- data frame types and operations.
- `std.math` -- statistical primitives.
