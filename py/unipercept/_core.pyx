# cython: language_level=3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Cython binding over the UniPercept C ABI (perceptual hashing)."""
from libc.stddef cimport size_t
from libc.stdint cimport uint64_t
cimport cython


cdef extern from "UniPercept.h":
    const char *up_version()
    void   up_init()
    int    up_abi_version()
    const char *up_strerror(int code)

    ctypedef void* up_percept

    int      up_decode(const unsigned char* data, size_t length, int fmt,
                       up_percept* out_handle)
    int      up_image_width(up_percept h)
    int      up_image_height(up_percept h)
    int      up_image_channels(up_percept h)
    uint64_t up_ahash(up_percept h)
    uint64_t up_dhash(up_percept h)
    uint64_t up_phash(up_percept h)
    int      up_blockhash(up_percept h, int bits,
                          unsigned char** out_data, size_t* out_len)
    int      up_hamming(uint64_t a, uint64_t b)
    void     up_free(up_percept h)
    void     up_buffer_free(unsigned char* buffer, size_t len)


# Format constants + the blockhash bound — mirror the C enums/macros in
# UniPercept.h so callers pass `unipercept.FMT_TGA`, etc. rather than raw ints.
FMT_AUTO = 0
FMT_TGA = 8
MAX_BLOCK_BITS = 256  # mirrors UP_PERCEPT_MAX_BLOCK_BITS


cdef class Image:
    """A decoded image exposed for perceptual hashing. The library owns the
    pixel data; freeing is automatic on GC."""

    cdef up_percept _h

    def __cinit__(self):
        self._h = NULL

    def __dealloc__(self):
        if self._h != NULL:
            up_free(self._h)
            self._h = NULL

    @property
    def width(self):
        return up_image_width(self._h)

    @property
    def height(self):
        return up_image_height(self._h)

    @property
    def channels(self):
        return up_image_channels(self._h)

    def ahash(self):
        return up_ahash(self._h)

    def dhash(self):
        return up_dhash(self._h)

    def phash(self):
        return up_phash(self._h)

    def blockhash(self, int bits=16):
        cdef unsigned char* out = NULL
        cdef size_t out_len = 0
        rc = up_blockhash(self._h, bits, &out, &out_len)
        if rc != 0:
            raise ValueError(f"blockhash failed: {strerror(rc)}")
        try:
            return bytes(<unsigned char[:out_len]>out)
        finally:
            up_buffer_free(out, out_len)


def strerror(int code):
    cdef const char* s = up_strerror(code)
    if s == NULL:
        return f"error {code}"
    return (<bytes>s).decode("ascii")


def version():
    return (<bytes>up_version()).decode("ascii")


def abi_version():
    return up_abi_version()


def init():
    up_init()


def decode(data, fmt=FMT_AUTO):
    """Decode an in-memory image (bytes). `fmt` defaults to AUTO (sniff the
    magic); pass FMT_TGA to decode a TGA (no magic). Returns an `Image`."""
    cdef up_percept h = NULL
    cdef const unsigned char* buf
    cdef size_t length = len(data)
    if length == 0:
        buf = NULL
    else:
        buf = <const unsigned char*>data
    rc = up_decode(buf, length, fmt, &h)
    if rc != 0:
        raise ValueError(f"decode failed: {strerror(rc)}")
    r = Image()
    r._h = h
    return r


def hamming(uint64_t a, uint64_t b):
    """Hamming distance (popcount of XOR) between two hashes."""
    return up_hamming(a, b)