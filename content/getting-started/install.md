---
title: Install
slug: install
section: getting-started
order: 2
description: Build toke from source on macOS or Linux.
---

## Prerequisites

- C compiler: gcc 11+ or clang 14+
- GNU Make 3.81+
- LLVM 15+

## macOS

```bash
brew install llvm
git clone https://github.com/karwalski/toke
cd toke && make
```

## Linux (Ubuntu/Debian)

```bash
sudo apt-get install -y clang-15 llvm-15-dev
git clone https://github.com/karwalski/toke
cd toke && make
```

## Verify

```bash
./build/tkc --version
```
