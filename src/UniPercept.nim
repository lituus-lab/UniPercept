# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniPercept — perceptual image hashing for the lituus-lab Uni* family.
##
## Grayscale, fixed-point resize, the aHash/dHash/pHash/blockhash kernels, a bk-tree index, and
## the UniImage-backed decoder; `computeHashes` and the per-algorithm file
## helpers wire decode -> gray -> hashes. The `up_*` C ABI (`src/UniPercept/c_api.nim`,
## header `include/UniPercept.h`) and the Cython binding (`py/unipercept/`)
## expose the same surface to C and Python.
import std/[strutils, sequtils]
import contracts
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

const UniPerceptVersion* = "1.0.0"

type
  HashResult* = object
    ## All supported perceptual hashes of a single image.
    aHash*, dHash*, pHash*: Hash
    blockhash*: seq[byte]

  PHashResult* = object
    ## Perceptual hash plus the decoded source dimensions.
    hash*: Hash
    width*, height*: int

proc computeHashes*(path: string): HashResult {.contractual.} =
  ## Decode `path` via UniImage and compute aHash/dHash/pHash/blockhash.
  require:
    path.len > 0
  ensure:
    result.blockhash.len == 32
  body:
    let img = loadImage(path)
    let g = toGrayscale(img.data, img.width, img.height, img.channels)
    result.aHash = aHash(g)
    result.dHash = dHash(g)
    result.pHash = pHash(g)
    result.blockhash = blockhash(g)

proc phashInfo*(path: string): PHashResult {.contractual.} =
  ## pHash and decoded dimensions of an image file.
  require:
    path.len > 0
  ensure:
    result.width > 0 and result.height > 0
  body:
    let img = loadImage(path)
    result.hash = pHash(toGrayscale(img.data, img.width, img.height, img.channels))
    result.width = img.width
    result.height = img.height

proc phash*(path: string): Hash {.contractual.} =
  ## pHash of an image file. See `phashInfo` when dimensions are also needed.
  require:
    path.len > 0
  body:
    result = phashInfo(path).hash

proc ahash*(path: string): Hash {.contractual.} =
  ## aHash of an image file.
  require:
    path.len > 0
  body:
    let img = loadImage(path)
    result = aHash(toGrayscale(img.data, img.width, img.height, img.channels))

proc dhash*(path: string): Hash {.contractual.} =
  ## dHash of an image file.
  require:
    path.len > 0
  body:
    let img = loadImage(path)
    result = dHash(toGrayscale(img.data, img.width, img.height, img.channels))

proc toHex*(hash: Hash): string {.contractual.} =
  ## 16-char lowercase hex of a `Hash`.
  ensure:
    result.len == 16
  body:
    result = hash.toHex(16).toLowerAscii()

proc toHex*(hash: seq[byte]): string {.contractual.} =
  ## Lowercase hex of a byte sequence (e.g. a blockhash).
  ensure:
    result.len == hash.len * 2
  body:
    result = hash.mapIt(it.toHex(2).toLowerAscii()).join("")
