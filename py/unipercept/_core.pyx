# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# cython: language_level=3
"""Cython binding over the complete UniPercept C ABI."""
from libc.stddef cimport size_t
from libc.stdint cimport int32_t, uint64_t
import os
import threading


cdef extern from "UniPercept.h":
    const char *up_version()
    void up_init()
    int up_abi_version()
    const char *up_strerror(int code)

    ctypedef void* up_percept
    ctypedef void* up_percept_index

    int up_grayscale(const unsigned char* data, size_t length, int width,
                     int height, int channels, unsigned char** out_data,
                     size_t* out_len)
    int up_resize_gray(const unsigned char* data, size_t length, int width,
                       int height, int new_width, int new_height,
                       unsigned char** out_data, size_t* out_len)
    int up_ahash_gray(const unsigned char* data, size_t length, int width,
                      int height, uint64_t* out_hash)
    int up_dhash_gray(const unsigned char* data, size_t length, int width,
                      int height, uint64_t* out_hash)
    int up_phash_gray(const unsigned char* data, size_t length, int width,
                      int height, uint64_t* out_hash)
    int up_blockhash_gray(const unsigned char* data, size_t length, int width,
                          int height, int bits, unsigned char** out_data,
                          size_t* out_len)
    double up_similarity(uint64_t a, uint64_t b)
    size_t up_hash_hex(uint64_t hash_value, char* out_text, size_t capacity)
    size_t up_bytes_hex(const unsigned char* data, size_t length,
                        char* out_text, size_t capacity)

    int up_decode(const unsigned char* data, size_t length, int fmt,
                  up_percept* out_handle)
    int up_decode_file(const char* path, up_percept* out_handle)
    int up_image_width(up_percept h)
    int up_image_height(up_percept h)
    int up_image_channels(up_percept h)
    uint64_t up_ahash(up_percept h)
    uint64_t up_dhash(up_percept h)
    uint64_t up_phash(up_percept h)
    int up_blockhash(up_percept h, int bits, unsigned char** out_data,
                     size_t* out_len)
    int up_hamming(uint64_t a, uint64_t b)
    int up_compute_file(const char* path, uint64_t* out_ahash,
                        uint64_t* out_dhash, uint64_t* out_phash,
                        unsigned char** out_blockhash,
                        size_t* out_blockhash_len)
    int up_phash_file(const char* path, uint64_t* out_hash, int* out_width,
                      int* out_height)
    int up_ahash_file(const char* path, uint64_t* out_hash)
    int up_dhash_file(const char* path, uint64_t* out_hash)
    void up_free(up_percept h)
    void up_buffer_free(void* buffer, size_t length)

    int up_index_new(up_percept_index* out_handle)
    int up_index_insert(up_percept_index idx, int32_t ident, uint64_t hash_value)
    size_t up_index_len(up_percept_index idx)
    int up_index_query(up_percept_index idx, uint64_t hash_value, int radius,
                       int32_t** out_ids, size_t* out_count)
    void up_index_free(up_percept_index idx)


FMT_AUTO = 0
FMT_TGA = 8
MAX_BLOCK_BITS = 256

_init_lock = threading.Lock()
_initialized = False


cdef bytes _owned_bytes(unsigned char* data, size_t length):
    try:
        if length == 0:
            return b""
        return bytes(<unsigned char[:length]>data)
    finally:
        up_buffer_free(<void*>data, length)


cdef bytes _path_bytes(path):
    return os.fsencode(os.fspath(path))


def strerror(int code):
    cdef const char* value = up_strerror(code)
    if value == NULL:
        return f"error {code}"
    return (<bytes>value).decode("ascii")


def version():
    return (<bytes>up_version()).decode("ascii")


def abi_version():
    return up_abi_version()


def init():
    global _initialized
    if _initialized:
        return
    with _init_lock:
        if not _initialized:
            up_init()
            _initialized = True


