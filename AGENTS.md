# AGENTS.md — UniPercept

## Build & gates

```bash
nimble install -y
nimble testAll    # Nim debug + release + C ABI
nimble pyTest     # Cython + pytest (needs libUniPercept.so)
nimble example
nimble coverage   # gcov + lcov -> coverage/ (needs lcov; linux/macOS)
nimble docs       # nimib book + API reference -> pages/ (needs nimib)
nimble checkVGraph
```

`nimble docs` needs a complete Nim distribution: `--project` builds `dochack`,
which Homebrew's `nim` omits (no `tools/`). choosenim and the CI action ship it.

CI: 3-OS Nim matrix + C ABI + Python.

## Conventions

- English comments, terse, describe what is done. No "deprecated".
- NimContracts `{.contractual.}` + `require:`/`ensure:`/`body:`, compiled away
  under `-d:release`. C ABI never raises — it maps errors to `UP_*` codes.
- A postcondition is cheaper than the body: never re-derives the result by
  calling the function itself.
- C ABI: hand-written `include/UniPercept.h` kept in sync with
  `src/UniPercept/c_api.nim`; `tests/c` links the header against the lib.
  Built `--app:staticlib`/`--app:lib --noMain --mm:arc -d:release` — **not**
  `-d:danger`: the ABI parses untrusted image bytes (via UniImage), so Nim's
  bounds checks are kept as defense-in-depth and `CatchableError`/`Defect` are
  trapped at the boundary.
- C symbols `up_*`; lib `libUniPercept`; header `UniPercept.h`.
- Layers `gray < resize < hashes < decode < c_api`, enforced by
  `nimble checkVGraph`. `gray`/`resize`/`hashes` are pure (no UniImage import);
  `decode` is the only layer that imports `UniImage`. The facade wires
  `decode -> gray -> hashes`.
- The grayscale + resize + hash kernels preserve the earlier fixed-point
  implementation for cross-CPU determinism. UniImage's float resize is NOT
  used in the hash pipeline — it would change every hash value.
- `book/index.nim` is nimib: its code blocks are compiled and run at docs build,
  so prose that outlives its API breaks the build. `py/notebooks/quickstart.ipynb`
  plays the same role for Python and renders natively on GitHub.
- Coverage ignores only Nim 2.2's empty imported-module (`gcov`) and synthetic
  line-after-EOF (`range`) mapping cases. Source and I/O errors remain fatal.

## Scope

Public engine repo of the `lituus-lab` family, above `UniImage` in the
dependency DAG (its only engine edge). Migrated from the author's earlier
Apache-2.0 implementation; its decoder FFI is replaced by UniImage decode.
No codec, no parallelism, no float resize in the hash pipeline (see README
anti-goals). Apache-2.0, DCO.
