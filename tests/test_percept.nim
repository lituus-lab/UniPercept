# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## End-to-end: UniImage encode -> decode -> gray -> hash. Pins golden values
## for a known RGB gradient and exercises the file-based `computeHashes` path.
import std/[unittest, os, strutils]
import UniImage
import UniPercept

const
  RepoRoot = currentSourcePath.parentDir.parentDir
  HeaderText = staticRead(RepoRoot / "include" / "UniPercept.h")
  PyProjectText = staticRead(RepoRoot / "py" / "pyproject.toml")

# 16x16 RGB gradient: R rises with x, G with y, B with x+y.
proc gradientRgb(invert = false): Image[uint8] =
  result = newImage[uint8](16, 16, csRgb)
  for y in 0 ..< 16:
    for x in 0 ..< 16:
      let i = (y * 16 + x) * 3
      result.data[i + 0] = byte(if invert: 255 - x * 17 else: x * 17)
      result.data[i + 1] = byte(if invert: 255 - y * 17 else: y * 17)
      result.data[i + 2] = byte(min(255, (x + y) * 8))

suite "unipercept end-to-end":
  test "version":
    check UniPerceptVersion == "1.0.0"
    check HeaderText.contains("#define UNIPERCEPT_VERSION \"" &
        UniPerceptVersion & "\"")
    check PyProjectText.contains("version = \"" & UniPerceptVersion & "\"")
    check HeaderText.contains("#define UP_PERCEPT_MAX_BLOCK_BITS " &
        $MaxBlockBits)

  test "encode -> decode -> hash golden (fixed-point determinism)":
    let png = encodeImage(gradientRgb(), efPng)
    let dec = decodeImage(png)
    let g = toGrayscale(dec.data, dec.width, dec.height, dec.channels)
    check aHash(g) == 18446742943604670464'u64
    check dHash(g) == 18446744073709551615'u64
    check pHash(g) == 18446742974181146357'u64

  test "hamming(h, h) == 0 and similarity == 1.0":
    let g = toGrayscale(
      decodeImage(encodeImage(gradientRgb(), efPng)).data, 16, 16, 3)
    let h = pHash(g)
    check hammingDistance(h, h) == 0
    check similarity(h, h) == 1.0

  test "hamming of two distinct gradients > 0":
    let g1 = toGrayscale(
      decodeImage(encodeImage(gradientRgb(), efPng)).data, 16, 16, 3)
    let g2 = toGrayscale(
      decodeImage(encodeImage(gradientRgb(invert = true), efPng)).data, 16, 16, 3)
    check hammingDistance(pHash(g1), pHash(g2)) > 0

  test "computeHashes(path) matches the in-memory pipeline":
    let png = encodeImage(gradientRgb(), efPng)
    let tmp = getTempDir() / "unipercept_test_gradient.png"
    writeFile(tmp, cast[string](png))
    defer: removeFile(tmp)
    let h = computeHashes(tmp)
    let g = toGrayscale(decodeImage(png).data, 16, 16, 3)
    check h.aHash == aHash(g)
    check h.dHash == dHash(g)
    check h.pHash == pHash(g)
    check h.blockhash.len == 32

  test "toHex(Hash) is 16 lowercase chars":
    let h = pHash(toGrayscale(
      decodeImage(encodeImage(gradientRgb(), efPng)).data, 16, 16, 3))
    let s = toHex(h)
    check s.len == 16
    check s == s.toLowerAscii()

  test "phash/ahash/dhash file helpers match computeHashes":
    let png = encodeImage(gradientRgb(), efPng)
    let tmp = getTempDir() / "unipercept_test_helpers.png"
    writeFile(tmp, cast[string](png))
    defer: removeFile(tmp)
    let h = computeHashes(tmp)
    let info = phashInfo(tmp)
    check info.hash == h.pHash
    check (info.width, info.height) == (16, 16)
    check phash(tmp) == info.hash
    check ahash(tmp) == h.aHash
    check dhash(tmp) == h.dHash
