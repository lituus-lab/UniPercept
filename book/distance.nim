# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme
import UniPercept

nbInit(theme = useNimibook)
useLituus()
nb.title = "Measuring a difference"

nbText: """
## Measuring a difference

For two 64-bit hashes, the Hamming distance counts positions where the bits
differ. It is the number of set bits in their XOR:

```
distance(a, b) = popcount(a XOR b)
```

The distance ranges from 0 to 64. UniPercept also maps it linearly to a
similarity between 0 and 1. This score is convenient, but it is not a
probability and no universal threshold works for every image collection.
"""

nbText: """
The image is the gradient from *Four ways to summarize an image*. Each chapter
is its own program, so it is rebuilt here rather than carried over:
"""

nbCode:
  var gradient = GrayscaleImage(width: 16, height: 16,
                                pixels: newSeq[byte](16 * 16))
  for y in 0 ..< gradient.height:
    for x in 0 ..< gradient.width:
      gradient.pixels[y * gradient.width + x] = byte(x * 17)
  let average = gradient.aHash()
  let difference = gradient.dHash()
  let perceptual = gradient.pHash()

nbCode:
  var reversed = gradient
  reversed.pixels = gradient.pixels
  for y in 0 ..< reversed.height:
    for x in 0 ..< reversed.width:
      reversed.pixels[y * reversed.width + x] = byte((15 - x) * 17)

  let other = reversed.pHash()
  echo "distance   ", hammingDistance(perceptual, other)
  echo "self score ", similarity(perceptual, perceptual)

nbText: """
"""

nbSave
