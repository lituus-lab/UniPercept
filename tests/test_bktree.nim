# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[unittest, algorithm]
import UniPercept/bktree

# Most comparisons focus on membership and sort by (distance, id).
proc norm(s: seq[(int32, int)]): seq[(int32, int)] =
  s.sortedByIt((it[1], it[0]))

suite "bk-tree":
  test "empty tree yields no matches":
    let t = initBkTree()
    check t.isEmpty
    check t.query(0'u64, 0).len == 0
    check t.query(0'u64, 64).len == 0

  test "exact and radius queries":
    var t = initBkTree()
    t.insert(0'u64, 10)
    t.insert(1'u64, 11) # dist 1 from 0
    t.insert(3'u64, 12) # dist 2 from 0, dist 1 from 1
    t.insert(0xFFFFFFFFFFFFFFFF'u64, 13) # dist 64 from 0
    check t.query(0'u64, 0).norm == @[(int32(10), 0)]
    check t.query(0'u64, 1).norm ==
      @[(int32(10), 0), (int32(11), 1)]
    check t.query(0'u64, 2).norm ==
      @[(int32(10), 0), (int32(11), 1), (int32(12), 2)]
    check t.query(1'u64, 1).norm ==
      @[(int32(11), 0), (int32(10), 1), (int32(12), 1)]
    let all = t.query(0'u64, 64).norm
    check all == @[(int32(10), 0), (int32(11), 1), (int32(12), 2),
        (int32(13), 64)]

  test "duplicate hashes stack ids on one node":
    var t = initBkTree()
    t.insert(7'u64, 1)
    t.insert(7'u64, 2)
    t.insert(7'u64, 3)
    check t.len == 1 # one distinct hash -> one node
    check t.query(7'u64, 0).norm ==
      @[(int32(1), 0), (int32(2), 0), (int32(3), 0)]

  test "negative radius yields no matches":
    var t = initBkTree()
    t.insert(0'u64, 0)
    check t.query(0'u64, -1).len == 0

  test "len counts distinct hashes, not inserts":
    var t = initBkTree()
    for h in [0'u64, 0'u64, 5'u64, 5'u64, 9'u64]: t.insert(h, 0)
    check t.len == 3

  test "query visits sibling edges in ascending distance order":
    var t = initBkTree()
    t.insert(0'u64, 10)
    t.insert(1'u64, 11)
    t.insert(3'u64, 12)
    t.insert(7'u64, 13)
    check t.query(0'u64, 64) == @[(int32(10), 0), (int32(11), 1),
        (int32(12), 2), (int32(13), 3)]
