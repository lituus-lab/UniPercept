# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Perceptual hash kernels: aHash, dHash, pHash (fixed-point DCT), blockhash,
## plus Hamming distance and similarity. Pure: imports only `gray` and `resize`
## (and stdlib bitops/math). Preserves the legacy implementation for
## cross-CPU determinism.
import contracts
import UniPercept/gray
import UniPercept/resize
import std/[bitops, math]

type Hash* = uint64

proc aHash*(img: GrayscaleImage): Hash =
  ## Average hash: 8x8 mean threshold.
  let small = img.resize(8, 8)
  var sum = 0'u32
  for p in small.pixels: sum += p
  let avg = byte(sum div 64)
  for i, p in small.pixels:
    if p >= avg: result = result or (1'u64 shl i)

proc dHash*(img: GrayscaleImage): Hash =
  ## Difference hash: 9x8 horizontal gradient.
  let small = img.resize(9, 8)
  for y in 0 ..< 8:
    for x in 0 ..< 8:
      if small.pixels[y * 9 + x] < small.pixels[y * 9 + x + 1]:
        result = result or (1'u64 shl (y * 8 + x))

const
  DCT_SIZE = 32
  FP_SHIFT = 14 # 14-bit precision for DCT coefficients

                # Precomputed DCT coefficients in fixed-point (S14.14). Module initialization
                # publishes one immutable table before callers can enter the hash kernels.
let dctCoeffsFp: array[DCT_SIZE, array[DCT_SIZE, int32]] = block:
  var coeffs: array[DCT_SIZE, array[DCT_SIZE, int32]]
  for i in 0 ..< DCT_SIZE:
    let c = if i == 0: 1.0 / sqrt(float(DCT_SIZE)) else: sqrt(2.0 / float(DCT_SIZE))
    for j in 0 ..< DCT_SIZE:
      coeffs[i][j] = int32(c * cos(PI * float(i) * (float(j) + 0.5) /
          float(DCT_SIZE)) * float(1 shl FP_SHIFT))
  coeffs

proc pHash*(img: GrayscaleImage): Hash =
  ## Perceptual hash: 32x32 -> 8x8 DCT (S14.14 fixed-point), mean of AC.
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
    bits > 0 and bits <= MaxBlockBits
  ensure:
    result.len == (bits * bits + 7) div 8
  body:
    if bits <= 0 or bits > MaxBlockBits: return @[]
    let n = bits * bits
    let small = img.resize(bits, bits)
    var sum = 0'u64
    for p in small.pixels: sum += p
    let mean = byte(sum div uint64(n))
    result = newSeq[byte]((n + 7) div 8)
    for i in 0 ..< n:
      if small.pixels[i] >= mean:
        result[i div 8] = result[i div 8] or (1'u8 shl (7 - (i mod 8)))

proc hammingDistance*(a, b: Hash): int = bitops.popcount(a xor b)
proc similarity*(a, b: Hash): float = 1.0 - (float(hammingDistance(a, b)) / 64.0)

