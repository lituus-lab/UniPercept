# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import ../tools/vgraph

# The rule itself now lives in vgraph.cfg under [confined]; the tool is the
# same file in every Uni* repo. This checks the mechanism against the rule
# this repo declares.
const Confined = @[("UniImage", "src/UniPercept/decode.nim")]

suite "vgraph family boundary":
  test "only decode may import UniImage":
    check mayImport("src/UniPercept/decode.nim", "UniImage", Confined)
    for module in ["gray", "resize", "hashes"]:
      check not mayImport("src/UniPercept/" & module & ".nim", "UniImage",
          Confined)
      check not mayImport("src/UniPercept/" & module & ".nim", "UniImage/core",
          Confined)

  test "an unconfined package is unaffected":
    check mayImport("src/UniPercept/gray.nim", "UniColor", Confined)

  test "a Windows path is the same path":
    # walkDirRec yields backslashes there; the rule is written with forward
    # slashes. Comparing them raw accused decode.nim of its own import.
    check mayImport("src\\UniPercept\\decode.nim", "UniImage", Confined)
    check not mayImport("src\\UniPercept\\gray.nim", "UniImage", Confined)
