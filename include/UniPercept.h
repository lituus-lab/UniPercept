// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/*
 * UniPercept.h — C ABI for UniPercept (perceptual image hashing)
 *
 * A pure-Nim perceptual-hash engine exposed to C: decode via UniImage, then
 * aHash / dHash / pHash / blockhash + Hamming distance.
 *
 * Lifecycle:
 *   - Call up_init() exactly once per process before any other function.
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

#define UNIPERCEPT_VERSION_MAJOR 0
#define UNIPERCEPT_VERSION_MINOR 1
#define UNIPERCEPT_VERSION_PATCH 0
#define UNIPERCEPT_VERSION "0.1.0"

#define UNIPERCEPT_VERSION_AT_LEAST(ma, mi, pa) \
  ((UNIPERCEPT_VERSION_MAJOR > (ma)) || \
   (UNIPERCEPT_VERSION_MAJOR == (ma) && UNIPERCEPT_VERSION_MINOR > (mi)) || \
   (UNIPERCEPT_VERSION_MAJOR == (ma) && UNIPERCEPT_VERSION_MINOR == (mi) && \
    UNIPERCEPT_VERSION_PATCH >= (pa)))

#define UNIPERCEPT_ABI_VERSION 1

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
typedef void* up_percept;

/* --- lifecycle --- */
void        up_init(void);
int         up_abi_version(void);
const char* up_strerror(int code);
const char* up_version(void);

/* Decode an in-memory image. fmt=UP_PERCEPT_FMT_AUTO sniffs the magic;
 * UP_PERCEPT_FMT_TGA decodes TGA (no magic). On success stores a handle in
 * *out_handle (free with up_free). */
int    up_decode(const unsigned char* data, size_t length, int fmt,
                 up_percept* out_handle);
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
void   up_free(up_percept h);
void   up_buffer_free(unsigned char* buffer, size_t len);

/* --- bk-tree index: Hamming-radius similarity search over hashes --- */
typedef void* up_percept_index;
/* Create an empty index (free with up_index_free). */
int    up_index_new(up_percept_index* out_handle);
/* Insert id at hash h. Never raises. */
int    up_index_insert(up_percept_index idx, int32_t id, uint64_t h);
/* Query hashes within Hamming radius of h. On success allocates *out_ids as
 * 2 * *out_count int32_t, interleaved [id0, dist0, id1, dist1, ...] (free with
 * up_buffer_free); *out_count is the number of matches. */
int    up_index_query(up_percept_index idx, uint64_t h, int radius,
                      int32_t** out_ids, size_t* out_count);
void   up_index_free(up_percept_index idx);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* UNIPERCEPT_H */
