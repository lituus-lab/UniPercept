# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Perceptual hash kernels: aHash, dHash, pHash (fixed-point DCT), blockhash,
## plus Hamming distance and similarity. Pure: imports only `gray` and `resize`
## (and stdlib bitops/math). Preserves the legacy implementation for
## cross-CPU determinism.
import contracts
import UniPercept/gray
import UniPercept/resize
import std/bitops

type Hash* = uint64

func validGray(img: GrayscaleImage): bool =
  img.width >= 0 and img.height >= 0 and
    (img.width == 0 or img.height <= high(int) div img.width) and
    img.width * img.height == img.pixels.len

proc aHash*(img: GrayscaleImage): Hash {.contractual.} =
  ## Average hash: 8x8 mean threshold.
  require:
    validGray(img)
  body:
    if not validGray(img): raise newException(ValueError, "aHash: invalid image")
    let small = img.resize(8, 8)
    var sum = 0'u32
    for p in small.pixels: sum += p
    let avg = byte(sum div 64)
    for i, p in small.pixels:
      if p >= avg: result = result or (1'u64 shl i)

proc dHash*(img: GrayscaleImage): Hash {.contractual.} =
  ## Difference hash: 9x8 horizontal gradient.
  require:
    validGray(img)
  body:
    if not validGray(img): raise newException(ValueError, "dHash: invalid image")
    let small = img.resize(9, 8)
    for y in 0 ..< 8:
      for x in 0 ..< 8:
        if small.pixels[y * 9 + x] < small.pixels[y * 9 + x + 1]:
          result = result or (1'u64 shl (y * 8 + x))

const
  DCT_SIZE = 32
  FP_SHIFT = 14 # 14-bit precision for DCT coefficients

  # Generated offline from the historical cosine formula at S14.14 precision.
const dctCoeffsFp: array[DCT_SIZE, array[DCT_SIZE, int32]] = [
    [2896, 2896, 2896, 2896, 2896, 2896, 2896, 2896, 2896, 2896, 2896, 2896,
        2896, 2896, 2896, 2896, 2896, 2896, 2896, 2896, 2896, 2896, 2896, 2896,
        2896, 2896, 2896, 2896, 2896, 2896, 2896, 2896],
    [4091, 4051, 3973, 3856, 3702, 3513, 3289, 3034, 2750, 2439, 2105, 1751,
        1379, 995, 601, 200, -200, -601, -995, -1379, -1751, -2105, -2439,
        -2750, -3034, -3289, -3513, -3702, -3856, -3973, -4051, -4091],
    [4076, 3919, 3612, 3166, 2598, 1930, 1189, 401, -401, -1189, -1930, -2598,
        -3166, -3612, -3919, -4076, -4076, -3919, -3612, -3166, -2598, -1930,
        -1189, -401, 401, 1189, 1930, 2598, 3166, 3612, 3919, 4076],
    [4051, 3702, 3034, 2105, 995, -200, -1379, -2439, -3289, -3856, -4091,
        -3973, -3513, -2750, -1751, -601, 601, 1751, 2750, 3513, 3973, 4091,
        3856, 3289, 2439, 1379, 200, -995, -2105, -3034, -3702, -4051],
    [4017, 3405, 2275, 799, -799, -2275, -3405, -4017, -4017, -3405, -2275,
        -799, 799, 2275, 3405, 4017, 4017, 3405, 2275, 799, -799, -2275, -3405,
        -4017, -4017, -3405, -2275, -799, 799, 2275, 3405, 4017],
    [3973, 3034, 1379, -601, -2439, -3702, -4091, -3513, -2105, -200, 1751,
        3289, 4051, 3856, 2750, 995, -995, -2750, -3856, -4051, -3289, -1751,
        200, 2105, 3513, 4091, 3702, 2439, 601, -1379, -3034, -3973],
    [3919, 2598, 401, -1930, -3612, -4076, -3166, -1189, 1189, 3166, 4076, 3612,
        1930, -401, -2598, -3919, -3919, -2598, -401, 1930, 3612, 4076, 3166,
        1189, -1189, -3166, -4076, -3612, -1930, 401, 2598, 3919],
    [3856, 2105, -601, -3034, -4091, -3289, -995, 1751, 3702, 3973, 2439, -200,
        -2750, -4051, -3513, -1379, 1379, 3513, 4051, 2750, 200, -2439, -3973,
        -3702, -1751, 995, 3289, 4091, 3034, 601, -2105, -3856],
    [3784, 1567, -1567, -3784, -3784, -1567, 1567, 3784, 3784, 1567, -1567,
        -3784, -3784, -1567, 1567, 3784, 3784, 1567, -1567, -3784, -3784, -1567,
        1567, 3784, 3784, 1567, -1567, -3784, -3784, -1567, 1567, 3784],
    [3702, 995, -2439, -4091, -2750, 601, 3513, 3856, 1379, -2105, -4051, -3034,
        200, 3289, 3973, 1751, -1751, -3973, -3289, -200, 3034, 4051, 2105,
        -1379, -3856, -3513, -601, 2750, 4091, 2439, -995, -3702],
    [3612, 401, -3166, -3919, -1189, 2598, 4076, 1930, -1930, -4076, -2598,
        1189, 3919, 3166, -401, -3612, -3612, -401, 3166, 3919, 1189, -2598,
        -4076, -1930, 1930, 4076, 2598, -1189, -3919, -3166, 401, 3612],
    [3513, -200, -3702, -3289, 601, 3856, 3034, -995, -3973, -2750, 1379, 4051,
        2439, -1751, -4091, -2105, 2105, 4091, 1751, -2439, -4051, -1379, 2750,
        3973, 995, -3034, -3856, -601, 3289, 3702, 200, -3513],
    [3405, -799, -4017, -2275, 2275, 4017, 799, -3405, -3405, 799, 4017, 2275,
        -2275, -4017, -799, 3405, 3405, -799, -4017, -2275, 2275, 4017, 799,
        -3405, -3405, 799, 4017, 2275, -2275, -4017, -799, 3405],
    [3289, -1379, -4091, -995, 3513, 3034, -1751, -4051, -601, 3702, 2750,
        -2105, -3973, -200, 3856, 2439, -2439, -3856, 200, 3973, 2105, -2750,
        -3702, 601, 4051, 1751, -3034, -3513, 995, 4091, 1379, -3289],
    [3166, -1930, -3919, 401, 4076, 1189, -3612, -2598, 2598, 3612, -1189,
        -4076, -401, 3919, 1930, -3166, -3166, 1930, 3919, -401, -4076, -1189,
        3612, 2598, -2598, -3612, 1189, 4076, 401, -3919, -1930, 3166],
    [3034, -2439, -3513, 1751, 3856, -995, -4051, 200, 4091, 601, -3973, -1379,
        3702, 2105, -3289, -2750, 2750, 3289, -2105, -3702, 1379, 3973, -601,
        -4091, -200, 4051, 995, -3856, -1751, 3513, 2439, -3034],
    [2896, -2896, -2896, 2896, 2896, -2896, -2896, 2896, 2896, -2896, -2896,
        2896, 2896, -2896, -2896, 2896, 2896, -2896, -2896, 2896, 2896, -2896,
        -2896, 2896, 2896, -2896, -2896, 2896, 2896, -2896, -2896, 2896],
    [2750, -3289, -2105, 3702, 1379, -3973, -601, 4091, -200, -4051, 995, 3856,
        -1751, -3513, 2439, 3034, -3034, -2439, 3513, 1751, -3856, -995, 4051,
        200, -4091, 601, 3973, -1379, -3702, 2105, 3289, -2750],
    [2598, -3612, -1189, 4076, -401, -3919, 1930, 3166, -3166, -1930, 3919, 401,
        -4076, 1189, 3612, -2598, -2598, 3612, 1189, -4076, 401, 3919, -1930,
        -3166, 3166, 1930, -3919, -401, 4076, -1189, -3612, 2598],
    [2439, -3856, -200, 3973, -2105, -2750, 3702, 601, -4051, 1751, 3034, -3513,
        -995, 4091, -1379, -3289, 3289, 1379, -4091, 995, 3513, -3034, -1751,
        4051, -601, -3702, 2750, 2105, -3973, 200, 3856, -2439],
    [2275, -4017, 799, 3405, -3405, -799, 4017, -2275, -2275, 4017, -799, -3405,
        3405, 799, -4017, 2275, 2275, -4017, 799, 3405, -3405, -799, 4017,
        -2275, -2275, 4017, -799, -3405, 3405, 799, -4017, 2275],
    [2105, -4091, 1751, 2439, -4051, 1379, 2750, -3973, 995, 3034, -3856, 601,
        3289, -3702, 200, 3513, -3513, -200, 3702, -3289, -601, 3856, -3034,
        -995, 3973, -2750, -1379, 4051, -2439, -1751, 4091, -2105],
    [1930, -4076, 2598, 1189, -3919, 3166, 401, -3612, 3612, -401, -3166, 3919,
        -1189, -2598, 4076, -1930, -1930, 4076, -2598, -1189, 3919, -3166, -401,
        3612, -3612, 401, 3166, -3919, 1189, 2598, -4076, 1930],
    [1751, -3973, 3289, -200, -3034, 4051, -2105, -1379, 3856, -3513, 601, 2750,
        -4091, 2439, 995, -3702, 3702, -995, -2439, 4091, -2750, -601, 3513,
        -3856, 1379, 2105, -4051, 3034, 200, -3289, 3973, -1751],
    [1567, -3784, 3784, -1567, -1567, 3784, -3784, 1567, 1567, -3784, 3784,
        -1567, -1567, 3784, -3784, 1567, 1567, -3784, 3784, -1567, -1567, 3784,
        -3784, 1567, 1567, -3784, 3784, -1567, -1567, 3784, -3784, 1567],
    [1379, -3513, 4051, -2750, 200, 2439, -3973, 3702, -1751, -995, 3289, -4091,
        3034, -601, -2105, 3856, -3856, 2105, 601, -3034, 4091, -3289, 995,
        1751, -3702, 3973, -2439, -200, 2750, -4051, 3513, -1379],
    [1189, -3166, 4076, -3612, 1930, 401, -2598, 3919, -3919, 2598, -401, -1930,
        3612, -4076, 3166, -1189, -1189, 3166, -4076, 3612, -1930, -401, 2598,
        -3919, 3919, -2598, 401, 1930, -3612, 4076, -3166, 1189],
    [995, -2750, 3856, -4051, 3289, -1751, -200, 2105, -3513, 4091, -3702, 2439,
        -601, -1379, 3034, -3973, 3973, -3034, 1379, 601, -2439, 3702, -4091,
        3513, -2105, 200, 1751, -3289, 4051, -3856, 2750, -995],
    [799, -2275, 3405, -4017, 4017, -3405, 2275, -799, -799, 2275, -3405, 4017,
        -4017, 3405, -2275, 799, 799, -2275, 3405, -4017, 4017, -3405, 2275,
        -799, -799, 2275, -3405, 4017, -4017, 3405, -2275, 799],
    [601, -1751, 2750, -3513, 3973, -4091, 3856, -3289, 2439, -1379, 200, 995,
        -2105, 3034, -3702, 4051, -4051, 3702, -3034, 2105, -995, -200, 1379,
        -2439, 3289, -3856, 4091, -3973, 3513, -2750, 1751, -601],
    [401, -1189, 1930, -2598, 3166, -3612, 3919, -4076, 4076, -3919, 3612,
        -3166, 2598, -1930, 1189, -401, -401, 1189, -1930, 2598, -3166, 3612,
        -3919, 4076, -4076, 3919, -3612, 3166, -2598, 1930, -1189, 401],
    [200, -601, 995, -1379, 1751, -2105, 2439, -2750, 3034, -3289, 3513, -3702,
        3856, -3973, 4051, -4091, 4091, -4051, 3973, -3856, 3702, -3513, 3289,
        -3034, 2750, -2439, 2105, -1751, 1379, -995, 601, -200]
  ]

proc pHash*(img: GrayscaleImage): Hash {.contractual.} =
  ## Perceptual hash: 32x32 -> 8x8 DCT (S14.14 fixed-point), mean of AC.
  require:
    validGray(img)
  body:
    if not validGray(img): raise newException(ValueError, "pHash: invalid image")
    let small = img.resize(DCT_SIZE, DCT_SIZE)

    var intermediate = newSeq[int32](DCT_SIZE * DCT_SIZE)
    var finalDct = newSeq[int32](8 * 8) # Only the top-left 8x8

  # Row pass
    for y in 0 ..< DCT_SIZE:
      let rowOffset = y * DCT_SIZE
      for u in 0 ..< DCT_SIZE:
        var sum: int64 = 0
        for x in 0 ..< DCT_SIZE:
          sum += int64(small.pixels[rowOffset + x]) * dctCoeffsFp[u][x]
        intermediate[rowOffset + u] = int32(sum shr 8)

  # Column pass
    for u in 0 ..< 8:
      for v in 0 ..< 8:
        var sum: int64 = 0
        for y in 0 ..< DCT_SIZE:
          sum += int64(intermediate[y * DCT_SIZE + u]) * dctCoeffsFp[v][y]
        finalDct[v * 8 + u] = int32(sum shr (FP_SHIFT + 2))

  # Mean of AC components (DC at index 0 excluded)
    var sumAc: int64 = 0
    for i in 1 ..< 64: sumAc += finalDct[i]
    let avg = int32(sumAc div 63)

    for i in 0 ..< 64:
      if finalDct[i] > avg: result = result or (1'u64 shl i)

const MaxBlockBits* = 256 ## Largest `bits` blockhash accepts; bounds the resize + output (≤ 8 KiB at 256²).

proc blockhash*(img: GrayscaleImage; bits: int = 16): seq[
    byte] {.contractual.} =
  ## Blockhash (standard variant): `bits`x`bits` mean threshold. Returns an empty
  ## sequence for nonpositive `bits` or for `bits > MaxBlockBits` — the bound
  ## keeps the resize + output buffer finite for untrusted callers. For valid
  ## `bits` the result length is `(bits * bits + 7) div 8` bytes, MSB-first.
  require:
    validGray(img)
  ensure:
    (bits < 1 or bits > MaxBlockBits) or
      result.len == (bits * bits + 7) div 8
  body:
    if not validGray(img) or bits <= 0 or bits > MaxBlockBits: return @[]
    let n = bits * bits
    let small = img.resize(bits, bits)
    var sum = 0'u64
    for p in small.pixels: sum += p
    let mean = byte(sum div uint64(n))
    result = newSeq[byte]((n + 7) div 8)
    for i in 0 ..< n:
      if small.pixels[i] >= mean:
        result[i div 8] = result[i div 8] or (1'u8 shl (7 - (i mod 8)))

proc hammingDistance*(a, b: Hash): int {.contractual.} =
  ## How many of the 64 bits differ. This is the distance perceptual hashes
  ## are compared with: two images are alike when few bits moved, and the
  ## count says how many, not how much the pictures differ in any other sense.
  ensure:
    result >= 0 and result <= 64
  body:
    result = bitops.popcount(a xor b)

proc similarity*(a, b: Hash): float {.contractual.} =
  ## The Hamming distance as a fraction in `0.0 .. 1.0`, where 1.0 is an
  ## identical hash. A convenience over `hammingDistance`, and a lossy one:
  ## the threshold worth thinking about is a bit count, and dividing by 64
  ## hides which count a given fraction stands for.
  ensure:
    result >= 0.0 and result <= 1.0
  body:
    result = 1.0 - (float(hammingDistance(a, b)) / 64.0)
