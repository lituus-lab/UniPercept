<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0003: Native engine and foreign façades

- Status: Accepted
- Date: 2026-07-15
- Scope: UniPercept

## Decision

- **Engine** (pure Nim): the library + a thin C ABI (`src/UniPercept/c_api.nim`),
  built `--app:staticlib`/`--app:lib --noMain --mm:arc -d:release` →
  `libUniPercept.a` / `libUniPercept.so`. No UI in the engine.
- Applications link the C ABI or use the Python package; user interfaces stay
  outside this engine.
- **C header** (`include/UniPercept.h`): hand-written, kept in sync with
  `src/UniPercept/c_api.nim`.
  `tests/c` links the header against the lib — a renamed/retyped symbol fails
  to link, so the C test is the ABI drift detector. (`--header:X.h` auto-gen is
  not used.)
- `--mm:arc` provides deterministic ownership for foreign callers. `--noMain`
  suppresses the executable entry point; C callers still invoke `up_init()`
  before any other ABI function so the Nim runtime is initialized.
- **Python binding**: Cython over the shared lib, RPATH `$ORIGIN`.
