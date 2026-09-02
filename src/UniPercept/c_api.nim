# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## C ABI for UniPercept. Built --app:staticlib/--app:lib --noMain --mm:arc
## -d:release. Keep in sync with include/UniPercept.h; tests/c links the header
## against this lib.
##
## Conventions (see the header for the authoritative contract):
##   * Call `up_init()` before anything else. Repeated calls are no-ops; the
##     first call must be externally synchronized.
##   * Handles are opaque `void*`. The library owns them; free with `up_free`.
##     `up_blockhash` allocates a C-owned buffer; free it with `up_buffer_free`.
##   * No Nim exception or Defect crosses the ABI: every entry point traps both
##     and maps them to an `UP_PERCEPT_*` code. The ABI is decode-only, so every
##     `UniImageException` maps to `UP_PERCEPT_ERR_FORMAT` (there is no
##     encode-side UNSUP case to distinguish, unlike UniImage's `ui_image_*`).
import UniPercept
import std/[sets, locks]

when defined(danger):
  {.error: "libUniPercept must not be built with -d:danger; use -d:release".}

const UniPerceptAbiVersion = 2

type
  ImgHandle = ref object
    img: DecodedImage
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

proc grayFromC(data: ptr uint8; length: csize_t; width,
    height: cint): GrayscaleImage =
  if width < 0 or height < 0:
    raise newException(ValueError, "negative grayscale dimensions")
  let count = int64(width) * int64(height)
  if count > int64(high(int)) or csize_t(count) != length:
    raise newException(ValueError, "inconsistent grayscale buffer")
  if count > 0 and data == nil:
    raise newException(ValueError, "nil grayscale buffer")
  result = GrayscaleImage(width: int(width), height: int(height),
      pixels: newSeq[byte](int(count)))
  if count > 0:
    copyMem(addr result.pixels[0], data, int(count))

proc copyToShared(data: openArray[byte]): ptr uint8 =
  if data.len == 0: return nil
  let p = allocShared(data.len)
  if p == nil: raise newException(OutOfMemDefect, "allocation failed")
  copyMem(p, unsafeAddr data[0], data.len)
  cast[ptr uint8](p)

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


# --noMain suppresses the generated entry point and with it every auto-init
# hook: neither the static nor the shared build emits a DllMain or an ELF
# constructor, so nothing initializes the Nim runtime. The first entry point
# then enters Nim code whose globals were never set up. The shared build was
# assumed to be covered by a loader hook it does not have -- its registries
# stayed empty and the contrast entry answered nan. Every --noMain task passes
# -d:noAutoInit; an ordinary executable linking this module must not, since its
# own main already ran NimMain.
when defined(noAutoInit):
  # A once primitive, not a plain flag: two threads reaching an entry point
  # together would both see the flag unset, both call NimMain, and the second
  # would enter Nim code the first had not finished initializing. The platform
  # primitives block the losers until the winner returns, which a flag cannot.
  #
  # C statics, not Nim globals: module initialization would reset a Nim one and
  # NimMain would run again. NimMain is declared here too — the generated
  # prototype comes after this section.
  {.emit: """/*VARSECTION*/
void NimMain(void);
#ifdef _WIN32
#  include <windows.h>
static INIT_ONCE up_runtime_once = INIT_ONCE_STATIC_INIT;
static BOOL CALLBACK up_runtime_init(PINIT_ONCE o, PVOID p, PVOID *c) {
  (void)o; (void)p; (void)c; NimMain(); return TRUE;
}
static void up_runtime_ensure(void) {
  InitOnceExecuteOnce(&up_runtime_once, up_runtime_init, NULL, NULL);
}
#else
#  include <pthread.h>
static pthread_once_t up_runtime_once = PTHREAD_ONCE_INIT;
static void up_runtime_init(void) { NimMain(); }
static void up_runtime_ensure(void) {
  pthread_once(&up_runtime_once, up_runtime_init);
}
#endif
""".}
  template ensureRuntime() =
    {.emit: "  up_runtime_ensure();".}
else:
  template ensureRuntime() = discard


{.push exportc, cdecl, dynlib.}

proc up_init() =
  ## Initialise the Nim runtime. The first call must be externally synchronized.
  ##
  ## The work is `ensureRuntime`, which every entry point calls. It used to be
  ## followed by a direct NimMain, so under -d:noAutoInit the module
  ## initializers ran twice, rebuilding every global while the first set was
  ## still live -- and the flag meant to prevent it was itself a Nim global,
  ## which that second run reset. Reproduced in UniColor: the second
  ## `uc_palette_make` of a process died inside Nim's allocator.
  ensureRuntime()

