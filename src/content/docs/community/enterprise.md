---
title: Enterprise Adoption
description: How toke reduces LLM inference costs by 60-80% for enterprise code generation pipelines.
---

## The Value Proposition

Every token an LLM generates costs compute time and API dollars. When your code generation pipeline produces Python, TypeScript, or Go, the model spends tokens on verbose keywords, ambiguous syntax, and whitespace conventions that were designed for human readability -- not machine efficiency.

toke eliminates this overhead at the language level. Its 56-character set with a purpose-built tokenizer achieves maximal token density. Its strict LL(1) grammar has exactly one valid interpretation at every syntactic position. Its mandatory typed interface files compress module contracts into minimal token sequences.

The result: **LLMs generating toke instead of Python or JavaScript reduce inference costs by 60-80%** on equivalent tasks. Fewer tokens per program means faster generation, lower API bills, and higher throughput.

## Use Cases

### AI Coding Assistants

Coding assistants that generate toke produce correct programs in fewer tokens. The strict grammar eliminates entire classes of syntax errors, and the structured JSON diagnostic schema enables automated repair loops without parsing English prose.

### Automated Code Generation Pipelines

High-volume pipelines that generate, test, and deploy code benefit directly from token efficiency. Each generation pass costs less, and the deterministic grammar reduces the retry rate for invalid programs.

### Cost Optimization for High-Volume APIs

If your platform serves code generation at scale -- thousands or millions of requests per day -- switching the target language to toke reduces per-request inference cost. The savings compound at volume.

### Internal Tooling

When LLMs write and execute code for internal automation -- data transformations, report generation, workflow orchestration -- toke provides a safe, efficient target language with predictable compilation and execution behaviour.

## Integration Path

toke compiles to native code via LLVM. The compiler (`tkc`) emits LLVM IR, which clang compiles to a native binary for any target triple clang supports -- x86-64, ARM64, RISC-V, WebAssembly, and more.

```bash
# Compile a toke program to a native binary
tkc program.toke | clang -x ir - -o program

# Cross-compile for a different target
tkc --target aarch64-linux-gnu program.toke | clang -x ir - --target=aarch64-linux-gnu -o program
```

The compiler is a single self-contained binary with no runtime dependencies. It integrates into any CI/CD pipeline, container image, or build system that can invoke a command-line tool.

### Interface Files

toke's mandatory `.tokei` interface files act as compressed task descriptions for LLMs. Feed the interface file to a model as context, and it can generate a conforming implementation with minimal prompt engineering.

```bash
# Generate the interface file
tkc --emit-interface module.toke

# The .tokei file is now available as LLM context
```

### Diagnostic Integration

Compiler diagnostics are emitted as structured JSON to stderr by default. This enables automated repair loops: generate code, compile, parse the JSON diagnostics, feed errors back to the model, regenerate.

```bash
# JSON diagnostics (default) for machine consumption
tkc program.toke 2> diagnostics.json

# Human-readable diagnostics for debugging
tkc --diag-text program.toke
```

## Security

The toke compiler is built with security as a baseline requirement:

- **SAST-scanned.** Every commit is checked with cppcheck and clang-tidy. Zero error-level findings are permitted.
- **Fuzz-tested.** The compiler frontend is fuzzed to catch crashes, undefined behaviour, and memory safety issues.
- **SBOM and signed releases.** Release artifacts include a software bill of materials and cryptographic signatures.
- **No external dependencies.** The compiler frontend has zero external C library dependencies, minimising supply chain risk.
- **Responsible disclosure.** Security issues are handled through the process described in [SECURITY.md](https://github.com/karwalski/tkc/blob/main/SECURITY.md).

## Licensing

toke is released under the **MIT licence**. There are no restrictions on commercial use, modification, or distribution. You can embed the compiler in proprietary products, ship generated binaries to customers, and modify the source for internal use -- all without licence obligations beyond preserving the copyright notice.

## Support

- **[GitHub Issues](https://github.com/karwalski/tkc/issues)** -- bug reports and feature requests. The maintainers triage and respond to issues regularly.
- **[GitHub Discussions](https://github.com/karwalski/toke/discussions)** -- questions about integration, architecture decisions, and general usage.
- **[Security reports](https://github.com/karwalski/tkc/blob/main/SECURITY.md)** -- responsible disclosure for security vulnerabilities.

## Getting Started

1. **Clone and build the compiler.**

   ```bash
   git clone https://github.com/karwalski/tkc
   cd tkc
   make
   ```

2. **Run the conformance suite** to verify your build.

   ```bash
   make conform
   ```

3. **Compile a toke program** and verify the output.

   ```bash
   tkc src/hello.toke | clang -x ir - -o hello
   ./hello
   ```

4. **Integrate into your pipeline.** The `tkc` binary is a single static executable. Copy it into your container image or CI environment and invoke it as part of your code generation workflow.

5. **Feed `.tokei` interface files to your LLM** as context for code generation tasks. Measure the token reduction against your current target language.
