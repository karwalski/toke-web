---
title: "std.math"
description: "Numeric functions: aggregation, statistics, linear regression, and basic arithmetic."
---

**Status: Implemented** -- C runtime backing.

The `std.math` module provides numeric utility functions covering aggregation, descriptive statistics, simple linear regression, and standard math operations.

## Types

### $linregresult

| Field | Type | Meaning |
|-------|------|---------|
| slope | f64 | Slope of the regression line |
| intercept | f64 | Y-intercept |
| r2 | f64 | R-squared goodness of fit |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `math.sum` | `vals: @(f64)` | `f64` | Sum of all values |
| `math.mean` | `vals: @(f64)` | `f64` | Arithmetic mean |
| `math.median` | `vals: @(f64)` | `f64` | Median value |
| `math.stddev` | `vals: @(f64)` | `f64` | Standard deviation |
| `math.variance` | `vals: @(f64)` | `f64` | Variance |
| `math.percentile` | `vals: @(f64); p: f64` | `f64` | P-th percentile (0.0--1.0) |
| `math.linreg` | `x: @(f64); y: @(f64)` | `$linregresult` | Simple linear regression |
| `math.min` | `vals: @(f64)` | `f64` | Minimum value |
| `math.max` | `vals: @(f64)` | `f64` | Maximum value |
| `math.abs` | `v: f64` | `f64` | Absolute value |
| `math.sqrt` | `v: f64` | `f64` | Square root |
| `math.floor` | `v: f64` | `i64` | Floor (round toward negative infinity) |
| `math.ceil` | `v: f64` | `i64` | Ceiling (round toward positive infinity) |
| `math.pow` | `base: f64; exp: f64` | `f64` | Raise base to exponent |

## Usage

```toke
use std.math

f=main():i64{
  let data = @(10.0; 20.0; 30.0; 40.0; 50.0)
  let avg = math.mean(data)          (* 30.0 *)
  let sd = math.stddev(data)         (* ~14.14 *)
  let p90 = math.percentile(data; 0.9)
  <0
}
```

## Dependencies

None.