proc up_abi_version(): cint =
  ensureRuntime()
  cint(UniPerceptAbiVersion)

proc up_strerror(code: cint): cstring =
  ensureRuntime()
  case code
  of UP_PERCEPT_OK: cstring"ok"
  of UP_PERCEPT_ERR_FORMAT: cstring"bad argument / unrecognized / truncated"
  of UP_PERCEPT_ERR_UNSUP: cstring"unsupported operation"
  of UP_PERCEPT_ERR_MEM: cstring"out of memory"
  else: cstring"unknown error"

proc up_version(): cstring =
  ## Static engine version string; do not free. Never raises.
  ensureRuntime()
  cstring(UniPerceptVersion)

proc up_grayscale(data: ptr uint8; length: csize_t; width, height,
    channels: cint; outData: ptr ptr uint8; outLen: ptr csize_t): cint =
  ensureRuntime()
  if outData == nil or outLen == nil: return UP_PERCEPT_ERR_FORMAT
  outData[] = nil
  outLen[] = 0
  if width < 0 or height < 0 or channels <= 0: return UP_PERCEPT_ERR_FORMAT
  let count = int64(width) * int64(height)
  if count > int64(high(int)) or
      (channels > 0 and count > int64(high(int)) div int64(channels)):
    return UP_PERCEPT_ERR_FORMAT
  let needed = count * int64(channels)
  if needed > int64(length) or (needed > 0 and data == nil):
    return UP_PERCEPT_ERR_FORMAT
  try:
    var input = newSeq[byte](int(needed))
    if needed > 0: copyMem(addr input[0], data, int(needed))
    let gray = toGrayscale(input, int(width), int(height), int(channels))
    outData[] = copyToShared(gray.pixels)
    outLen[] = csize_t(gray.pixels.len)
    UP_PERCEPT_OK
  except OutOfMemDefect:
    UP_PERCEPT_ERR_MEM
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_resize_gray(data: ptr uint8; length: csize_t; width, height,
    newWidth, newHeight: cint; outData: ptr ptr uint8;
    outLen: ptr csize_t): cint =
  ensureRuntime()
  if outData == nil or outLen == nil: return UP_PERCEPT_ERR_FORMAT
  outData[] = nil
  outLen[] = 0
  if newWidth < 0 or newHeight < 0: return UP_PERCEPT_ERR_FORMAT
  let outputCount = int64(newWidth) * int64(newHeight)
  if outputCount > int64(high(cint)): return UP_PERCEPT_ERR_MEM
  try:
    let resized = resize(grayFromC(data, length, width, height),
        int(newWidth), int(newHeight))
    outData[] = copyToShared(resized.pixels)
    outLen[] = csize_t(resized.pixels.len)
    UP_PERCEPT_OK
  except OutOfMemDefect:
    UP_PERCEPT_ERR_MEM
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_ahash_gray(data: ptr uint8; length: csize_t; width, height: cint;
    outHash: ptr uint64): cint =
  ensureRuntime()
  if outHash == nil: return UP_PERCEPT_ERR_FORMAT
  try:
    outHash[] = uint64(aHash(grayFromC(data, length, width, height)))
    UP_PERCEPT_OK
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_dhash_gray(data: ptr uint8; length: csize_t; width, height: cint;
    outHash: ptr uint64): cint =
  ensureRuntime()
  if outHash == nil: return UP_PERCEPT_ERR_FORMAT
  try:
    outHash[] = uint64(dHash(grayFromC(data, length, width, height)))
    UP_PERCEPT_OK
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_phash_gray(data: ptr uint8; length: csize_t; width, height: cint;
    outHash: ptr uint64): cint =
  ensureRuntime()
  if outHash == nil: return UP_PERCEPT_ERR_FORMAT
  try:
    outHash[] = uint64(pHash(grayFromC(data, length, width, height)))
    UP_PERCEPT_OK
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_blockhash_gray(data: ptr uint8; length: csize_t; width, height,
    bits: cint; outData: ptr ptr uint8; outLen: ptr csize_t): cint =
  ensureRuntime()
  if outData == nil or outLen == nil: return UP_PERCEPT_ERR_FORMAT
  outData[] = nil
  outLen[] = 0
  if bits <= 0 or bits > cint(MaxBlockBits): return UP_PERCEPT_ERR_FORMAT
  try:
    let value = blockhash(grayFromC(data, length, width, height), int(bits))
    outData[] = copyToShared(value)
    outLen[] = csize_t(value.len)
    UP_PERCEPT_OK
  except OutOfMemDefect:
    UP_PERCEPT_ERR_MEM
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_similarity(a, b: uint64): cdouble =
  ensureRuntime()
  cdouble(similarity(Hash(a), Hash(b)))

