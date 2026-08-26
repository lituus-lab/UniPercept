#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Regenerate subifd-raw.tiff, the RAW-shaped fixture the dimension test uses.

A vendor RAW keeps a small preview in IFD0 and the sensor image in a SubIFD,
so decoding the file yields the preview while the picture's real size is only
stated in metadata. This is that structure in two hundred bytes, with no
photograph in it: four grey pixels in IFD0 and a SubIFD declaring 4992x3280.
"""
import struct
import os


def ifd(entries, next_offset):
    out = struct.pack("<H", len(entries))
    for tag, typ, count, value in entries:
        out += struct.pack("<HHII", tag, typ, count, value)
    return out + struct.pack("<I", next_offset)


pixels = bytes(range(16))
ifd0_offset = 8
ifd0_length = 2 + 10 * 12 + 4
sub_offset = ifd0_offset + ifd0_length
sub_length = 2 + 4 * 12 + 4
strip_offset = sub_offset + sub_length

data = b"II\x2a\x00" + struct.pack("<I", ifd0_offset) + ifd([
    (0x0100, 3, 1, 4),                 # ImageWidth  -- the preview
    (0x0101, 3, 1, 4),                 # ImageLength
    (0x0102, 3, 1, 8),                 # BitsPerSample
    (0x0103, 3, 1, 1),                 # Compression: none
    (0x0106, 3, 1, 1),                 # Photometric: black is zero
    (0x0111, 4, 1, strip_offset),      # StripOffsets
    (0x0115, 3, 1, 1),                 # SamplesPerPixel
    (0x0116, 4, 1, 4),                 # RowsPerStrip
    (0x0117, 4, 1, len(pixels)),       # StripByteCounts
    (0x014A, 4, 1, sub_offset),        # SubIFDs -> the real picture
], 0) + ifd([
    (0x0100, 4, 1, 4992),              # ImageWidth  -- what the photo is
    (0x0101, 4, 1, 3280),              # ImageLength
    (0x0102, 3, 1, 12),
    (0x0115, 3, 1, 1),
], 0) + pixels

target = os.path.join(os.path.dirname(__file__), "subifd-raw.tiff")
with open(target, "wb") as handle:
    handle.write(data)
print(f"wrote {target}: {len(data)} bytes")
