# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import UniPercept

# 16x16 horizontal gradient: column x holds x*17 (0..255).
var img: GrayscaleImage
img.width = 16
img.height = 16
img.pixels = newSeq[byte](16 * 16)
for y in 0 ..< 16:
  for x in 0 ..< 16:
    img.pixels[y * 16 + x] = byte(x * 17)

echo "UniPercept " & UniPerceptVersion
echo "aHash  ", toHex(img.aHash())
echo "dHash  ", toHex(img.dHash())
echo "pHash  ", toHex(img.pHash())
echo "block  ", toHex(img.blockhash())