proc up_hash_hex(hash: uint64; outText: ptr char; capacity: csize_t): csize_t =
  ensureRuntime()
  const Required = 17
  try:
    if outText != nil and capacity >= Required:
      let value = toHex(Hash(hash))
      copyMem(outText, unsafeAddr value[0], value.len)
      cast[ptr UncheckedArray[char]](outText)[value.len] = '\0'
    csize_t(Required)
  except CatchableError, Defect:
    0

proc up_bytes_hex(data: ptr uint8; length: csize_t; outText: ptr char;
    capacity: csize_t): csize_t =
  ensureRuntime()
  if length > csize_t((high(int) - 1) div 2): return 0
  let required = int(length) * 2 + 1
  if length > 0 and data == nil: return 0
  try:
    if outText != nil and capacity >= csize_t(required):
      var bytes = newSeq[byte](int(length))
      if length > 0: copyMem(addr bytes[0], data, int(length))
      let value = toHex(bytes)
      if value.len > 0: copyMem(outText, unsafeAddr value[0], value.len)
      cast[ptr UncheckedArray[char]](outText)[value.len] = '\0'
    csize_t(required)
  except CatchableError, Defect:
    0

proc up_decode(data: ptr uint8; length: csize_t; fmt: cint;
    outHandle: ptr pointer): cint =
  ## Decode an in-memory image. `fmt=UP_PERCEPT_FMT_AUTO` sniffs the magic;
  ## `UP_PERCEPT_FMT_TGA` decodes TGA (no magic). On success stores an opaque
  ## handle (free with up_free).
  ensureRuntime()
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

proc up_decode_file(path: cstring; outHandle: ptr pointer): cint =
  ensureRuntime()
  if outHandle == nil: return UP_PERCEPT_ERR_FORMAT
  outHandle[] = nil
  if path == nil or path[0] == '\0': return UP_PERCEPT_ERR_FORMAT
  try:
    let h = ImgHandle(img: loadImage($path))
    let p = cast[pointer](h)
    registerHandle(imageHandles, p)
    GC_ref(h)
    outHandle[] = p
    UP_PERCEPT_OK
  except UniImageException, IOError, OSError:
    UP_PERCEPT_ERR_FORMAT
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_image_width(h: pointer): cint =
  ensureRuntime()
  if not containsHandle(imageHandles, h): return 0
  try: cint(imgOf(h).img.width)
  except CatchableError, Defect: 0

proc up_image_height(h: pointer): cint =
  ensureRuntime()
  if not containsHandle(imageHandles, h): return 0
  try: cint(imgOf(h).img.height)
  except CatchableError, Defect: 0

proc up_image_channels(h: pointer): cint =
  ensureRuntime()
  if not containsHandle(imageHandles, h): return 0
  try: cint(imgOf(h).img.channels)
  except CatchableError, Defect: 0

proc up_ahash(h: pointer): uint64 =
  ## Average hash, or 0 on a nil handle / failure. Never raises.
  ensureRuntime()
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
  ensureRuntime()
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
  ensureRuntime()
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
  ensureRuntime()
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
  ensureRuntime()
  cint(hammingDistance(a, b))

