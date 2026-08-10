// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/*
 * test_unipercept.c — self-contained C ABI smoke test (no external fixture).
 * Exercises up_decode, the perceptual hashes, up_hamming, up_blockhash bounds,
 * NULL-safety, and bad input. Build/run via `nimble ctest`.
 */
/* Keep the asserts active even if this TU is built with -DNDEBUG (a copied
 * Makefile, a CI matrix variant, or a downstream consumer). A test that prints
 * "OK" without exercising the ABI is worse than no test. */
#undef NDEBUG
#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include "UniPercept.h"

int main(void) {
  up_init();

  /* NULL-safety: benign returns, no crash. */
  up_free(NULL);
  up_buffer_free(NULL, 0);
  assert(up_ahash(NULL) == 0);
  assert(up_dhash(NULL) == 0);
  assert(up_phash(NULL) == 0);
  assert(up_image_width(NULL) == 0);
  assert(up_image_height(NULL) == 0);
  assert(up_image_channels(NULL) == 0);
  assert(up_image_width((up_percept)1) == 0);
  assert(up_ahash((up_percept)1) == 0);
  up_free((up_percept)1);
  assert(up_hamming(0, 0) == 0);
  assert(up_similarity(0, 0) == 1.0);

  /* Bad arguments: rejected, out-handle cleared. */
  up_percept bad = (up_percept)1;
  assert(up_decode(NULL, 0, UP_PERCEPT_FMT_AUTO, &bad) == UP_PERCEPT_ERR_FORMAT);
  assert(bad == NULL);
  assert(up_decode((const unsigned char*)"x", 1, 99, &bad) ==
         UP_PERCEPT_ERR_FORMAT);
  assert(bad == NULL);

  /* A 2x2 RGB P6 PPM: red, green, blue, white. Sniffed by AUTO. */
  static const unsigned char ppm[] = {
    'P', '6', '\n', '2', ' ', '2', '\n', '2', '5', '5', '\n',
    0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00,
    0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF
  };
  up_percept img = NULL;
  assert(up_decode(ppm, sizeof ppm, UP_PERCEPT_FMT_AUTO, &img) == UP_PERCEPT_OK);
  assert(img != NULL);
  assert(up_image_width(img) == 2);
  assert(up_image_height(img) == 2);
  assert(up_image_channels(img) == 3);

  /* Pure grayscale and resize kernels expose the same bytes as Nim. */
  unsigned char* gray = NULL;
  size_t graylen = 0;
  assert(up_grayscale(ppm + 11, 12, 2, 2, 3, &gray, &graylen) ==
         UP_PERCEPT_OK);
  assert(graylen == 4 && gray[0] == 76 && gray[1] == 149 &&
         gray[2] == 29 && gray[3] == 255);
  unsigned char* resized = NULL;
  size_t resizedlen = 0;
  assert(up_resize_gray(gray, graylen, 2, 2, 8, 8, &resized, &resizedlen) ==
         UP_PERCEPT_OK);
  assert(resizedlen == 64);
  up_buffer_free(resized, resizedlen);
  resized = (unsigned char*)1;
  resizedlen = 1;
  assert(up_resize_gray(ppm, sizeof ppm, 1, 1, INT_MAX, INT_MAX,
                        &resized, &resizedlen) == UP_PERCEPT_ERR_MEM);
  assert(resized == NULL && resizedlen == 0);
  uint64_t gray_hash = 0;
  assert(up_phash_gray(gray, graylen, 2, 2, &gray_hash) == UP_PERCEPT_OK);
  up_buffer_free(gray, graylen);

  /* Hashes are non-zero (12 distinct pixels) and self-equal under Hamming. */
  uint64_t a = up_ahash(img);
  uint64_t d = up_dhash(img);
  uint64_t p = up_phash(img);
  assert(a != 0 && d != 0 && p != 0);
  assert(up_hamming(a, a) == 0);
  assert(up_hamming(d, d) == 0);
  assert(up_hamming(p, p) == 0);
  assert(gray_hash == p);

  /* Dimension products that cannot fit a Nim sequence are rejected. */
  gray = (unsigned char*)1;
  graylen = 1;
  assert(up_grayscale(ppm, sizeof ppm, INT_MAX, INT_MAX, INT_MAX,
                      &gray, &graylen) == UP_PERCEPT_ERR_FORMAT);
  assert(gray == NULL && graylen == 0);

  char hex[17];
  assert(up_hash_hex(p, NULL, 0) == sizeof hex);
  assert(up_hash_hex(p, hex, sizeof hex) == sizeof hex);
  assert(strlen(hex) == 16);
  char short_hex[2] = {'x', 'y'};
  assert(up_hash_hex(p, short_hex, sizeof short_hex) == sizeof hex);
  assert(short_hex[0] == 'x' && short_hex[1] == 'y');
  static const unsigned char known_bytes[] = {0x00, 0xAB, 0xFF};
  char bytes_hex[7];
  assert(up_bytes_hex(known_bytes, sizeof known_bytes, bytes_hex,
                      sizeof bytes_hex) == sizeof bytes_hex);
  assert(strcmp(bytes_hex, "00abff") == 0);

  /* A distinct image (all-blue) differs from the mixed PPM. */
  static const unsigned char blue[] = {
    'P', '6', '\n', '2', ' ', '2', '\n', '2', '5', '5', '\n',
    0x00, 0x00, 0xFF, 0x00, 0x00, 0xFF,
    0x00, 0x00, 0xFF, 0x00, 0x00, 0xFF
  };
  up_percept bimg = NULL;
  assert(up_decode(blue, sizeof blue, UP_PERCEPT_FMT_AUTO, &bimg) ==
         UP_PERCEPT_OK);
  uint64_t a2 = up_ahash(bimg);
  assert(a2 != a);
  assert(up_hamming(a, a2) > 0);

  /* blockhash(16) -> 32 bytes; out-of-range bits -> ERR_FORMAT. */
  unsigned char* bh = NULL;
  size_t bhlen = 0;
  assert(up_blockhash(img, 16, &bh, &bhlen) == UP_PERCEPT_OK);
  assert(bh != NULL && bhlen == 32);
  up_buffer_free(bh, bhlen);

  bh = (unsigned char*)1; bhlen = 1;
  assert(up_blockhash(img, 0, &bh, &bhlen) == UP_PERCEPT_ERR_FORMAT);
  assert(bh == NULL && bhlen == 0);
  assert(up_blockhash(img, UP_PERCEPT_MAX_BLOCK_BITS + 1, &bh, &bhlen) ==
         UP_PERCEPT_ERR_FORMAT);
  assert(bh == NULL && bhlen == 0);

  /* Max bound is accepted (256x256 -> 8192 bytes). */
  assert(up_blockhash(img, UP_PERCEPT_MAX_BLOCK_BITS, &bh, &bhlen) ==
         UP_PERCEPT_OK);
  assert(bh != NULL && bhlen == (256 * 256 + 7) / 8);
  up_buffer_free(bh, bhlen);

  /* Junk input is rejected. */
  static const unsigned char junk[] = {0x00, 0x01, 0x02, 0x03};
  up_percept j = NULL;
  assert(up_decode(junk, sizeof junk, UP_PERCEPT_FMT_AUTO, &j) ==
         UP_PERCEPT_ERR_FORMAT);
  assert(j == NULL);

  /* --- bk-tree index (up_index_*) --- */
  up_percept_index idx = NULL;
  assert(up_index_new(&idx) == UP_PERCEPT_OK);
  assert(idx != NULL);
  /* NULL-safety: bad handle rejected, out-params cleared, free(NULL) no-op. */
  assert(up_index_insert(NULL, 0, 0ULL) == UP_PERCEPT_ERR_FORMAT);
  assert(up_index_insert((up_percept_index)1, 0, 0ULL) ==
         UP_PERCEPT_ERR_FORMAT);
  int32_t* qids = (int32_t*)1; size_t qn = 1;
  assert(up_index_query(NULL, 0ULL, 0, &qids, &qn) == UP_PERCEPT_ERR_FORMAT);
  assert(qids == NULL && qn == 0);
  up_index_free(NULL);
  up_index_free((up_percept_index)1);

  /* Hashes at known Hamming distances from 0: 100@0, 101@1, 102@3 (d2), 103@all-ones (d64). */
  assert(up_index_insert(idx, 100, 0ULL) == UP_PERCEPT_OK);
  assert(up_index_insert(idx, 101, 1ULL) == UP_PERCEPT_OK);
  assert(up_index_insert(idx, 102, 3ULL) == UP_PERCEPT_OK);
  assert(up_index_insert(idx, 103, 0xFFFFFFFFFFFFFFFFULL) == UP_PERCEPT_OK);
  assert(up_index_len(idx) == 4);

  /* radius 0 -> exact match only (id 100, dist 0). */
  qids = NULL; qn = 0;
  assert(up_index_query(idx, 0ULL, 0, &qids, &qn) == UP_PERCEPT_OK);
  assert(qn == 1 && qids[0] == 100 && qids[1] == 0);
  up_buffer_free((unsigned char*)qids, qn * 2 * sizeof(int32_t));

  /* radius 1 -> ids 100 (d0) and 101 (d1); scan the interleaved buffer. */
  qids = NULL; qn = 0;
  assert(up_index_query(idx, 0ULL, 1, &qids, &qn) == UP_PERCEPT_OK);
  assert(qn == 2);
  int found100 = 0, found101 = 0;
  for (size_t k = 0; k < qn; ++k) {
    if (qids[k * 2] == 100 && qids[k * 2 + 1] == 0) found100 = 1;
    if (qids[k * 2] == 101 && qids[k * 2 + 1] == 1) found101 = 1;
  }
  assert(found100 && found101);
  up_buffer_free((unsigned char*)qids, qn * 2 * sizeof(int32_t));

  /* radius 64 -> all four matches. */
  qids = NULL; qn = 0;
  assert(up_index_query(idx, 0ULL, 64, &qids, &qn) == UP_PERCEPT_OK);
  assert(qn == 4);
  up_buffer_free((unsigned char*)qids, qn * 2 * sizeof(int32_t));
  qids = (int32_t*)1; qn = 1;
  assert(up_index_query(idx, 0ULL, -1, &qids, &qn) == UP_PERCEPT_ERR_FORMAT);
  assert(qids == NULL && qn == 0);

  up_index_free(idx);
  up_index_free(idx);  /* stale handles and double-free are benign */

  /* ABI drift check. */
  assert(up_abi_version() == UNIPERCEPT_ABI_VERSION);
  assert(strcmp(up_version(), UNIPERCEPT_VERSION) == 0);

  up_free(img);
  up_free(img);  /* stale handles and double-free are benign */
  up_free(bimg);

  printf("capi test OK (ABI v%d, %s)\n", up_abi_version(), up_version());
  return 0;
}
