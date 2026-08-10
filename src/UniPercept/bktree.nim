# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Burkhard-Keller tree for Hamming-radius lookup over perceptual hashes.
##
## A bk-tree indexes a discrete metric space so all points within a radius r of
## a query are found without scanning every point: at each node the search
## descends only through edge distances between `d - r` and `d + r`, where d is
## the node's distance to the query. The metric here is Hamming distance on
## 64-bit `Hash`es (range 0..64), so edge keys are small and the tree is
## shallow. Pure: imports only `hashes` (Hash + hammingDistance) and the stdlib.
## Exposed to C by the `up_index_*` ABI and used by the `find` CLI command.
import UniPercept/hashes
import std/algorithm
import contracts

type
  BkNode = object
    hash: Hash
    ids: seq[int32]        # every id inserted at this exact hash (duplicates stack)
    edges: seq[(int, int)] # (distance, child index), kept sorted by distance
  BkTree* = object
    nodes: seq[BkNode] # nodes[0] is the root when non-empty

proc len*(t: BkTree): int {.contractual.} =
  ## Number of nodes (distinct hashes) in the tree.
  ensure:
    result >= 0
  body:
    result = t.nodes.len

proc isEmpty*(t: BkTree): bool {.contractual.} =
  ensure:
    result == (t.len == 0)
  body:
    result = t.nodes.len == 0

proc initBkTree*(): BkTree {.contractual.} =
  ## An empty tree.
  ensure:
    result.len == 0
  body:
    result = BkTree(nodes: @[])

proc insert*(t: var BkTree; h: Hash; id: int32) {.contractual.} =
  ## Insert `id` at hash `h`. A hash already present stacks its id on the
  ## existing node instead of adding a new one, so duplicates stay queryable.
  ensure:
    t.len >= 1
  body:
    if t.nodes.len == 0:
      t.nodes.add BkNode(hash: h, ids: @[id])
      return
    var idx = 0
    while true:
      let d = hammingDistance(t.nodes[idx].hash, h)
      if d == 0:
        t.nodes[idx].ids.add id
        return
      var child = -1
      for edge in t.nodes[idx].edges:
        if edge[0] == d: child = edge[1]; break
      if child >= 0:
        idx = child
      else:
        let newIdx = t.nodes.len
        t.nodes.add BkNode(hash: h, ids: @[id])
        t.nodes[idx].edges.add (d, newIdx)
        t.nodes[idx].edges.sort(proc(a, b: (int, int)): int = cmp(a[0], b[0]))
        return

proc query*(t: BkTree; h: Hash;
    radius: int): seq[(int32, int)] {.contractual.} =
  ## Every `(id, distance)` pair whose Hamming distance to `h` is `<= radius`,
  ## in tree-traversal order. A negative `radius` or an empty tree yields no
  ## matches; the distance is the actual Hamming distance (0 for an exact match).
  ensure:
    radius >= 0 or result.len == 0
  body:
    if t.nodes.len == 0 or radius < 0: return
    var stack = @[0]
    while stack.len > 0:
      let idx = stack.pop()
      let d = hammingDistance(t.nodes[idx].hash, h)
      if d <= radius:
        for id in t.nodes[idx].ids: result.add (id, d)
      for edge in t.nodes[idx].edges.reversed:
        if edge[0] >= d - radius and edge[0] <= d + radius:
          stack.add edge[1]
