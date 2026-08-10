# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""unipercept — Python binding over the UniPercept C library (perceptual hashing)."""
from ._core import (
    version,
    abi_version,
    init,
    decode,
    hamming,
    strerror,
    Image,
    FMT_AUTO,
    FMT_TGA,
    MAX_BLOCK_BITS,
)

__version__ = version()

init()


__all__ = [
    "__version__",
    "abi_version",
    "decode",
    "hamming",
    "Image",
    "init",
    "strerror",
    "version",
    "FMT_AUTO",
    "FMT_TGA",
    "MAX_BLOCK_BITS",
]