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

## A photograph-sized image with structure at several scales: flat blocks
## would hash identically whatever the decode, and prove nothing.
proc detailedRgb(width, height: int): Image[uint8] =
  result = newImage[uint8](width, height, csRgb)
  for y in 0 ..< height:
    for x in 0 ..< width:
      let i = (y * width + x) * 3
      let coarse = (x * 255) div width
      let band = if (y div 37) mod 2 == 0: 40 else: 0
      let fine = ((x * 7 + y * 13) mod 32) - 16
      result.data[i + 0] = byte(clamp(coarse + fine, 0, 255))
      result.data[i + 1] = byte(clamp((y * 255) div height + band, 0, 255))
      result.data[i + 2] = byte(clamp(255 - coarse + band - fine, 0, 255))

suite "scaled decode for hashing":
  test "a reduced decode reports the size the file really is":
    let path = getTempDir() / "unipercept_scaled_size.jpg"
    writeFile(path, cast[string](encodeImage(detailedRgb(512, 384), efJpeg, 90)))
    defer: removeFile(path)
    let info = phashInfo(path)
    # 512x384 is eight times the 32 pHash needs, so the decode reduced; the
    # dimensions reported are the file's own regardless.
    check info.width == 512
    check info.height == 384

  test "reducing the decode barely moves the hash":
    # Both paths average the same pixels when 32 divides the block grid, and
    # then agree exactly. They do not in general: a 4032x3024 photograph puts
    # 126 blocks across 32 samples, so the two averages straddle block edges
    # differently. Measured over a library of real photographs, that moved 8
    # of 17 JPEG hashes by one or two bits of 64 -- an order below the three
    # a 95% similarity threshold allows, so grouping is unaffected. This pins
    # the bound; a larger drift would be a real change of behaviour.
    let path = getTempDir() / "unipercept_scaled_drift.jpg"
    let img = detailedRgb(1000, 750)
    writeFile(path, cast[string](encodeImage(img, efJpeg, 92)))
    defer: removeFile(path)
    let reduced = phashInfo(path).hash
    let raw = loadImage(path)
    let full = pHash(toGrayscale(raw.data, raw.width, raw.height, 3))
    check hammingDistance(reduced, full) <= 2

  test "a file too small to reduce hashes exactly as it did":
    let path = getTempDir() / "unipercept_scaled_small.jpg"
    writeFile(path, cast[string](encodeImage(detailedRgb(64, 64), efJpeg, 92)))
    defer: removeFile(path)
    # 64x64 reduces to 8x8, short of the 32 pHash needs, so the decode is the
    # full one. Assert that rather than infer it from the hashes agreeing: a
    # reduction that slipped through would otherwise read as a hash change.
    let analysed = loadImageForAnalysis(path, 32)
    check analysed.image.width == 64 and analysed.image.height == 64
    let full = pHash(toGrayscale(loadImage(path).data, 64, 64, 3))
    check phashInfo(path).hash == full

suite "unipercept end-to-end":
  test "version":
    check UniPerceptVersion == "1.0.1"
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

suite "a RAW reports the picture's size, not its preview's":
  ## A vendor RAW keeps a small preview in IFD0 and the sensor image in a
  ## SubIFD under a proprietary compression. Decoding the file yields the
  ## preview, so a caller recording how big the photograph is would write down
  ## the thumbnail's size -- 160x120 for a Nikon NEF, measured, where the
  ## picture is 4992x3280.
  const RawShaped = currentSourcePath.parentDir / "fixtures" /
    "subifd-raw.tiff"

  test "the decoded preview is not what gets reported":
    let info = phashInfo(RawShaped)
    check info.width == 4992
    check info.height == 3280

  test "the hash still comes from the pixels that were decoded":
    # Reporting the stated size does not pretend the sensor data was read:
    # the hash is of the preview, which is a rendering of the same picture.
    let analysed = loadImageForAnalysis(RawShaped, 32)
    check analysed.image.width == 4
    check analysed.sourceWidth == 4992

  test "an ordinary image is left alone":
    # The stated size only wins where it is larger; a normal file's decoded
    # image is its own size and nothing overrides it.
    let path = getTempDir() / ("unipercept-plain-" &
      $getCurrentProcessId() & ".png")
    defer: removeFile(path)
    writeFile(path, cast[string](encodeImage(detailedRgb(64, 48), efPng)))
    let info = phashInfo(path)
    check info.width == 64
    check info.height == 48

