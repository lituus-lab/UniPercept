<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# Security Policy

Report vulnerabilities via GitHub private vulnerability reporting (Security
tab → "Report a vulnerability"), not via a public issue. Include: description
and impact, minimal reproducer, affected version (`up_version()`).

Only the latest released line is supported. The C ABI is public and versioned;
applications should check `up_abi_version()` before use.

## Surface

- C ABI trusts its callers for pointer validity and never raises across the
  boundary. Inputs are clamped only where a function documents it; invalid
  values otherwise return the applicable `UP_*` status, including
  `UP_PERCEPT_ERR_FORMAT` for invalid blockhash sizes.
- Python binding adds the domain check and raises `ValueError`/`TypeError`.
- Call `up_init()` once before the other ABI functions and externally
  synchronize its first invocation. After initialization, independent immutable
  hash operations are reentrant; handle creation, destruction, and mutation are
  not safe concurrently without external synchronization.