cdef class GrayscaleImage:
    """Owned grayscale pixels with the dimensions required by hash kernels."""

    cdef bytes _pixels
    cdef int _width
    cdef int _height

    def __init__(self, pixels, int width, int height):
        cdef bytes value = bytes(pixels)
        if width < 0 or height < 0:
            raise ValueError("dimensions must be nonnegative")
        if width != 0 and height > 2147483647 // width:
            raise ValueError("dimensions are too large")
        if len(value) != width * height:
            raise ValueError("pixels must contain width * height bytes")
        self._pixels = value
        self._width = width
        self._height = height

    @property
    def pixels(self):
        return self._pixels

    @property
    def width(self):
        return self._width

    @property
    def height(self):
        return self._height

    def resize(self, int width, int height):
        return resize(self, width, height)

    def ahash(self):
        return ahash(self)

    def dhash(self):
        return dhash(self)

    def phash(self):
        return phash(self)

    def blockhash(self, int bits=16):
        return blockhash(self, bits)


cdef class Image:
    """Decoded image owned by UniPercept."""

    cdef up_percept _h

    def __cinit__(self):
        self._h = NULL

    def __dealloc__(self):
        if self._h != NULL:
            up_free(self._h)
            self._h = NULL

    cdef void _require_handle(self) except *:
        if self._h == NULL:
            raise RuntimeError("Image cannot be constructed directly")

    @property
    def width(self):
        self._require_handle()
        return up_image_width(self._h)

    @property
    def height(self):
        self._require_handle()
        return up_image_height(self._h)

    @property
    def channels(self):
        self._require_handle()
        return up_image_channels(self._h)

    def ahash(self):
        self._require_handle()
        return up_ahash(self._h)

    def dhash(self):
        self._require_handle()
        return up_dhash(self._h)

    def phash(self):
        self._require_handle()
        return up_phash(self._h)

    def blockhash(self, int bits=16):
        cdef unsigned char* out = NULL
        cdef size_t out_len = 0
        self._require_handle()
        rc = up_blockhash(self._h, bits, &out, &out_len)
        if rc != 0:
            raise ValueError(f"blockhash failed: {strerror(rc)}")
        return _owned_bytes(out, out_len)


cdef class BkTree:
    """Hamming-distance BK-tree whose identifiers are signed 32-bit values."""

    cdef up_percept_index _h

    def __cinit__(self):
        self._h = NULL
        rc = up_index_new(&self._h)
        if rc != 0:
            raise MemoryError(f"BK-tree allocation failed: {strerror(rc)}")

    def __dealloc__(self):
        if self._h != NULL:
            up_index_free(self._h)
            self._h = NULL

    def __len__(self):
        return up_index_len(self._h)

    def insert(self, int32_t ident, uint64_t hash_value):
        rc = up_index_insert(self._h, ident, hash_value)
        if rc != 0:
            raise ValueError(f"BK-tree insert failed: {strerror(rc)}")

    def query(self, uint64_t hash_value, int radius):
        cdef int32_t* out = NULL
        cdef size_t count = 0
        rc = up_index_query(self._h, hash_value, radius, &out, &count)
        if rc != 0:
            raise ValueError(f"BK-tree query failed: {strerror(rc)}")
        try:
            return [(out[i * 2], out[i * 2 + 1]) for i in range(count)]
        finally:
            up_buffer_free(<void*>out, count * 2 * sizeof(int32_t))


def to_grayscale(data, int width, int height, int channels):
    cdef bytes value = bytes(data)
    cdef const unsigned char* src = value
    cdef unsigned char* out = NULL
    cdef size_t out_len = 0
    rc = up_grayscale(src, len(value), width, height, channels, &out, &out_len)
    if rc != 0:
        raise ValueError(f"grayscale conversion failed: {strerror(rc)}")
    return GrayscaleImage(_owned_bytes(out, out_len), width, height)


def resize(GrayscaleImage image not None, int width, int height):
    cdef const unsigned char* src = image._pixels
    cdef unsigned char* out = NULL
    cdef size_t out_len = 0
    rc = up_resize_gray(src, len(image._pixels), image._width, image._height,
                        width, height, &out, &out_len)
    if rc != 0:
        raise ValueError(f"resize failed: {strerror(rc)}")
    return GrayscaleImage(_owned_bytes(out, out_len), width, height)


cdef uint64_t _gray_hash(GrayscaleImage image, int kind) except *:
    cdef const unsigned char* src = image._pixels
    cdef uint64_t value = 0
    if kind == 0:
        rc = up_ahash_gray(src, len(image._pixels), image._width, image._height,
                           &value)
    elif kind == 1:
        rc = up_dhash_gray(src, len(image._pixels), image._width, image._height,
                           &value)
    else:
        rc = up_phash_gray(src, len(image._pixels), image._width, image._height,
                           &value)
    if rc != 0:
        raise ValueError(f"hash failed: {strerror(rc)}")
    return value


