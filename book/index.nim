# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme
import UniPercept

nbInit(theme = useNimibook)
useLituus()
nb.title = "UniPercept"

nbText: """
# Understanding perceptual image hashes

A cryptographic hash changes dramatically when one input byte changes. That is
ideal for integrity checks, but it is inconvenient when a resized or
recompressed photograph should still be recognized.

A **perceptual hash** instead summarizes visible structure. Similar pictures
often produce hashes separated by only a few bits. This makes the hash useful
for finding candidates, but not for proving that two files or pictures are
identical.

UniPercept provides aHash, dHash, pHash and blockhash. Its image decoder comes
from UniImage; its grayscale, resize and hash kernels use deterministic integer
arithmetic so the same input produces the same stored signature on supported
CPUs.
"""

nbSave
