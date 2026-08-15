# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniImage-backed decoder — the ONLY layer that imports UniImage. The hash
## pipeline (gray/resize/hashes) stays decoder-agnostic. `loadImage` reads a
## file and dispatches TGA by extension (it has no reliable header magic);
## every other supported format is sniffed from its bytes by
## `UniImage.decodeImage`. This replaces the former decoder FFI.
import std/[os, strutils]
import UniImage/formats
import contracts
export UniImageException ## so callers (CLI, C ABI) can catch decode errors.
export decodeTga ## surfaced for the C ABI TGA hint (no magic to sniff).

type DecodedImage* = Image[uint8]
  ## Decoder result type exposed without requiring higher layers to import
  ## UniImage directly.

proc loadFileBytes(path: string): seq[byte] =
  let raw = readFile(path)
  result = newSeq[byte](raw.len)
  if raw.len > 0: copyMem(addr result[0], unsafeAddr raw[0], raw.len)

proc loadImage*(path: string): DecodedImage {.contractual.} =
  ## Read and decode an image file to an 8-bit `UniImage.Image`. TGA is
  ## dispatched by extension (no reliable magic); other formats are sniffed by
  ## `decodeImage`. Raises `UniImageException` on unsupported/truncated input.
  require:
    path.len > 0
  ensure:
    result.width > 0 and result.height > 0
    result.data.len == result.width * result.height * result.channels
  body:
    let ext = path.splitFile().ext.toLowerAscii()
    let bytes = loadFileBytes(path)
    if ext in [".tga", ".targa"]: result = decodeTga(bytes)
    else: result = decodeImage(bytes)

type AnalysedImage* = object
  ## An image decoded for measurement, and the size it was decoded from.
  image*: DecodedImage
  sourceWidth*, sourceHeight*: int

proc loadImageForAnalysis*(path: string;
                           maxEdge: int): AnalysedImage {.contractual.} =
  ## Read an image file, decoding no more finely than `maxEdge` needs, and
  ## report the size it came from.
  ##
  ## A hash reduces the image to a few dozen samples, so decoding every pixel
  ## of a 12 MP photograph first is work thrown away. What a format can skip is
  ## its own business: JPEG reconstructs one sample per 8x8 block, everything
  ## else decodes in full.
  require:
    path.len > 0
    maxEdge > 0
  ensure:
    result.image.width > 0 and result.image.height > 0
    result.sourceWidth >= result.image.width
    result.sourceHeight >= result.image.height
  body:
    let ext = path.splitFile().ext.toLowerAscii()
    let bytes = loadFileBytes(path)
    if ext in [".tga", ".targa"]:
      let full = decodeTga(bytes)
      return AnalysedImage(image: full, sourceWidth: full.width,
        sourceHeight: full.height)
    let scaled = decodeImageScaled(bytes, maxEdge)
    AnalysedImage(image: scaled.image, sourceWidth: scaled.sourceWidth,
      sourceHeight: scaled.sourceHeight)

proc loadImageFromMemory*(buffer: openArray[
    byte]): DecodedImage {.contractual.} =
  ## Decode an in-memory buffer via the byte-sniffing dispatcher. TGA cannot be
  ## sniffed; callers with a known-TGA buffer should use `UniImage.decodeTga`
  ## directly. Raises `UniImageException` on unsupported/truncated input.
  require:
    buffer.len > 0
  ensure:
    result.width > 0 and result.height > 0
    result.data.len == result.width * result.height * result.channels
  body:
    result = decodeImage(buffer)
