# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import ../tools/vgraph

suite "vgraph family boundary":
  test "only decode may import UniImage":
    check mayImportUniImage("src/UniPercept/decode.nim", "UniImage")
    for module in ["gray", "resize", "hashes"]:
      check not mayImportUniImage("src/UniPercept/" & module & ".nim",
          "UniImage")
      check not mayImportUniImage("src/UniPercept/" & module & ".nim",
          "UniImage/core")
