---
title: "std.ml"
description: "Machine learning primitives: linear regression, k-means clustering, decision trees, and k-nearest neighbors."
---

**Status: Implemented** -- C runtime backing.

The `std.ml` module provides classical machine learning algorithms: multivariate linear regression, k-means clustering, decision tree classification, and k-nearest neighbors prediction.

## Types

### $row

| Field | Type | Meaning |
|-------|------|---------|
| vals | @(f64) | Feature values for one sample |

### $linearmodel

| Field | Type | Meaning |
|-------|------|---------|
| coef | @(f64) | Coefficients for each feature |
| intercept | f64 | Bias / intercept term |

### $centroid

| Field | Type | Meaning |
|-------|------|---------|
| id | u64 | Cluster identifier |
| center | @(f64) | Center coordinates |

### $kmeansmodel

| Field | Type | Meaning |
|-------|------|---------|
| centroids | @($centroid) | Cluster centroids |
| k | u64 | Number of clusters |

### $dtreemodel

Opaque handle to a trained decision tree.

### $mlerr

| Field | Type | Meaning |
|-------|------|---------|
| msg | $str | Error description |

## Functions

| Function | Parameters | Return | Description |
|----------|-----------|--------|-------------|
| `ml.linregfit` | `X: @($row); y: @(f64)` | `$linearmodel!$mlerr` | Fit a multivariate linear regression model |
| `ml.linregpredict` | `model: $linearmodel; features: @(f64)` | `f64` | Predict using a fitted linear model |
| `ml.kmeanstrain` | `data: @($row); k: u64; maxiter: u64` | `$kmeansmodel!$mlerr` | Train k-means clustering |
| `ml.kmeansassign` | `model: $kmeansmodel; point: @(f64)` | `u64` | Assign a point to the nearest cluster |
| `ml.dtreefit` | `X: @($row); labels: @($str); maxdepth: u64` | `$dtreemodel!$mlerr` | Train a decision tree classifier |
| `ml.dtreepredict` | `model: $dtreemodel; features: @(f64)` | `$str` | Predict a class label |
| `ml.knnpredict` | `data: @($row); labels: @($str); point: @(f64); k: u64` | `$str` | Predict using k-nearest neighbors |

## Usage

```toke
use std.ml

f=main():i64{
  let X = @(
    ml.$row{vals=@(1.0; 2.0)}
    ml.$row{vals=@(2.0; 3.0)}
    ml.$row{vals=@(3.0; 5.0)}
  )
  let y = @(5.0; 8.0; 13.0)
  let model = ml.linregfit(X; y)|{Ok:m m;Err:e <1}
  let pred = ml.linregpredict(model; @(4.0; 6.0))
  <0
}
```

## Dependencies

- `std.dataframe` -- row-oriented data types.
- `std.math` -- numerical primitives.
