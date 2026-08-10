<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0001: UniPercept dependency direction

- Status: Accepted
- Date: 2026-07-15
- Scope: UniPercept

## Decision

UniPercept depends on UniImage for decoding. UniImage never imports
UniPercept. The internal kernels remain independent of decoding:

```text
gray -> resize -> hashes -> bktree
                         \
UniImage -> decode ------> facade -> c_api
```

## Invariants

1. Only `decode.nim` and the foreign boundary import UniImage.
2. Grayscale, resize, hashes, and BK-tree remain usable without a codec.
3. UniPercept does not duplicate UniImage image types or decoders.
4. UniPercept never imports an application.
5. NimContracts and UniImage track their maintained `main` branches, matching
   the family development contract used by the package manifest.