proc up_compute_file(path: cstring; outAHash, outDHash,
    outPHash: ptr uint64; outBlockhash: ptr ptr uint8;
    outBlockhashLen: ptr csize_t): cint =
  ensureRuntime()
  if path == nil or path[0] == '\0' or outAHash == nil or outDHash == nil or
      outPHash == nil or outBlockhash == nil or outBlockhashLen == nil:
    return UP_PERCEPT_ERR_FORMAT
  outBlockhash[] = nil
  outBlockhashLen[] = 0
  try:
    let hashes = computeHashes($path)
    let blockData = copyToShared(hashes.blockhash)
    outAHash[] = uint64(hashes.aHash)
    outDHash[] = uint64(hashes.dHash)
    outPHash[] = uint64(hashes.pHash)
    outBlockhash[] = blockData
    outBlockhashLen[] = csize_t(hashes.blockhash.len)
    UP_PERCEPT_OK
  except OutOfMemDefect:
    UP_PERCEPT_ERR_MEM
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_phash_file(path: cstring; outHash: ptr uint64; outWidth,
    outHeight: ptr cint): cint =
  ensureRuntime()
  if path == nil or path[0] == '\0' or outHash == nil or outWidth == nil or
      outHeight == nil:
    return UP_PERCEPT_ERR_FORMAT
  try:
    let value = phashInfo($path)
    if value.width > high(cint) or value.height > high(cint):
      return UP_PERCEPT_ERR_FORMAT
    outHash[] = uint64(value.hash)
    outWidth[] = cint(value.width)
    outHeight[] = cint(value.height)
    UP_PERCEPT_OK
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_ahash_file(path: cstring; outHash: ptr uint64): cint =
  ensureRuntime()
  if path == nil or path[0] == '\0' or outHash == nil:
    return UP_PERCEPT_ERR_FORMAT
  try:
    outHash[] = uint64(ahash($path))
    UP_PERCEPT_OK
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_dhash_file(path: cstring; outHash: ptr uint64): cint =
  ensureRuntime()
  if path == nil or path[0] == '\0' or outHash == nil:
    return UP_PERCEPT_ERR_FORMAT
  try:
    outHash[] = uint64(dhash($path))
    UP_PERCEPT_OK
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_index_new(outHandle: ptr pointer): cint =
  ## Create an empty bk-tree index. On success stores an opaque handle (free
  ## with up_index_free).
  ensureRuntime()
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
  ensureRuntime()
  if not containsHandle(indexHandles, idx): return UP_PERCEPT_ERR_FORMAT
  try:
    indexOf(idx).tree.insert(Hash(h), id)
    UP_PERCEPT_OK
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_index_len(idx: pointer): csize_t =
  ensureRuntime()
  if not containsHandle(indexHandles, idx): return 0
  try: csize_t(indexOf(idx).tree.len)
  except CatchableError, Defect: 0

proc up_index_query(idx: pointer; h: uint64; radius: cint;
    outIds: ptr ptr int32; outCount: ptr csize_t): cint =
  ## Query the index for hashes within Hamming `radius` of `h`. On success
  ## allocates *outIds as `2 * *outCount` int32s, interleaved
  ## `[id0, dist0, id1, dist1, ...]` (free with up_buffer_free); *outCount is the
  ## number of matches. A nil index or out-param returns UP_PERCEPT_ERR_FORMAT.
  ensureRuntime()
  if outIds == nil or outCount == nil: return UP_PERCEPT_ERR_FORMAT
  outIds[] = nil
  outCount[] = 0
  if not containsHandle(indexHandles, idx): return UP_PERCEPT_ERR_FORMAT
  if radius < 0 or radius > 64: return UP_PERCEPT_ERR_FORMAT
  try:
    let res = indexOf(idx).tree.query(Hash(h), int(radius))
    if res.len == 0: return UP_PERCEPT_OK
    if res.len > high(int) div (2 * sizeof(int32)):
      return UP_PERCEPT_ERR_MEM
    let buf = allocShared(res.len * 2 * sizeof(int32))
    if buf == nil: return UP_PERCEPT_ERR_MEM
    let dst = cast[ptr UncheckedArray[int32]](buf)
    for i in 0 ..< res.len:
      dst[i * 2] = res[i][0]
      dst[i * 2 + 1] = int32(res[i][1])
    outIds[] = cast[ptr int32](buf)
    outCount[] = csize_t(res.len)
    UP_PERCEPT_OK
  except CatchableError, Defect:
    UP_PERCEPT_ERR_FORMAT

proc up_index_free(idx: pointer) =
  ## Free an index handle. NULL is a no-op.
  ensureRuntime()
  if unregisterHandle(indexHandles, idx): GC_unref(indexOf(idx))

proc up_free(h: pointer) =
  ## Free a handle. NULL is a no-op.
  ensureRuntime()
  if unregisterHandle(imageHandles, h): GC_unref(imgOf(h))

proc up_buffer_free(p: pointer; len: csize_t) =
  ## Free a buffer returned by UniPercept. NULL is a no-op. `len` is ignored.
  ensureRuntime()
  if p != nil: deallocShared(p)

{.pop.}
