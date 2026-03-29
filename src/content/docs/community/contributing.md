---
title: Contributing
description: How to contribute to the toke language project -- bug reports, code, documentation, and tests.
---

## Welcome

toke is open source under the MIT licence. Contributions are welcome at all skill levels -- from fixing a typo in the docs to adding a new compiler pass. Every contribution matters.

## Ways to Contribute

### Bug Reports

Found a compiler crash, an incorrect diagnostic, or a spec inconsistency? Open an issue on the relevant repository. Include:

- The toke source that triggers the bug
- The compiler version (`tkc --version`)
- The expected behaviour and the actual behaviour
- The full diagnostic output (JSON or `--diag-text`)

### Code Contributions

Fix a bug, implement a missing feature, or improve compiler performance. All code changes require conformance tests.

### Documentation

Improve the language guide, add examples, clarify error messages, or fix inaccuracies in the specification.

### Tests

Expand the conformance suite, write edge-case tests for the lexer or parser, or add diagnostic fix-field coverage.

## Repository Overview

The toke project spans seven repositories, each with a focused role:

| Repository | Role |
|------------|------|
| [karwalski/toke](https://github.com/karwalski/toke) | Meta-repo: project landing page, cross-repo issue tracker |
| [karwalski/tkc](https://github.com/karwalski/tkc) | Reference compiler (C), standard library, conformance test suite |
| [karwalski/toke-spec](https://github.com/karwalski/toke-spec) | Language specification: grammar, character set, keyword table |
| [karwalski/toke-corpus](https://github.com/karwalski/toke-corpus) | Corpus generation pipeline, sandbox execution harness |
| [karwalski/toke-model](https://github.com/karwalski/toke-model) | Fine-tuning scripts and model evaluation harness |
| [karwalski/toke-benchmark](https://github.com/karwalski/toke-benchmark) | Held-out benchmark task set, gate measurement scripts |
| [karwalski/toke-eval](https://github.com/karwalski/toke-eval) | Pass@1 and token-efficiency evaluation pipeline |

Most contributors start with **tkc** (the compiler) or **toke-spec** (the language specification).

## Good First Issues

Look for issues labelled [`good-first-issue`](https://github.com/karwalski/tkc/labels/good-first-issue) in the tkc repository. These are scoped, well-described tasks suitable for newcomers to the codebase.

## Development Setup

### Build the compiler

Requirements: clang (any recent version), make.

```bash
git clone https://github.com/karwalski/tkc
cd tkc
make
```

The `tkc` binary is placed in the repo root. It is a self-contained native binary with no runtime dependencies.

### Run the conformance suite

```bash
make conform
```

This runs the full conformance test suite across the lexer, grammar, and diagnostic series. All tests must pass before any change is submitted.

### Run the full test suite

```bash
make test
```

### Run SAST locally

```bash
cppcheck --enable=all src/
clang-tidy src/*.c -- -std=c99 -Wall -Wextra -Wpedantic -Werror -g
```

## Code Style

- **Compiler (tkc):** C11, compiled with `-Wall -Wextra -Wpedantic -Werror`. No external C library dependencies in the compiler frontend (`src/`) without explicit approval.
- **Tooling and pipelines:** Python 3.11+.
- **Commit messages:** Conventional Commits format -- `type(scope): message`. Valid types: `feat`, `fix`, `test`, `refactor`, `docs`, `chore`, `ci`.

```
feat(typechecker): add exhaustive match enforcement E4010
fix(lexer): emit E1003 for out-of-set structural characters
test(diagnostics): add D-series fix field tests for E4020
```

## Pull Request Process

1. **Branch from main.** Use the naming convention: `feature/compiler-<description>`, `fix/lexer-<description>`, `test/typechecker-<description>`, or `refactor/parser-<description>`.
2. **Write tests.** Every change to a compiler stage requires conformance tests. New error codes require new test cases.
3. **Pass all checks.** Before opening a PR:
   - `make conform` passes 100%
   - `make lint` produces zero warnings
   - `make build-all` succeeds on x86-64 and ARM64
   - `cppcheck --enable=all src/` produces zero errors
4. **Sign your commits.** All commits must carry a `Signed-off-by` trailer (DCO). Use `git commit -s`.
5. **Describe your changes.** Explain what changed and why. Reference the relevant issue number.
6. **Update progress tracking.** Update `docs/progress.md` if your change affects milestone status.

## Rules That Are Not Negotiable

These rules apply to every contribution, no exceptions:

- Never change an existing error code number or meaning.
- Never populate the `fix` field in a diagnostic with a fix that is incorrect for any valid program triggering that error.
- Never add an external C library dependency to the compiler frontend without raising an issue and getting explicit approval.
- `make conform` must pass at 100% before any PR is merged.

## Code of Conduct

We expect all contributors to be respectful, constructive, and professional. Harassment, discrimination, and bad-faith behaviour are not tolerated. Maintainers reserve the right to remove contributions and ban participants who violate these expectations.

## Communication

- **[GitHub Issues](https://github.com/karwalski/tkc/issues)** -- bug reports, feature requests, and task tracking.
- **[GitHub Discussions](https://github.com/karwalski/toke/discussions)** -- questions, design discussions, and general conversation about the project.
- **Security issues** -- see [SECURITY.md](https://github.com/karwalski/tkc/blob/main/SECURITY.md) in the tkc repository. Do not file security issues publicly.
