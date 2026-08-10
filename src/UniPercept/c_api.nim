# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## C ABI for UniPercept. Built --app:staticlib/--app:lib --noMain --mm:arc
## -d:release. Keep in sync with include/UniPercept.h; tests/c links the header
## against this lib.
##
## Conventions (see the header for the authoritative contract):
##   * Call `up_init()` exactly once per process before anything else (it runs
##     the Nim runtime initialiser).
##   * Handles are opaque `void*`. The library owns them; free with `up_free`.
##     `up_blockhash` allocates a C-owned buffer; free it with `up_buffer_free`.
##   * No Nim exception or Defect crosses the ABI: every entry point traps both
##     and maps them to an `UP_PERCEPT_*` code. The ABI is decode-only, so every
##     `UniImageException` maps to `UP_PERCEPT_ERR_FORMAT` (there is no
##     encode-side UNSUP case to distinguish, unlike UniImage's `ui_image_*`).
import UniPercept
import std/[sets, locks]
import UniImage ## for the `Image[uint8]` type held in the handle; Nim does not
              ## re-export a foreign generic type through the facade's `export`
              ## chain, so the engine facade is imported directly (vgraph-clean:
              ## UniImage is an engine, not a layer).

when defined(danger):
  {.warning: "libUniPercept built with -d:danger: bounds checks are off and the " &
    "Defect backstops at the ABI boundary cannot fire. Prefer -d:release for a " &
    "hardened parser facing untrusted input.".}

const UniPerceptAbiVersion = 1

type
  ImgHandle = ref object
    img: Image[uint8]
  IndexHandle = ref object
    tree: BkTree

proc NimMain() {.importc.}

proc imgOf(p: pointer): ImgHandle {.inline.} = cast[ImgHandle](p)
proc indexOf(p: pointer): IndexHandle {.inline.} = cast[IndexHandle](p)

var
  handleLock: Lock
  imageHandles, indexHandles: HashSet[pointer]

initLock(handleLock)

proc registerHandle(handles: var HashSet[pointer]; h: pointer) =
  withLock handleLock:
    handles.incl h

proc containsHandle(handles: var HashSet[pointer]; h: pointer): bool =
  if h == nil: return false
  withLock handleLock:
    result = h in handles

proc unregisterHandle(handles: var HashSet[pointer]; h: pointer): bool =
  if h == nil: return false
  withLock handleLock:
    result = h in handles
    if result: handles.excl h

# Status codes — keep in sync with `up_percept_status` in UniPercept.h.
const
  UP_PERCEPT_OK = cint(0)
  UP_PERCEPT_ERR_FORMAT = cint(2)         # bad arg / unrecognized / truncated / bad handle
  UP_PERCEPT_ERR_UNSUP {.used.} = cint(4) # reserved; the ABI is decode-only
  UP_PERCEPT_ERR_MEM = cint(8)            # allocation failed

# Format hint — keep in sync with `up_percept_format` in UniPercept.h.
const
  UP_PERCEPT_FMT_AUTO {.used.} = cint(0) # decode default (the else branch)
  UP_PERCEPT_FMT_TGA = cint(8)           # TGA has no magic; needs the hint

{.push exportc, cdecl, dynlib.}

proc up_init() =
  ## Initialise the Nim runtime. Must be called once before any other function.
  try:
    NimMain()
  except CatchableError, Defect:
    discard

proc up_abi_version(): cint = cint(UniPerceptAbiVersion)

proc up_strerror(code: cint): cstring =
  case code
  of 0: cstring"ok"
  of 2: cstring"bad argument / unrecognized / truncated"
  of 4: cstring"unsupported operation"
  of 8: cstring"out of memory"
  else: cstring"unknown error"

proc up_version(): cstring =
  ## Static engine version string; do not free. Never raises.
  cstring(UniPerceptVersion)

proc up_decode(data: ptr uint8; length: csize_t; fmt: cint;
    outHandle: ptr pointer): cint =
  ## Decode an in-memory image. `fmt=UP_PERCEPT_FMT_AUTO` sniffs the magic;
  ## `UP_PERCEPT_FMT_TGA` decodes TGA (no magic). On success stores an opaque
  ## handle (free with up_free).
  if outHandle == nil: return UP_PERCEPT_ERR_FORMAT
  outHandle[] = nil
  if data == nil or length == 0 or length > csize_t(high(int)):
    return UP_PERCEPT_ERR_FORMAT
  if fmt notin [UP_PERCEPT_FMT_AUTO, UP_PERCEPT_FMT_TGA]:
    return UP_PERCEPT_ERR_FORMAT
  try:
    let arr = cast[ptr UncheckedArray[byte]](data)
    let img = if fmt == UP_PERCEPT_FMT_TGA:
      decodeTga(arr.toOpenArray(0, int(length) - 1)) else:
      loadImageFromMemory(arr.toOpenArray(0, int(length) - 1))
    let h = ImgHandle(img: img)
    let p = cast[pointer](h)
    registerHandle(imageHandles, p)
    GC_ref(h)
    outHandle[] = p
    UP_PERCEPT_OK
  except UniImageException:
    UP_PERCEPT_ERR_FORMAT
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_image_width(h: pointer): cint =
  if not containsHandle(imageHandles, h): return 0
  cint(imgOf(h).img.width)

proc up_image_height(h: pointer): cint =
  if not containsHandle(imageHandles, h): return 0
  cint(imgOf(h).img.height)

proc up_image_channels(h: pointer): cint =
  if not containsHandle(imageHandles, h): return 0
  cint(imgOf(h).img.channels)

