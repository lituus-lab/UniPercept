<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniPercept

Perceptual image hashing for the `lituus-lab` Uni* family. UniPercept decodes
rasters via `UniImage` and layers the fixed-point grayscale, resize, and hash
kernels that make hashes deterministic across CPUs: `aHash`, `dHash`, `pHash`,
and `blockhash`, plus Hamming distance / similarity.

## Layout

```text
src/UniPercept.nim            umbrella (facade: computeHashes, phashInfo, toHex)
src/UniPercept/gray.nim       grayscale (fixed-point luma)
src/UniPercept/resize.nim     grayscale box resize (fixed-point)
src/UniPercept/hashes.nim     aHash/dHash/pHash/blockhash + hamming/similarity
src/UniPercept/decode.nim     UniImage-backed decode (the only UniImage importer)
src/UniPercept/c_api.nim      C ABI (up_*)
include/UniPercept.h          hand-written C header
tests/test_percept.nim        Nim tests
tests/c/                      C ABI test (links the header against the lib)
examples/                     Nim + C demos
py/                           Cython binding + pytest
ADRs/                         0001 DAG, 0002 license, 0003 engine&shell, 0004 conventions
.github/workflows/ci.yml      3-OS Nim matrix + C ABI + Python
```

## Build

```bash
nimble install -y
nimble test           # Nim, debug (contracts active)
nimble testRelease    # Nim, release (contracts compiled away)
nimble testAll        # debug + release + C ABI
nimble ctest          # C ABI: static lib + tests/c
nimble cexample       # C demo
nimble example        # Nim demo
nimble pyTest         # Cython + pytest
nimble coverage       # gcov + lcov -> coverage/
nimble book           # nimib book -> book/index.html
nimble docs           # book + API reference -> pages/
nimble checkVGraph    # enforce the layer DAG in vgraph.cfg
```

## Dependency on UniImage

UniPercept's only engine edge is `UniPercept --> UniImage`. UniImage is pushed
to `lituus-lab/UniImage` but untagged, so during the transition it is consumed
via a relative path (`config.nims`: `--path:../UniImage/src`), not a nimble
`requires`. Once UniImage is tagged, switch to
`requires "https://github.com/lituus-lab/UniImage#<sha>"` and drop the path
switch. `vgraph.cfg` declares `[engines] = UniImage`.

## Decode reuse

`phashInfo(path)` returns the pHash together with the decoded width and height.
Consumers that index both values should use it instead of decoding the same
file twice. The existing `phash(path)` helper remains the hash-only façade and
delegates to the same implementation.

## CI

`test`, `cabi` and `python` on ubuntu/macOS/Windows. `consume-cabi` and
`consume-wheel` rebuild against the published artifacts on a machine without Nim,
so what ships is what was tested. `coverage` and `docs` run on ubuntu.

`dco` blocks PRs missing a `Signed-off-by` trailer; `commitizen` blocks PRs whose
commits or title are not [Conventional Commits](https://www.conventionalcommits.org/)
(`CONTRIBUTING.md`).

## Anti-goals

- **No codec of its own.** Decode is UniImage's job; UniPercept imports
  `UniImage/formats` and stops there. Adding a decoder here is a back-edge.
- **No parallelism in v1.** The engine is single-threaded (mirrors UniImage).
  Walk-and-hash parallelism is an app-layer concern; `malebolgia` is not a dep.
- **No float resize in the hash pipeline.** UniImage's bilinear/box resize is
  RGB-float and would change every hash value. The grayscale resize stays a
  local fixed-point box filter, byte-identical to the legacy implementation.
- **Unified decoding.** The former decoder FFI is dropped; UniImage replaces
  it. NOTICE carries no vendored attribution.

## AI-assisted contributions

Assistance from AI/LLM tools is welcome on the same terms as any other
contribution.

- **Accountability.** The human contributor is the author and remains fully
  responsible for the change. The DCO sign-off (`Signed-off-by`) is the mechanism:
  by signing you certify the content is yours or properly licensed — this covers
  AI-assisted work, provided you can stand behind it.
- **No third-party contamination.** Ensure AI output introduces no code from a
  third party without a compatible license and attribution. If an LLM reproduced
  protected material, do not submit it.
- **Correctness is yours.** The gates (tests, `nimble lint`, conventional commits,
  pre-commit) catch a lot, but you own the result — review and verify what you
  commit.
- **Atomic commits.** Each commit is one logical change. A PR may stack
  several atomic commits (one per element, say) — one monolithic big-bang
  commit is not.
- **Disclosure.** State in the PR whether AI assistance was used (see the PR
  template). It is not a hard requirement — the DCO remains the gate.

## License

Apache-2.0 (`LICENSE`). DCO sign-off on every commit (`CONTRIBUTING.md`).
>>>>>>> d56e71b (feat: add perceptual image hashing engine)
