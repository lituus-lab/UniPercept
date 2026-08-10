# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Self-contained pytest over the up_* Cython surface (no fixture)."""
import pytest

import unipercept

# A 2x2 RGB P6 PPM: red, green, blue, white.
PPM = b"P6\n2 2\n255\n" + bytes(
    [0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF]
)
# A distinct 2x2 image (all-blue).
BLUE = b"P6\n2 2\n255\n" + bytes(
    [0x00, 0x00, 0xFF, 0x00, 0x00, 0xFF, 0x00, 0x00, 0xFF, 0x00, 0x00, 0xFF]
)


def test_abi_version():
    assert unipercept.abi_version() == 1


def test_version():
    assert unipercept.version() == "0.1.0"
    assert unipercept.__version__ == "0.1.0"


def test_decode_and_props():
    img = unipercept.decode(PPM)
    assert img.width == 2
    assert img.height == 2
    assert img.channels == 3


def test_hashes_are_ints_and_nonzero():
    img = unipercept.decode(PPM)
    a = img.ahash()
    d = img.dhash()
    p = img.phash()
    assert isinstance(a, int) and isinstance(d, int) and isinstance(p, int)
    assert a != 0 and d != 0 and p != 0


def test_hamming_self_is_zero():
    img = unipercept.decode(PPM)
    a = img.ahash()
    d = img.dhash()
    p = img.phash()
    assert unipercept.hamming(a, a) == 0
    assert unipercept.hamming(d, d) == 0
    assert unipercept.hamming(p, p) == 0


def test_hamming_distinct_is_positive():
    a1 = unipercept.decode(PPM).ahash()
    a2 = unipercept.decode(BLUE).ahash()
    assert a1 != a2
    assert unipercept.hamming(a1, a2) > 0


def test_blockhash_length():
    img = unipercept.decode(PPM)
    bh = img.blockhash(16)
    assert isinstance(bh, bytes)
    assert len(bh) == 32


def test_blockhash_max_bound():
    img = unipercept.decode(PPM)
    bh = img.blockhash(unipercept.MAX_BLOCK_BITS)
    assert len(bh) == (256 * 256 + 7) // 8


def test_blockhash_out_of_range_raises():
    img = unipercept.decode(PPM)
    with pytest.raises(ValueError):
        img.blockhash(0)
    with pytest.raises(ValueError):
        img.blockhash(unipercept.MAX_BLOCK_BITS + 1)


def test_bad_input_raises():
    with pytest.raises(ValueError):
        unipercept.decode(b"\x00\x01\x02\x03")