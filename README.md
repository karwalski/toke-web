# toke-website

This is the source code for [tokelang.dev](https://tokelang.dev), the official website for the toke programming language. It contains all documentation, tutorials, and reference material for toke. The site is built using ooke, toke's native web framework, and compiles to a single binary that serves the site over HTTPS.

## Website sections

- **Getting started** -- installation, hello world, project setup
- **Tutorials** -- step-by-step guides covering modules, control flow, collections, strings, error handling, and more
- **Language reference** -- syntax, semantics, and type system
- **Stdlib reference** -- standard library module documentation
- **Compiler guide** -- how tkc works, LLVM IR output, linking
- **Cookbook** -- real-world recipes (REST APIs, data pipelines, doc pipelines)
- **About / Design decisions** -- ADRs, design philosophy, ecosystem overview

## Local development

You need the toke compiler (`tkc`) on your PATH.

```bash
# Generate self-signed TLS certs for local dev
make certs

# Compile and run the site server
make run
```

The server will start on `https://staging.tokelang.dev:443` (you may need a `/etc/hosts` entry pointing `staging.tokelang.dev` to `127.0.0.1`).

For plain HTTP on port 9080:

```bash
make run-http
```

## Content structure

```
main.tk            # Server entry point (ooke app)
ooke.toml          # Site configuration
pages/             # Route handlers (.tk files, file-based routing)
templates/         # Page templates (.tkt files)
sites/             # Static site files served by virtual host
static/            # CSS and other static assets
scripts/           # Deployment and validation scripts
.github/           # CI workflow (placeholder until tkc is on public registry)
```

## Deploying

The deploy script cross-compiles for Linux and deploys to a remote server:

```bash
TOKE_DEPLOY_HOST=your.host \
TOKE_DEPLOY_KEY=~/.ssh/your-key.pem \
./scripts/deploy.sh
```

This emits LLVM IR locally, rsyncs it to the server, compiles a native binary with clang, and restarts the service. See `scripts/deploy.sh` for details.

## Related repositories

- [toke](https://github.com/karwalski/toke) -- the toke language compiler and standard library (also the source of truth for the docs this site serves)
- [toke-ooke](https://github.com/karwalski/toke-ooke) -- ooke web framework
- [toke-corpus](https://github.com/karwalski/toke-corpus) -- training-data generation for toke code models
- [toke-model](https://github.com/karwalski/toke-models) -- model training and adapter merging
- [toke-tokenizer](https://github.com/karwalski/toke-tokenizer) -- custom toke tokenizer

## License

MIT -- see [LICENSE](LICENSE).
