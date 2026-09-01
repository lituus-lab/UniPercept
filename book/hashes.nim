# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme
import UniPercept

nbInit(theme = useNimibook)
useLituus()
nb.title = "Four ways to summarize an image"

nbText: """
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
"""

nbSave
