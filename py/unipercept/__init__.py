# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Perceptual image hashing backed by the native UniPercept engine."""
from ._core import (
    BkTree,
    FMT_AUTO,
    FMT_TGA,
    MAX_BLOCK_BITS,
    GrayscaleImage,
    Image,
    abi_version,
    ahash,
    blockhash,
    compute_hashes,
    decode,
    dhash,
    hamming,
    init,
    load_image,
    phash,
    phash_info,
    resize,
    similarity,
    strerror,
    to_grayscale,
    to_hex,
    version,
)

init()
__version__ = version()

__all__ = [
    "__version__",
    "BkTree",
    "FMT_AUTO",
    "FMT_TGA",
    "GrayscaleImage",
    "Image",
    "MAX_BLOCK_BITS",
    "abi_version",
    "ahash",
    "blockhash",
    "compute_hashes",
    "decode",
    "dhash",
    "hamming",
    "load_image",
    "phash",
    "phash_info",
    "resize",
    "similarity",
    "strerror",
    "to_grayscale",
    "to_hex",
    "version",
]
