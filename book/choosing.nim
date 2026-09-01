# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme
import UniPercept

nbInit(theme = useNimibook)
useLituus()
nb.title = "Choosing responsibly"

nbText: """
## Choosing responsibly

- Use a cryptographic hash such as BLAKE3 for byte-for-byte duplicates.
- Use a perceptual hash to shortlist visually related images.
- Measure thresholds on representative examples from the real collection.
- Confirm destructive decisions by decoding or comparing the candidates.
- Store the algorithm and version beside persisted hashes, because changing a
  resize or threshold rule changes the signature.
"""

nbSave

nbSave
