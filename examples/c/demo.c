// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/* demo.c — minimal C consumer of the up_* ABI. Decode a 2x2 PPM, print the
 * perceptual hashes, the Hamming self-distance, and a blockhash. A demo
 * prints; it does not assert. Build/run via `nimble cexample`. */
#include <stdio.h>
#include "UniPercept.h"

int main(void) {
  up_init();

  /* A 2x2 RGB P6 PPM: red, green, blue, white. Sniffed by AUTO. */
  static const unsigned char ppm[] = {
    'P', '6', '\n', '2', ' ', '2', '\n', '2', '5', '5', '\n',
    0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00,
    0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF
  };

  up_percept img = NULL;
  if (up_decode(ppm, sizeof ppm, UP_PERCEPT_FMT_AUTO, &img) != UP_PERCEPT_OK) {
    fprintf(stderr, "decode failed\n");
    return 1;
  }

  printf("UniPercept %s (ABI v%d)\n", up_version(), up_abi_version());
  printf("image  %dx%d, %d channels\n", up_image_width(img),
         up_image_height(img), up_image_channels(img));

  uint64_t a = up_ahash(img);
  uint64_t d = up_dhash(img);
  uint64_t p = up_phash(img);
  printf("aHash  %016llx\n", (unsigned long long)a);
  printf("dHash  %016llx\n", (unsigned long long)d);
  printf("pHash  %016llx\n", (unsigned long long)p);
  printf("hamming(a, a) = %d\n", up_hamming(a, a));

  unsigned char* bh = NULL;
  size_t bhlen = 0;
  if (up_blockhash(img, 16, &bh, &bhlen) == UP_PERCEPT_OK) {
    printf("blockhash(16) = %zu bytes, first byte %02x\n", bhlen, bh[0]);
    up_buffer_free(bh, bhlen);
  }

  up_free(img);
  return 0;
}