# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniPercept — perceptual image hashing for the lituus-lab Uni* family.
##
## Grayscale, fixed-point resize, the aHash/dHash/pHash/blockhash kernels, a bk-tree index, and
## the UniImage-backed decoder; `computeHashes` and the per-algorithm file
## helpers wire decode -> gray -> hashes. The `up_*` C ABI (`src/UniPercept/c_api.nim`,
## header `include/UniPercept.h`) and the Cython binding (`py/unipercept/`)
## expose the same surface to C and Python.
import std/[os, strutils, sequtils]
import UniPercept/gray
export gray
import UniPercept/resize
export resize
import UniPercept/hashes
export hashes
import UniPercept/bktree
export bktree
import UniPercept/decode
export decode

func manifestVersion(text: string): string {.compileTime.} =
  for line in text.splitLines:
    if line.strip.startsWith('#'): continue
    let fields = line.split('=', 1)
    if fields.len == 2 and fields[0].strip == "version":
      return fields[1].strip.strip(chars = {'"'})
  raise newException(ValueError, "UniPercept.nimble has no version")

const UniPerceptVersion* = manifestVersion(staticRead(
  currentSourcePath.parentDir.parentDir / "UniPercept.nimble"))

type
  HashResult* = object
    ## All supported perceptual hashes of a single image.
    aHash*, dHash*, pHash*: Hash
    blockhash*: seq[byte]

  PHashResult* = object
    ## Perceptual hash plus the decoded source dimensions.
    hash*: Hash
    width*, height*: int

proc computeHashes*(path: string): HashResult =
  ## Decode `path` via UniImage and compute aHash/dHash/pHash/blockhash.
  let img = loadImage(path)
  let g = toGrayscale(img.data, img.width, img.height, img.channels)
  result.aHash = aHash(g)
  result.dHash = dHash(g)
  result.pHash = pHash(g)
  result.blockhash = blockhash(g)

proc phashInfo*(path: string): PHashResult =
  ## pHash and decoded dimensions of an image file.
  let img = loadImage(path)
  result.hash = pHash(toGrayscale(img.data, img.width, img.height, img.channels))
  result.width = img.width
  result.height = img.height

proc phash*(path: string): Hash =
  ## pHash of an image file. See `phashInfo` when dimensions are also needed.
  phashInfo(path).hash

proc ahash*(path: string): Hash =
  ## aHash of an image file.
  let img = loadImage(path)
  aHash(toGrayscale(img.data, img.width, img.height, img.channels))

proc dhash*(path: string): Hash =
  ## dHash of an image file.
  let img = loadImage(path)
  dHash(toGrayscale(img.data, img.width, img.height, img.channels))

proc toHex*(hash: Hash): string =
  ## 16-char lowercase hex of a `Hash`.
  hash.toHex(16).toLowerAscii()

proc toHex*(hash: seq[byte]): string =
  ## Lowercase hex of a byte sequence (e.g. a blockhash).
  hash.mapIt(it.toHex(2).toLowerAscii()).join("")
