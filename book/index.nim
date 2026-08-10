# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib

nbInit
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

## A small image without a file

The algorithms consume a `GrayscaleImage`: a width, a height, and one byte per
pixel. The following 16 by 16 image is dark on the left and bright on the
right.
"""

nbCode:
  import UniPercept

  var gradient = GrayscaleImage(
    width: 16,
    height: 16,
    pixels: newSeq[byte](16 * 16)
  )
  for y in 0 ..< gradient.height:
    for x in 0 ..< gradient.width:
      gradient.pixels[y * gradient.width + x] = byte(x * 17)

  echo gradient.width, " x ", gradient.height

nbText: """
## Four ways to summarize it

**aHash** resizes the image to 8 by 8 and compares each pixel with the mean.
Each comparison becomes one bit, hence a 64-bit result. It is fast, but two
images with similar broad light and dark regions can collide.

**dHash** resizes to 9 by 8. Each bit records whether a pixel is darker than
its neighbour to the right. It therefore emphasizes horizontal changes rather
than absolute brightness.

**pHash** resizes to 32 by 32 and applies a two-dimensional discrete cosine
transform (DCT). The low-frequency 8 by 8 corner describes broad structure;
its coefficients are compared with the mean of the non-constant coefficients.
This usually tolerates moderate resizing and recompression better than the two
simpler hashes.

**blockhash** resizes to a configurable square and compares every sample with
the mean. At its default 16 by 16 size it contains 256 bits, stored in 32
bytes.
"""

nbCode:
  let average = gradient.aHash()
  let difference = gradient.dHash()
  let perceptual = gradient.pHash()
  let blocks = gradient.blockhash()

  echo "aHash     ", toHex(average)
  echo "dHash     ", toHex(difference)
  echo "pHash     ", toHex(perceptual)
  echo "blockhash ", blocks.len, " bytes"

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
## Searching more than two images

Comparing a query with every stored hash is simple and sometimes sufficient.
A BK-tree can avoid many comparisons because Hamming distance is a metric. An
edge records the distance between two nodes; during a radius query, the
triangle inequality identifies branches that cannot contain an answer.

Performance depends on the data and radius, so a BK-tree does not promise a
fixed logarithmic running time. Its result is exact: every stored hash within
the requested radius is returned.
"""

nbCode:
  var index = initBkTree()
  index.insert(perceptual, 1)
  index.insert(other, 2)

  echo "distinct hashes ", index.len
  for (id, distance) in index.query(perceptual, radius = 0):
    echo "exact match ", id, " at distance ", distance

nbText: """
## Hashing image files

`computeHashes` decodes a file once and computes all four signatures.
`phashInfo` returns the pHash together with the decoded dimensions, which is
useful when building an index. The individual `ahash`, `dhash` and `phash`
helpers are convenient when only one signature is needed.

The same operations are available through `include/UniPercept.h` for C and
through the `unipercept` Python module. The Python distribution on PyPI is
named `UniPercept-lituus`.

## Choosing responsibly

- Use a cryptographic hash such as BLAKE3 for byte-for-byte duplicates.
- Use a perceptual hash to shortlist visually related images.
- Measure thresholds on representative examples from the real collection.
- Confirm destructive decisions by decoding or comparing the candidates.
- Store the algorithm and version beside persisted hashes, because changing a
  resize or threshold rule changes the signature.
"""

nbSave
