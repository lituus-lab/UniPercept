# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniImage-backed decoder — the ONLY layer that imports UniImage. The hash
## pipeline (gray/resize/hashes) stays decoder-agnostic. `loadImage` reads a
## file and dispatches TGA by extension (it has no reliable header magic);
## every other supported format is sniffed from its bytes by
## `UniImage.decodeImage`. This replaces the former decoder FFI.
import std/[os, strutils]
import UniImage/formats
export UniImageException ## so callers (CLI, C ABI) can catch decode errors.
export decodeTga ## surfaced for the C ABI TGA hint (no magic to sniff).

type DecodedImage* = Image[uint8]
  ## Decoder result type exposed without requiring higher layers to import
  ## UniImage directly.

proc loadFileBytes(path: string): seq[byte] =
  let raw = readFile(path)
  result = newSeq[byte](raw.len)
  if raw.len > 0: copyMem(addr result[0], unsafeAddr raw[0], raw.len)

proc loadImage*(path: string): DecodedImage =
  ## Read and decode an image file to an 8-bit `UniImage.Image`. TGA is
  ## dispatched by extension (no reliable magic); other formats are sniffed by
  ## `decodeImage`. Raises `UniImageException` on unsupported/truncated input.
  let ext = path.splitFile().ext.toLowerAscii()
  let bytes = loadFileBytes(path)
  if ext in [".tga", ".targa"]: result = decodeTga(bytes)
  else: result = decodeImage(bytes)

proc loadImageFromMemory*(buffer: openArray[byte]): DecodedImage =
  ## Decode an in-memory buffer via the byte-sniffing dispatcher. TGA cannot be
  ## sniffed; callers with a known-TGA buffer should use `UniImage.decodeTga`
  ## directly. Raises `UniImageException` on unsupported/truncated input.
  result = decodeImage(buffer)