def ahash(value):
    cdef uint64_t result
    cdef bytes path
    if isinstance(value, GrayscaleImage):
        return _gray_hash(value, 0)
    if isinstance(value, Image):
        return (<Image>value).ahash()
    path = _path_bytes(value)
    rc = up_ahash_file(path, &result)
    if rc != 0:
        raise ValueError(f"aHash failed: {strerror(rc)}")
    return result


def dhash(value):
    cdef uint64_t result
    cdef bytes path
    if isinstance(value, GrayscaleImage):
        return _gray_hash(value, 1)
    if isinstance(value, Image):
        return (<Image>value).dhash()
    path = _path_bytes(value)
    rc = up_dhash_file(path, &result)
    if rc != 0:
        raise ValueError(f"dHash failed: {strerror(rc)}")
    return result


def phash(value):
    cdef uint64_t result
    cdef int width = 0
    cdef int height = 0
    cdef bytes path
    if isinstance(value, GrayscaleImage):
        return _gray_hash(value, 2)
    if isinstance(value, Image):
        return (<Image>value).phash()
    path = _path_bytes(value)
    rc = up_phash_file(path, &result, &width, &height)
    if rc != 0:
        raise ValueError(f"pHash failed: {strerror(rc)}")
    return result


def blockhash(value, int bits=16):
    cdef GrayscaleImage image
    cdef const unsigned char* src
    cdef unsigned char* out = NULL
    cdef size_t out_len = 0
    if isinstance(value, Image):
        return (<Image>value).blockhash(bits)
    if not isinstance(value, GrayscaleImage):
        raise TypeError("blockhash expects Image or GrayscaleImage")
    image = value
    src = image._pixels
    rc = up_blockhash_gray(src, len(image._pixels), image._width, image._height,
                           bits, &out, &out_len)
    if rc != 0:
        raise ValueError(f"blockhash failed: {strerror(rc)}")
    return _owned_bytes(out, out_len)


def decode(data, fmt=FMT_AUTO):
    cdef bytes value = bytes(data)
    cdef const unsigned char* src = value
    cdef up_percept handle = NULL
    rc = up_decode(src, len(value), fmt, &handle)
    if rc != 0:
        raise ValueError(f"decode failed: {strerror(rc)}")
    result = Image()
    result._h = handle
    return result


def load_image(path):
    cdef bytes value = _path_bytes(path)
    cdef up_percept handle = NULL
    rc = up_decode_file(value, &handle)
    if rc != 0:
        raise ValueError(f"image decode failed: {strerror(rc)}")
    result = Image()
    result._h = handle
    return result


def compute_hashes(path):
    cdef bytes value = _path_bytes(path)
    cdef uint64_t a = 0
    cdef uint64_t d = 0
    cdef uint64_t p = 0
    cdef unsigned char* out = NULL
    cdef size_t out_len = 0
    rc = up_compute_file(value, &a, &d, &p, &out, &out_len)
    if rc != 0:
        raise ValueError(f"hash computation failed: {strerror(rc)}")
    return {"ahash": a, "dhash": d, "phash": p,
            "blockhash": _owned_bytes(out, out_len)}


def phash_info(path):
    cdef bytes value = _path_bytes(path)
    cdef uint64_t result = 0
    cdef int width = 0
    cdef int height = 0
    rc = up_phash_file(value, &result, &width, &height)
    if rc != 0:
        raise ValueError(f"pHash failed: {strerror(rc)}")
    return result, width, height


def hamming(uint64_t a, uint64_t b):
    return up_hamming(a, b)


def similarity(uint64_t a, uint64_t b):
    return up_similarity(a, b)


def to_hex(value):
    cdef size_t required
    cdef bytearray output
    cdef char* dst
    cdef bytes raw
    cdef const unsigned char* src
    if isinstance(value, int):
        required = up_hash_hex(value, NULL, 0)
        output = bytearray(required)
        dst = output
        up_hash_hex(value, dst, required)
    else:
        raw = bytes(value)
        src = raw
        required = up_bytes_hex(src, len(raw), NULL, 0)
        if required == 0:
            raise ValueError("byte sequence is too large")
        output = bytearray(required)
        dst = output
        up_bytes_hex(src, len(raw), dst, required)
    return bytes(output[:-1]).decode("ascii")
