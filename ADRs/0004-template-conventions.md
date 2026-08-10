<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0004: UniPercept conventions

- Status: Accepted
- Date: 2026-07-27
- Scope: UniPercept and the conventions inherited from UniTemplate

## Layout

```text
UniPercept.nimble          package + tasks
config.nims                package-root build path
vgraph.cfg                 layers gray<resize<hashes<decode<c_api, engines=[UniImage]
src/UniPercept.nim         umbrella (file helpers, toHex, version)
src/UniPercept/gray.nim    grayscale (fixed-point luma) — pure
src/UniPercept/resize.nim  grayscale box resize (fixed-point) — pure, imports gray
src/UniPercept/hashes.nim  aHash/dHash/pHash/blockhash + hamming — imports gray+resize
src/UniPercept/decode.nim  UniImage-backed decode — the only UniImage importer
src/UniPercept/c_api.nim   C ABI (up_*)
include/UniPercept.h       hand-written C header
tests/ tests/c/            Nim + C ABI tests
examples/                  Nim + C demos
py/                        Cython binding + pytest
book/                      nimib book
ADRs/                      0001–0004
.github/workflows/ci.yml   3-OS Nim + C ABI + Python
LICENSE NOTICE CONTRIBUTING.md SECURITY.md .gitignore README.md AGENTS.md CLAUDE.md
```

## Naming

- Nim package/module: `UniPercept` (PascalCase).
- C library: `libUniPercept`. C header: `UniPercept.h`.
- C symbol prefix: `up_` (family §6 fixed table).

## Conventions

- NimContracts `{.contractual.}` + `require:`/`ensure:`/`body:`, compiled away
  under `-d:release`. The C ABI never raises — it maps errors to `UP_*` codes.
- A postcondition is cheaper than the body; it never re-derives the result.
- English comments, terse, describe what is done. No "deprecated".
- The grayscale + resize + hash kernels preserve the earlier fixed-point
  implementation: hash values are deterministic across CPUs, the engine's
  reason to exist. UniImage is used only for decode.
- Internal layers never climb: `gray < resize < hashes < decode < c_api`.

## CI gates

- `nimble testCi` + `testCiRelease` on ubuntu/macOS/Windows.
- `nimble ctest` on linux/macOS/Windows.
- Python build, tests and wheel on Linux/macOS/Windows.
- Installed C archive and wheel consumption on all three systems.
- Release wheels for CPython 3.9–3.14, sdist, GitHub release and PyPI.
