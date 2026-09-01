# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme
import UniPercept

nbInit(theme = useNimibook)
useLituus()
nb.title = "Searching more than two images"

nbText: """
## Searching more than two images

Comparing a query with every stored hash is simple and sometimes sufficient.
A BK-tree can avoid many comparisons because Hamming distance is a metric. An
edge records the distance between two nodes; during a radius query, the
triangle inequality identifies branches that cannot contain an answer.

Performance depends on the data and radius, so a BK-tree does not promise a
fixed logarithmic running time. Its result is exact: every stored hash within
the requested radius is returned.
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
  # The mirrored image from *Measuring a difference*, for a second hash to
  # search against.
  var reversed = gradient
  for y in 0 ..< reversed.height:
    for x in 0 ..< reversed.width:
      reversed.pixels[y * reversed.width + x] = byte((15 - x) * 17)
  let other = reversed.pHash()

nbCode:
  var index = initBkTree()
  index.insert(perceptual, 1)
  index.insert(other, 2)

  echo "distinct hashes ", index.len
  for (id, distance) in index.query(perceptual, radius = 0):
    echo "exact match ", id, " at distance ", distance

nbText: """
"""

nbSave
