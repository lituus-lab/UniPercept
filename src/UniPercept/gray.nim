# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Grayscale image + fixed-point luma conversion. Pure: no UniImage import —
## the hash pipeline remains decoder-agnostic. The integer implementation is
## preserved for cross-CPU determinism.
import contracts

type
  GrayscaleImage* = object
    width*, height*: int
    pixels*: seq[byte]

func inputFits(dataLen, width, height, channels: int): bool =
  if width < 0 or height < 0 or channels <= 0: return false
  if width > 0 and height > high(int) div width: return false
  let pixelCount = width * height
  pixelCount <= dataLen div channels

proc toGrayscale*(data: openArray[byte]; width, height,
    channels: int): GrayscaleImage {.contractual.} =
  ## Convert RGB/RGBA to luma (Y) with fixed-point arithmetic, or copy a
  ## single-channel image through. `Y = (306*R + 601*G + 117*B) >> 10`.
  require:
    inputFits(data.len, width, height, channels)
  ensure:
    result.width == width
    result.height == height
    result.pixels.len == width * height
  body:
    if not inputFits(data.len, width, height, channels):
      raise newException(ValueError, "toGrayscale: input buffer is too short")
    let pixelCount = width * height
    result.width = width
    result.height = height
    result.pixels = newSeq[byte](pixelCount)

    if channels >= 3:
      for i in 0 ..< pixelCount:
        let r = uint32(data[i * channels + 0])
        let g = uint32(data[i * channels + 1])
        let b = uint32(data[i * channels + 2])
        result.pixels[i] = byte((r * 306 + g * 601 + b * 117) shr 10)
    else:
      for i in 0 ..< pixelCount:
        result.pixels[i] = data[i * channels]