proc up_ahash(h: pointer): uint64 =
  ## Average hash, or 0 on a nil handle / failure. Never raises.
  if not containsHandle(imageHandles, h): return 0'u64
  try:
    let hh = imgOf(h)
    let g = toGrayscale(hh.img.data, hh.img.width, hh.img.height,
        hh.img.channels)
    uint64(aHash(g))
  except CatchableError, Defect:
    0'u64

proc up_dhash(h: pointer): uint64 =
  ## Difference hash, or 0 on a nil handle / failure. Never raises.
  if not containsHandle(imageHandles, h): return 0'u64
  try:
    let hh = imgOf(h)
    let g = toGrayscale(hh.img.data, hh.img.width, hh.img.height,
        hh.img.channels)
    uint64(dHash(g))
  except CatchableError, Defect:
    0'u64

proc up_phash(h: pointer): uint64 =
  ## Perceptual hash (DCT), or 0 on a nil handle / failure. Never raises.
  if not containsHandle(imageHandles, h): return 0'u64
  try:
    let hh = imgOf(h)
    let g = toGrayscale(hh.img.data, hh.img.width, hh.img.height,
        hh.img.channels)
    uint64(pHash(g))
  except CatchableError, Defect:
    0'u64

proc up_blockhash(h: pointer; bits: cint; outData: ptr ptr uint8;
    outLen: ptr csize_t): cint =
  ## Blockhash at `bits`x`bits` (1..UP_PERCEPT_MAX_BLOCK_BITS). On success
  ## allocates *outData (free with up_buffer_free) and sets *outLen to
  ## `(bits*bits + 7) div 8`. Out-of-range `bits` returns UP_PERCEPT_ERR_FORMAT
  ## in every build — the kernel's `require` is a debug-only backstop, so the ABI
  ## never relies on it.
  if outData == nil or outLen == nil: return UP_PERCEPT_ERR_FORMAT
  outData[] = nil
  outLen[] = 0
  if not containsHandle(imageHandles, h): return UP_PERCEPT_ERR_FORMAT
  if bits <= 0 or bits > cint(MaxBlockBits): return UP_PERCEPT_ERR_FORMAT
  try:
    let hh = imgOf(h)
    let g = toGrayscale(hh.img.data, hh.img.width, hh.img.height,
        hh.img.channels)
    let bh = blockhash(g, int(bits))
    if bh.len == 0: return UP_PERCEPT_ERR_FORMAT # defensive; can't happen post-validate
    let buf = allocShared(bh.len) # C-owned; freed by up_buffer_free
    if buf == nil: return UP_PERCEPT_ERR_MEM
    copyMem(buf, unsafeAddr bh[0], bh.len)
    outData[] = cast[ptr uint8](buf)
    outLen[] = csize_t(bh.len)
    UP_PERCEPT_OK
  except UniImageException:
    UP_PERCEPT_ERR_FORMAT
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_hamming(a, b: uint64): cint =
  ## Hamming distance (popcount of XOR). Never raises.
  cint(hammingDistance(a, b))

proc up_index_new(outHandle: ptr pointer): cint =
  ## Create an empty bk-tree index. On success stores an opaque handle (free
  ## with up_index_free).
  if outHandle == nil: return UP_PERCEPT_ERR_FORMAT
  outHandle[] = nil
  try:
    let h = IndexHandle(tree: initBkTree())
    let p = cast[pointer](h)
    registerHandle(indexHandles, p)
    GC_ref(h)
    outHandle[] = p
    UP_PERCEPT_OK
  except CatchableError, Defect:
    UP_PERCEPT_ERR_MEM

proc up_index_insert(idx: pointer; id: int32; h: uint64): cint =
  ## Insert `id` at hash `h` into the index. Never raises.
  if not containsHandle(indexHandles, idx): return UP_PERCEPT_ERR_FORMAT
  try:
    indexOf(idx).tree.insert(Hash(h), id)
    UP_PERCEPT_OK
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_index_query(idx: pointer; h: uint64; radius: cint;
    outIds: ptr ptr int32; outCount: ptr csize_t): cint =
  ## Query the index for hashes within Hamming `radius` of `h`. On success
  ## allocates *outIds as `2 * *outCount` int32s, interleaved
  ## `[id0, dist0, id1, dist1, ...]` (free with up_buffer_free); *outCount is the
  ## number of matches. A nil index or out-param returns UP_PERCEPT_ERR_FORMAT.
  if outIds == nil or outCount == nil: return UP_PERCEPT_ERR_FORMAT
  outIds[] = nil
  outCount[] = 0
  if not containsHandle(indexHandles, idx): return UP_PERCEPT_ERR_FORMAT
  try:
    let res = indexOf(idx).tree.query(Hash(h), int(radius))
    outCount[] = csize_t(res.len)
    if res.len == 0: return UP_PERCEPT_OK
    let buf = allocShared(res.len * 2 * sizeof(int32))
    if buf == nil: return UP_PERCEPT_ERR_MEM
    let dst = cast[ptr UncheckedArray[int32]](buf)
    for i in 0 ..< res.len:
      dst[i * 2] = res[i][0]
      dst[i * 2 + 1] = int32(res[i][1])
    outIds[] = cast[ptr int32](buf)
    UP_PERCEPT_OK
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_index_free(idx: pointer) =
  ## Free an index handle. NULL is a no-op.
  if unregisterHandle(indexHandles, idx): GC_unref(indexOf(idx))

proc up_free(h: pointer) =
  ## Free a handle. NULL is a no-op.
  if unregisterHandle(imageHandles, h): GC_unref(imgOf(h))

proc up_buffer_free(p: ptr uint8; len: csize_t) =
  ## Free a buffer returned by up_blockhash. NULL is a no-op. `len` is ignored
  ## (kept for symmetry with the allocator).
  if p != nil: deallocShared(p)

{.pop.}

