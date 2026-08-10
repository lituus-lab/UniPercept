# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniPercept/gray
import UniPercept/hashes

# Deterministic 16x16 horizontal gradient: column x holds x*17 (0..255).
proc gradient(): GrayscaleImage =
  result.width = 16
  result.height = 16
  result.pixels = newSeq[byte](16 * 16)
  for y in 0 ..< 16:
    for x in 0 ..< 16:
      result.pixels[y * 16 + x] = byte(x * 17)

suite "hashes":
  test "hamming(h, h) == 0 and similarity == 1.0":
    let img = gradient()
    let h = img.pHash()
    check hammingDistance(h, h) == 0
    check similarity(h, h) == 1.0

  test "hamming of two distinct gradients > 0":
    let g1 = gradient()
    var g2 = g1
    for x in 0 ..< 16: g2.pixels[3 * 16 + x] = byte(255 - x * 17)
    check hammingDistance(g1.pHash(), g2.pHash()) > 0

  test "aHash is stable across calls":
    let img = gradient()
    check img.aHash() == img.aHash()

  test "aHash/dHash/pHash golden (fixed-point determinism)":
    # Captured at first green run; pinned to catch any drift in the kernels.
    # dHash is all-1s because the gradient is strictly increasing left-to-right.
    let img = gradient()
    check img.aHash() == 17361641481138401520'u64
    check img.dHash() == 18446744073709551615'u64
    check img.pHash() == 18446744073709551573'u64

  test "blockhash length is bits*bits/8 and mixed":
    let img = gradient()
    let b = img.blockhash(16)
    check b.len == 32
    var ones = 0
    for bv in b:
      for bi in 0 ..< 8:
        if ((bv shr bi) and 1'u8) == 1'u8: inc ones
    check ones > 0 and ones < 256

  test "blockhash default bits == 16":
    let img = gradient()
    check img.blockhash().len == 32
