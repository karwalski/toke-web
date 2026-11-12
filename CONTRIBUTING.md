# Contributing to toke-website

Thank you for your interest in contributing to the toke website.

## Getting started

1. Fork the repository
2. Clone your fork locally
3. Install the toke compiler (`tkc`) -- see [toke](https://github.com/karwalski/toke) for instructions
4. Run `make certs` to generate local TLS certificates
5. Run `make run` to start the development server

## What to contribute

- Corrections to the site's own pages (`templates/`, `static/`, `sites/`)
- Documentation improvements and corrections -- in the
  [toke](https://github.com/karwalski/toke) repository's `docs/`, not here:
  `content/docs/` is a generated copy (`make docs-content`) and
  `make check-docs-content` fails if it is edited by hand
- New tutorials or cookbook recipes
- Bug fixes in templates or styling
- Accessibility improvements

## Pull requests

- Keep changes focused -- one topic per PR
- Run `make ci` before submitting; it is what the CI workflow runs (see the
  Checks table in the [README](README.md))
- Write clear commit messages describing the change
- Sign off every commit (`git commit -s`): the project uses the Developer
  Certificate of Origin, not a CLA -- see
  [`LICENSING.md`](https://github.com/karwalski/toke/blob/main/LICENSING.md)
- Every number published about toke comes from
  [`docs/metrics-baseline.md`](https://github.com/karwalski/toke/blob/main/docs/metrics-baseline.md);
  a figure that is not there is not published

## Code of conduct

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## Questions?

Open an issue on GitHub if you have questions or need help.
