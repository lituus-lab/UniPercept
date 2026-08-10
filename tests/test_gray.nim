# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniPercept/gray

suite "toGrayscale":
  test "luma of the pure primaries and white":
    # Y = (306R + 601G + 117B) >> 10. White collapses to 255.
    let g = toGrayscale([255'u8, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255], 2, 2, 3)
    check g.width == 2
    check g.height == 2
    check g.pixels == [76'u8, 149, 29, 255]

  test "single-channel image passes through":
    let g = toGrayscale([10'u8, 20, 30, 40], 2, 2, 1)
    check g.pixels == [10'u8, 20, 30, 40]

  test "zero-size image yields an empty buffer":
    let empty = newSeq[byte](0)
    let g = toGrayscale(empty, 0, 0, 3)
    check g.pixels.len == 0
