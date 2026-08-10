// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/*
 * UniPercept.h — C ABI for UniPercept (perceptual image hashing)
 *
 * A pure-Nim perceptual-hash engine exposed to C: grayscale conversion,
 * fixed-point resize, decode via UniImage, perceptual hashes, and BK-tree
 * similarity search.
 *
 * Lifecycle:
 *   - Call up_init() before any other function. Repeated calls are no-ops;
 *     externally synchronize the first call.
 *   - Handles are opaque. The library owns them; release with up_free.
 *     up_blockhash allocates a buffer the caller frees with up_buffer_free.
 *
 * Thread-safety:
 *   - up_init() is required once before use. A single handle must not be used
 *     concurrently from multiple threads without external synchronisation.
 *
 * Error model:
 *   - Functions returning int return an up_percept_status. No exception or fault
 *     from the Nim core crosses this boundary.
 *
 * ABI stability:
 *   - UNIPERCEPT_ABI_VERSION is bumped on incompatible changes; check it at
 *     runtime with up_abi_version().
 */
#ifndef UNIPERCEPT_H
#define UNIPERCEPT_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define UNIPERCEPT_VERSION_MAJOR 1
#define UNIPERCEPT_VERSION_MINOR 0
#define UNIPERCEPT_VERSION_PATCH 0
#define UNIPERCEPT_VERSION "1.0.0"

#define UNIPERCEPT_VERSION_AT_LEAST(ma, mi, pa) \
  ((UNIPERCEPT_VERSION_MAJOR > (ma)) || \
   (UNIPERCEPT_VERSION_MAJOR == (ma) && UNIPERCEPT_VERSION_MINOR > (mi)) || \
   (UNIPERCEPT_VERSION_MAJOR == (ma) && UNIPERCEPT_VERSION_MINOR == (mi) && \
    UNIPERCEPT_VERSION_PATCH >= (pa)))

#define UNIPERCEPT_ABI_VERSION 2

/* Largest `bits` up_blockhash accepts; bounds the resize + output buffer. */
#define UP_PERCEPT_MAX_BLOCK_BITS 256

typedef enum {
  UP_PERCEPT_OK         = 0, /* success */
  UP_PERCEPT_ERR_FORMAT = 2, /* bad arg / unrecognized / truncated / bad handle */
  UP_PERCEPT_ERR_UNSUP  = 4, /* unsupported operation (reserved) */
  UP_PERCEPT_ERR_MEM    = 8  /* allocation failed */
} up_percept_status;

/* Decode hint. AUTO sniffs the magic; TGA has no magic and needs the hint.
 * Any other value returns UP_PERCEPT_ERR_FORMAT. */
typedef enum {
  UP_PERCEPT_FMT_AUTO = 0, /* sniff PNG/JPEG/BMP/QOI/PNM/GIF/PCX/HDR/WebP/TIFF */
  UP_PERCEPT_FMT_TGA  = 8  /* decode needs the hint (TGA has no magic) */
} up_percept_format;

/* Opaque decoded-image handle. */
typedef struct up_percept_image* up_percept;
typedef struct up_percept_index_impl* up_percept_index;

/* --- lifecycle --- */
void        up_init(void);
int         up_abi_version(void);
const char* up_strerror(int code);
const char* up_version(void);

/* --- pure grayscale kernels ---
 * UniPercept allocates returned buffers; ownership transfers to the caller on
 * success and the caller releases them with up_buffer_free. up_grayscale
 * accepts an empty source image and reports success with a NULL buffer and
 * length zero. */
int up_grayscale(const unsigned char* data, size_t length, int width, int height,
                 int channels, unsigned char** out_data, size_t* out_len);
/* Resize a valid grayscale source. An empty source produces a
 * new_width x new_height output when the requested target is non-empty;
 * zero-sized targets produce an empty output. */
int up_resize_gray(const unsigned char* data, size_t length, int width,
                   int height, int new_width, int new_height,
                   unsigned char** out_data, size_t* out_len);
int up_ahash_gray(const unsigned char* data, size_t length, int width,
                  int height, uint64_t* out_hash);
int up_dhash_gray(const unsigned char* data, size_t length, int width,
                  int height, uint64_t* out_hash);
int up_phash_gray(const unsigned char* data, size_t length, int width,
                  int height, uint64_t* out_hash);
int up_blockhash_gray(const unsigned char* data, size_t length, int width,
                      int height, int bits, unsigned char** out_data,
                      size_t* out_len);
double up_similarity(uint64_t a, uint64_t b);
/* Count/fill string conversion. Return value includes the trailing NUL.
 * Passing NULL or a short buffer only returns the required capacity. */
size_t up_hash_hex(uint64_t hash, char* out_text, size_t capacity);
size_t up_bytes_hex(const unsigned char* data, size_t length, char* out_text,
                    size_t capacity);

/* Decode an in-memory image. fmt=UP_PERCEPT_FMT_AUTO sniffs the magic;
 * UP_PERCEPT_FMT_TGA decodes TGA (no magic). On success stores a handle in
 * *out_handle (free with up_free). */
int    up_decode(const unsigned char* data, size_t length, int fmt,
                 up_percept* out_handle);
int    up_decode_file(const char* path, up_percept* out_handle);
int    up_image_width(up_percept h);
int    up_image_height(up_percept h);
int    up_image_channels(up_percept h);
/* Perceptual hashes of the decoded image; 0 on an invalid handle. Never raise. */
uint64_t up_ahash(up_percept h);
uint64_t up_dhash(up_percept h);
uint64_t up_phash(up_percept h);
/* Blockhash at bits*bits (1..UP_PERCEPT_MAX_BLOCK_BITS). On success allocates
 * *out_data (free with up_buffer_free) and sets *out_len to (bits*bits+7)/8.
 * Out-of-range bits returns UP_PERCEPT_ERR_FORMAT. */
int    up_blockhash(up_percept h, int bits,
                    unsigned char** out_data, size_t* out_len);
/* Hamming distance (popcount of XOR). Never raises. */
int    up_hamming(uint64_t a, uint64_t b);
/* File helpers mirror the Nim facade. up_compute_file allocates blockhash. */
int    up_compute_file(const char* path, uint64_t* out_ahash,
                       uint64_t* out_dhash, uint64_t* out_phash,
                       unsigned char** out_blockhash,
                       size_t* out_blockhash_len);
int    up_phash_file(const char* path, uint64_t* out_hash, int* out_width,
                     int* out_height);
int    up_ahash_file(const char* path, uint64_t* out_hash);
int    up_dhash_file(const char* path, uint64_t* out_hash);
void   up_free(up_percept h);
void   up_buffer_free(void* buffer, size_t len);

/* --- bk-tree index: Hamming-radius similarity search over hashes --- */
/* Create an empty index (free with up_index_free). */
int    up_index_new(up_percept_index* out_handle);
/* Insert id at hash h. Never raises. */
int    up_index_insert(up_percept_index idx, int32_t id, uint64_t h);
/* Number of distinct hashes. Returns zero for an invalid or empty index. */
size_t up_index_len(up_percept_index idx);
/* Query hashes within Hamming radius 0..64 of h. On success allocates *out_ids as
 * 2 * *out_count int32_t, interleaved [id0, dist0, id1, dist1, ...] (free with
 * up_buffer_free); *out_count is the number of matches. */
int    up_index_query(up_percept_index idx, uint64_t h, int radius,
                      int32_t** out_ids, size_t* out_count);
void   up_index_free(up_percept_index idx);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* UNIPERCEPT_H */
