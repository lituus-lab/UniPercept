# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Grayscale box resize, integer-only, 16.16 fixed-point coordinate mapping.
## Pure: imports only `gray`. Preserves the legacy implementation — the
## fixed-point path is what makes hashes deterministic across CPUs, so
## UniImage's float resize is never used here.
import UniPercept/gray

proc resize*(img: GrayscaleImage; newWidth, newHeight: int): GrayscaleImage =
  ## Box-filter resize of a grayscale image to `newWidth` x `newHeight`.
  result.width = newWidth
  result.height = newHeight
  result.pixels = newSeq[byte](newWidth * newHeight)

  if img.width == 0 or img.height == 0 or newWidth <= 0 or newHeight <= 0: return

  let xStep = (img.width shl 16) div newWidth
  let yStep = (img.height shl 16) div newHeight

  var yFixed = 0
  for y in 0 ..< newHeight:
    let srcY = yFixed shr 16
    let nextYFixed = yFixed + yStep
    let nextSrcY = nextYFixed shr 16

    var xFixed = 0
    for x in 0 ..< newWidth:
      let srcX = xFixed shr 16
      let nextXFixed = xFixed + xStep
      let nextSrcX = nextXFixed shr 16

      var sum = 0'u32
      var count = 0'u32

      for sy in srcY ..< min(nextSrcY, img.height):
        for sx in srcX ..< min(nextSrcX, img.width):
          sum += img.pixels[sy * img.width + sx]
          count += 1

      if count > 0:
        result.pixels[y * newWidth + x] = byte(sum div count)
      elif srcX < img.width and srcY < img.height:
        result.pixels[y * newWidth + x] = img.pixels[srcY * img.width + srcX]

      xFixed = nextXFixed
    yFixed = nextYFixed
