# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme
import UniPercept

nbInit(theme = useNimibook)
useLituus()
nb.title = "Hashing image files"

nbText: """
## Hashing image files

`computeHashes` decodes a file once and computes all four signatures.
`phashInfo` returns the pHash together with the decoded dimensions, which is
useful when building an index. The individual `ahash`, `dhash` and `phash`
helpers are convenient when only one signature is needed.

The same operations are available through `include/UniPercept.h` for C and
through the `unipercept` Python module. The Python distribution on PyPI is
named `UniPercept-lituus`.
"""

nbSave
