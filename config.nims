# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniPercept build config. Consumes UniImage via a relative path during the
## untagged transition (family §6): once UniImage is tagged, replace this with
## `requires "https://github.com/lituus-lab/UniImage#<sha>"` in the nimble file.
## `src` is here (not just on the test tasks) so the C ABI tasks — which compile
## `src/UniPercept/c_api.nim` directly and `import UniPercept` (the facade) —
## resolve the package root without each task passing `--path:src` itself.
switch("path", "src")
switch("path", "../UniImage/src")
