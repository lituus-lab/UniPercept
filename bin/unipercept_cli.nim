# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## unipercept — perceptual image hashing CLI.
##
##   unipercept hash <file> [--algo ah|dh|ph|block]
##       hex hash(es) of one image (default: all four)
##   unipercept find <dir> [--algo ph] [--threshold N]
##       walk <dir>, hash every image, list pairs with Hamming distance <= N
##       (default 5). Single-threaded.
import std/[os, strutils, strformat, algorithm]
import UniPercept

const ImageExts = [".png", ".jpg", ".jpeg", ".bmp", ".qoi", ".pnm", ".ppm",
    ".pgm", ".pam", ".pcx", ".gif", ".tga", ".targa"]

proc die(msg: string) =
  stderr.writeLine "error: " & msg
  quit(1)

proc needFile(path: string) =
  if not fileExists(path): die("file not found: " & path)

proc needDir(path: string) =
  if not dirExists(path): die("directory not found: " & path)

proc usage() =
  stderr.writeLine """usage:
  unipercept hash <file> [--algo ah|dh|ph|block]
  unipercept find <dir>  [--algo ph] [--threshold N]"""
  quit(1)

proc hashOf(path: string; algo: string): Hash =
  ## Single-Hash algorithms only (block is a seq, not a Hash).
  case algo
  of "ah": result = ahash(path)
  of "dh": result = dhash(path)
  of "ph": result = phash(path)
  else: die("unknown algo: " & algo & " (want ah, dh, or ph)")

proc cmdHash(args: seq[string]) =
  if args.len < 1: usage()
  let file = args[0]
  needFile(file)
  var algo = "all"
  var i = 1
  while i < args.len:
    let a = args[i]
    if a.startsWith("--algo="):
      algo = a[7 ..< a.len]
    elif a == "--algo":
      if i + 1 >= args.len: die("--algo needs a value")
      algo = args[i + 1]
      i += 1
    else:
      die("unknown argument: " & a)
    i += 1
  try:
    if algo == "all":
      let h = computeHashes(file)
      echo "aHash  ", toHex(h.aHash)
      echo "dHash  ", toHex(h.dHash)
      echo "pHash  ", toHex(h.pHash)
      echo "block  ", toHex(h.blockhash)
    elif algo == "block":
      echo toHex(computeHashes(file).blockhash)
    else:
      echo toHex(hashOf(file, algo))
  except UniImageException as e:
    die(e.msg)
  except IOError as e:
    die(e.msg)

proc cmdFind(args: seq[string]) =
  if args.len < 1: usage()
  let root = args[0]
  needDir(root)
  var algo = "ph"
  var threshold = 5
  var i = 1
  while i < args.len:
    let a = args[i]
    if a.startsWith("--algo="):
      algo = a[7 ..< a.len]
    elif a == "--algo":
      if i + 1 >= args.len: die("--algo needs a value")
      algo = args[i + 1]
      i += 1
    elif a.startsWith("--threshold="):
      try: threshold = parseInt(a[12 ..< a.len])
      except ValueError: die("threshold must be an integer: " & a)
    elif a == "--threshold":
      if i + 1 >= args.len: die("--threshold needs a value")
      try: threshold = parseInt(args[i + 1])
      except ValueError: die("threshold must be an integer: " & args[i + 1])
      i += 1
    else:
      die("unknown argument: " & a)
    i += 1
  if algo notin ["ah", "dh", "ph"]:
    die("find needs algo ah, dh, or ph; got: " & algo)
  if threshold < 0 or threshold > 64:
    die("threshold must be between 0 and 64")
  # Hash every image under root; skip non-images and undecodable files.
  var seen: seq[(string, Hash)]
  for path in walkDirRec(root):
    if path.splitFile().ext.toLowerAscii() notin ImageExts: continue
    try: seen.add((path, hashOf(path, algo)))
    except UniImageException, IOError: discard
  seen.sort(proc(a, b: (string, Hash)): int = cmp(a[0], b[0]))
  # Index the hashes in a bk-tree and query each within `threshold`; emit
  # every near-duplicate pair once (id > i), ordered by path.
  var tree = initBkTree()
  for i in 0 ..< seen.len: tree.insert(seen[i][1], int32(i))
  var pairs: seq[(string, string, int, float)]
  for i in 0 ..< seen.len:
    for (id, d) in tree.query(seen[i][1], threshold):
      if int(id) > i:
        pairs.add((seen[i][0], seen[int(id)][0], d,
            similarity(seen[i][1], seen[int(id)][1])))
  pairs.sort(proc(a, b: (string, string, int, float)): int =
    if a[0] != b[0]: cmp(a[0], b[0]) else: cmp(a[1], b[1]))
  for (pa, pb, d, s) in pairs:
    echo &"{pa}\t{pb}\t{d}\t{s}"

proc main() =
  let args = commandLineParams()
  if args.len < 1: usage()
  let cmd = args[0]
  let rest = if args.len > 1: args[1 ..< args.len] else: @[]
  case cmd
  of "hash": cmdHash(rest)
  of "find": cmdFind(rest)
  else: usage()

when isMainModule: main()
