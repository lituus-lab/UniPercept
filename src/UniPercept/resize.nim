# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Grayscale box resize, integer-only, 16.16 fixed-point coordinate mapping.
## Pure: imports only `gray`. Preserves the legacy implementation — the
## fixed-point path is what makes hashes deterministic across CPUs, so
## UniImage's float resize is never used here.
import UniPercept/gray
import contracts

func dimensionsFit(width, height: int): bool =
  width >= 0 and height >= 0 and
    (width == 0 or height <= high(int) div width)

func validGray(img: GrayscaleImage): bool =
  dimensionsFit(img.width, img.height) and
    img.pixels.len == img.width * img.height

proc resize*(img: GrayscaleImage; newWidth,
    newHeight: int): GrayscaleImage {.contractual.} =
  ## Box-filter resize of a grayscale image to `newWidth` x `newHeight`.
  require:
    validGray(img)
    dimensionsFit(newWidth, newHeight)
  ensure:
    result.width == newWidth
    result.height == newHeight
    result.pixels.len == newWidth * newHeight
  body:
    if not dimensionsFit(newWidth, newHeight):
      raise newException(ValueError, "resize: negative dimensions")
    if not validGray(img):
      raise newException(ValueError, "resize: inconsistent source buffer")
    let outputCount = newWidth * newHeight

    result.width = newWidth
    result.height = newHeight
    result.pixels = newSeq[byte](outputCount)

    if img.width == 0 or img.height == 0 or newWidth == 0 or newHeight == 0:
      return

    for y in 0 ..< newHeight:
      let yFixed = (int64(y) * int64(img.height) shl 16) div int64(newHeight)
      let srcY = int(yFixed shr 16)
      let nextYFixed = (int64(y + 1) * int64(img.height) shl 16) div
          int64(newHeight)
      let nextSrcY = int(nextYFixed shr 16)

      for x in 0 ..< newWidth:
        let xFixed = (int64(x) * int64(img.width) shl 16) div int64(newWidth)
        let srcX = int(xFixed shr 16)
        let nextXFixed = (int64(x + 1) * int64(img.width) shl 16) div
            int64(newWidth)
        let nextSrcX = int(nextXFixed shr 16)

        var sum = 0'u64
        var count = 0'u64

        for sy in srcY ..< min(nextSrcY, img.height):
          for sx in srcX ..< min(nextSrcX, img.width):
            sum += img.pixels[sy * img.width + sx]
            count += 1

        if count > 0:
          result.pixels[y * newWidth + x] = byte(sum div count)
        elif srcX < img.width and srcY < img.height:
          result.pixels[y * newWidth + x] = img.pixels[srcY * img.width + srcX]
