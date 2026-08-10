# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib

nbInit
nb.title = "UniPercept"

nbText: """
# UniPercept

Perceptual image hashing for the `lituus-lab` Uni* family. UniPercept wraps
`UniImage` for decode and layers the fixed-point grayscale + resize + hash
kernels that make hashes deterministic across CPUs: `aHash`, `dHash`, `pHash`,
and `blockhash`, plus Hamming distance and similarity.

This page is a nimib book: every Nim block below is compiled and run when the
book is built, and the output shown is what the code actually produced.

## Version

"""

nbCode:
  import UniPercept

  echo "version ", UniPerceptVersion

nbText: """
## Hashing a grayscale image

The kernels take a `GrayscaleImage` directly, so a caller can hash a synthetic
image without going through decode. Here a 16x16 horizontal gradient (column
`x` holds `x * 17`) is hashed with all four algorithms.
"""

nbCode:
  var img: GrayscaleImage
  img.width = 16
  img.height = 16
  img.pixels = newSeq[byte](16 * 16)
  for y in 0 ..< 16:
    for x in 0 ..< 16:
      img.pixels[y * 16 + x] = byte(x * 17)

  echo "aHash  ", toHex(img.aHash())
  echo "dHash  ", toHex(img.dHash())
  echo "pHash  ", toHex(img.pHash())
  echo "block  ", toHex(img.blockhash())

nbText: """
## Comparing hashes

`hammingDistance` is the popcount of the XOR of two hashes; `similarity` maps
it onto [0, 1] (1.0 for identical). A hash compared with itself is at distance
0 and similarity 1.0.
"""

nbCode:
  let a = img.aHash()
  echo "hamming(a, a)  ", hammingDistance(a, a)
  echo "similarity    ", similarity(a, a)

nbText: """
## Decode, C ABI, and Python

Decode is `UniImage`'s job: `loadImage(path)` / `loadImageFromMemory(buffer)`
return an 8-bit `Image`, and `computeHashes(path)` wires decode -> gray ->
hashes in one call. The Nim-only `phashInfo(path)` reuses that decode to return
pHash plus source width and height; indexers should not decode again merely to
obtain dimensions. The hash-only `phash(path)` remains compatible.

Hashing and decoded-image operations are exposed to C through the `up_*` ABI
(`include/UniPercept.h`) and to Python through the `unipercept` wheel — see
`examples/c/demo.c` and `py/notebooks/quickstart.ipynb` for runnable examples
in those languages.
"""

nbSave
