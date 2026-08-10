# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniPercept/gray
import UniPercept/resize

suite "resize":
  test "identity at same size is exact":
    let g = toGrayscale([1'u8, 2, 3, 4], 2, 2, 1)
    let r = g.resize(2, 2)
    check r.width == 2
    check r.height == 2
    check r.pixels == [1'u8, 2, 3, 4]

  test "2x2 box downscale of a flat 4x4 is the flat value":
    let g = toGrayscale([200'u8, 200, 200, 200, 200, 200, 200, 200,
        200, 200, 200, 200, 200, 200, 200, 200], 4, 4, 1)
    let r = g.resize(2, 2)
    check r.pixels == [200'u8, 200, 200, 200]

  test "2x2 box downscale averages each 2x2 block":
    let g = toGrayscale([10'u8, 10, 20, 20, 10, 10, 20, 20, 30, 30, 40, 40,
        30, 30, 40, 40], 4, 4, 1)
    let r = g.resize(2, 2)
    check r.pixels == [10'u8, 20, 30, 40]

  test "upscale 1x2 -> 1x4 picks the nearest source column":
    let g = toGrayscale([0'u8, 100], 2, 1, 1)
    let r = g.resize(4, 1)
    check r.width == 4
    check r.pixels == [0'u8, 0, 100, 100]

  test "zero-size source produces a zero-pixel output":
    let empty = newSeq[byte](0)
    let g = toGrayscale(empty, 0, 0, 1)
    let r = g.resize(8, 8)
    check r.width == 8
    check r.height == 8
    check r.pixels.len == 64
    for v in r.pixels: check v == 0

  test "non-integral downscales cover the final source row and column":
    for sourceSize in [4, 7]:
      var pixels = newSeq[byte](sourceSize * sourceSize)
      let finalStart = (2 * sourceSize) div 3
      for y in finalStart ..< sourceSize:
        for x in finalStart ..< sourceSize:
          pixels[y * sourceSize + x] = 255
      let r = GrayscaleImage(width: sourceSize, height: sourceSize,
          pixels: pixels).resize(3, 3)
      check r.pixels[^1] == 255

  test "large flat downscale does not overflow its accumulator":
    let side = 5000
    var pixels = newSeq[byte](side * side)
    for i in 0 ..< pixels.len: pixels[i] = 255
    let g = GrayscaleImage(width: side, height: side, pixels: pixels)
    check g.resize(1, 1).pixels == @[255'u8]
