---
title: Project Repositories
description: The toke project's multi-repo structure, with descriptions, status, and links for each repository.
---

The toke project is split across multiple repositories under the [karwalski](https://github.com/karwalski/toke) GitHub organisation. Each repository has independent licensing and versioning. Changes that cross repository boundaries require coordinated pull requests.

## toke

**Meta-repository.** Project landing page, cross-repo issue tracking, and overall status dashboard.

- **Status:** Active
- **License:** MIT
- **Link:** [github.com/karwalski/toke](https://github.com/karwalski/toke)

## tkc

**Reference compiler.** The toke compiler, written in C. Produces LLVM IR from toke source. Includes the conformance test suite (62 tests across lexer, grammar, and diagnostics) and project documentation. Self-contained native binary with no runtime dependencies.

- **Status:** Active -- Phase 1 milestone M1 (reference compiler) complete
- **License:** Apache 2.0
- **Link:** [github.com/karwalski/tkc](https://github.com/karwalski/tkc)

## toke-spec

**Language specification.** The normative grammar (`grammar.ebnf`), character set definitions for the legacy and default syntax profiles, keyword table, symbol assignment rules, and legacy-to-default transformation rules. The RFC draft lives here.

- **Status:** Active -- specification locked at milestone M0
- **License:** MIT
- **Link:** [github.com/karwalski/toke-spec](https://github.com/karwalski/toke-spec)

## toke-stdlib

**Standard library.** C implementations of standard library functions with `.toki` interface files that the compiler consumes. Covers I/O, strings, math, collections, and error types.

- **Status:** Active -- milestone M2 (standard library core) complete
- **License:** MIT
- **Link:** [github.com/karwalski/toke-stdlib](https://github.com/karwalski/toke-stdlib)

## toke-corpus

**Corpus generation pipeline.** Python-based pipeline that generates validated (task description, toke source) pairs for model fine-tuning. Includes the monitoring console, sandbox execution harness, and parallel differential testing infrastructure.

- **Status:** Blocked -- awaiting Mac Studio hardware provisioning (Epic 1.4)
- **License:** Apache 2.0
- **Link:** [github.com/karwalski/toke-corpus](https://github.com/karwalski/toke-corpus)

## toke-tokenizer

**Purpose-built BPE tokenizer.** A tokenizer trained on the toke corpus, designed for the default syntax character profile. Optimises token boundaries for toke's syntax patterns so that common constructs like `$user`, `$str`, and `@(` merge into single vocabulary entries.

- **Status:** Not started -- depends on corpus generation (Epic 1.5)
- **License:** Apache 2.0
- **Link:** [github.com/karwalski/toke-tokenizer](https://github.com/karwalski/toke-tokenizer)

## toke-benchmark

**Evaluation benchmark suite.** A held-out set of 500 benchmark tasks with gate measurement scripts. Used to evaluate Pass@1 rates and token efficiency at each project gate.

- **Status:** Active -- task set defined, gate measurement pending
- **License:** Apache 2.0
- **Link:** [github.com/karwalski/toke-benchmark](https://github.com/karwalski/toke-benchmark)

## toke-model (planned)

**Model training infrastructure.** QLoRA fine-tuning scripts, training data preparation pipeline, and model evaluation harness. Handles base model selection, training configuration, and checkpoint management.

- **Status:** Planned -- depends on corpus and tokenizer completion
- **License:** Apache 2.0
- **Link:** github.com/karwalski/toke-model (not yet available)

## toke-eval (planned)

**Evaluation pipeline.** Pass@1 and token-efficiency evaluation scripts that run generated toke programs against the benchmark suite and measure gate criteria.

- **Status:** Planned -- repository not yet created
- **License:** Apache 2.0
- **Link:** github.com/karwalski/toke-eval (not yet available)

## toke-web

**This website.** The public-facing documentation site for the toke language, built with Astro Starlight.

- **Status:** Active
- **License:** MIT
- **Link:** [github.com/karwalski/toke-web](https://github.com/karwalski/toke-web)

---

## Dependency Order

When a change in one repository affects another, the downstream repository must be updated. The critical dependency chains:

| If you change... | Then update... |
|---|---|
| `toke-spec` grammar | `tkc` conformance tests |
| `toke-spec` error definitions | `tkc` diagnostic implementation + tests |
| `toke-spec` stdlib signatures | `toke-stdlib` source files |
| `tkc` diagnostic schema | `toke-corpus` pipeline consumers |
| `toke-corpus` schema | `toke-model` data preparation scripts |
| `toke-benchmark` task schema | evaluation harness + `toke-corpus` differential testing |

The general rule: open the downstream PR first, merge the downstream PR last.
