# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# UniPercept — perceptual image hashing for the lituus-lab Uni* family.

version       = "1.0.1"
author        = "lituus-lab"
description   = "Perceptual image hashing for the lituus-lab Uni* family (Nim + C-ABI + Python)"
license       = "Apache-2.0"
srcDir        = "src"

requires "nim >= 2.0.0"
requires "https://github.com/lbartoletti/NimContracts#main"
requires "https://github.com/lituus-lab/UniImage#main"

let pythonExe = when defined(windows): "python" else: "python3"

proc pipSystemFlag(): string =
  if gorgeEx(pythonExe & " -m pip install --help").output.contains(
      "--break-system-packages"):
    " --break-system-packages"
  else:
    ""
# nimble 0.22 exits 0 even when an `exec` inside a task fails, so a task's exit
# code says nothing about whether its body ran. Each task writes a marker as
# its last statement; `tools/gate.nim` removes the marker, runs the task, and
# fails if it is not there afterwards. `nimble canary` proves the gate still
# bites -- if that one ever passes, every other green result is worthless.
const gateExe =
  when defined(windows): "build/unigate.exe" else: "build/unigate"

template done(task: string) =
  mkDir "build/.gate"
  writeFile("build/.gate/" & task & ".ok", "")

proc gate(task: string): string =
  ## `exec gate("test")` -- builds the tool on first use.
  if not fileExists(gateExe):
    exec "nim c --hints:off -o:" & gateExe & " tools/gate.nim"
  gateExe & " " & task

task canary, "Must fail: proves the gate still catches a broken build":
  # No `done` here on purpose: the exec below raises, so the marker is never
  # written and the gate reports the failure nimble swallowed.
  exec "nim c -r --hints:off --path:src -o:build/canary tests/canary_broken.nim"

task lint, "Fail if nimpretty would reformat a source":
  exec "nim c -r --hints:off -o:build/lint_tool tools/lint.nim"
  done "lint"

task checkVGraph, "Fail on an import that climbs the layers in vgraph.cfg":
  exec "nim c -r --hints:off -o:build/vgraph_tool tools/vgraph.nim"
  done "checkVGraph"

const bookDeps = [
  "https://github.com/pietroppeter/nimib#v0.4.1",
  "https://github.com/pietroppeter/nimibook#v0.4.0",
  "https://github.com/lituus-lab/lituus-theme#v0.2.0",
]
taskRequires "docsDeps", bookDeps[0], bookDeps[1], bookDeps[2]
taskRequires "book", bookDeps[0], bookDeps[1], bookDeps[2]
taskRequires "docs", bookDeps[0], bookDeps[1], bookDeps[2]

task docsDeps, "Install the docs toolchain (nimib + nimibook + theme)":
  echo "nimib, nimibook and lituus-theme installed."
  done "docsDeps"

task bookInit, "Scaffold a chapter added to the table of contents":
  withDir "book":
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim init"
  done "bookInit"

task book, "Build the multi-chapter book (needs nimib + nimibook)":
  withDir "book":
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim clean"
    # `init` before `build`, on every run: it is what creates `__site/assets`,
    # which is not tracked, so a fresh clone has none and every page ships
    # referencing a stylesheet and a script that are not there.
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim init"
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim build"
  done "book"

task docs, "API reference + book into pages/ — what CI publishes":
  rmDir "pages"
  exec gate("book")
  cpDir "book/__site", "pages"
  rmFile "pages/book.json"
  # `--path:src` so the umbrella's own imports resolve against this checkout
  # rather than falling through to whatever version is installed.
  exec "nim doc --index:on --outdir:pages/api --project --hints:off " &
       "--path:src src/UniPercept.nim"
  # ...and the reference wears the same theme. `nim doc` has no stylesheet
  # option, so the palette is appended to the one it just wrote.
  exec "nim c -r --hints:off --outdir:build tools/theme_api.nim " &
       "pages/api/nimdoc.out.css"
  done "docs"

task test, "Nim tests (debug, contracts active)":
  exec "nim c -r --path:src -o:build/test_percept tests/test_percept.nim"
  exec "nim c -r --path:src -o:build/test_version tests/test_version.nim"
  exec "nim c -r --path:src -o:build/test_gray tests/test_gray.nim"
  exec "nim c -r --path:src -o:build/test_resize tests/test_resize.nim"
  exec "nim c -r --path:src -o:build/test_hashes tests/test_hashes.nim"
  exec "nim c -r --path:src -o:build/test_bktree tests/test_bktree.nim"
  exec "nim c -r --path:src -o:build/test_vgraph tests/test_vgraph.nim"
  done "test"

task testRelease, "Nim tests (release, contracts compiled away)":
  exec "nim c -r -d:release --path:src -o:build/test_percept_rel tests/test_percept.nim"
  exec "nim c -r -d:release --path:src -o:build/test_gray_rel tests/test_gray.nim"
  exec "nim c -r -d:release --path:src -o:build/test_resize_rel tests/test_resize.nim"
  exec "nim c -r -d:release --path:src -o:build/test_hashes_rel tests/test_hashes.nim"
  exec "nim c -r -d:release --path:src -o:build/test_bktree_rel tests/test_bktree.nim"
  exec "nim c -r -d:release --path:src -o:build/test_vgraph_rel tests/test_vgraph.nim"
  done "testRelease"

task testCi, "Nim tests (CI subset, debug)":
  exec gate("test")
  done "testCi"

task testCiRelease, "Nim tests (CI subset, release)":
  exec gate("testRelease")
  done "testCiRelease"

task testAll, "debug + release + C ABI":
  exec gate("test")
  exec gate("testRelease")
  exec gate("ctest")
  done "testAll"

task example, "Nim demo":
  exec "nim c -r --path:src -o:build/demo examples/demo.nim"
  done "example"

task unipercept, "Build the unipercept CLI (hash/find)":
  exec "nim c --path:src -o:bin/unipercept bin/unipercept_cli.nim"
  done "unipercept"

# Nim takes `-o:` literally and appends no platform extension.
const
  sharedLib =
    when defined(windows): "libUniPercept.dll"
    elif defined(macosx): "libUniPercept.dylib"
    else: "libUniPercept.so"
  staticLib = "libUniPercept.a"  # MinGW `ar` on Windows, so `.a` everywhere.

  # @rpath install_name, so the copy bundled in the wheel is found at import.
  macArgs =
    when defined(macosx): " --passL:\"-Wl,-install_name,@rpath/" & sharedLib & "\""
    else: ""

task clib, "C shared library":
  exec "nim c --app:lib --noMain --mm:arc -d:release -o:" & sharedLib & macArgs &
       " src/UniPercept/c_api.nim"
  done "clib"

task clibStatic, "C static library":
  exec "nim c --app:staticlib -d:staticNoAutoInit --noMain --mm:arc -d:release -o:" & staticLib &
       " src/UniPercept/c_api.nim"
  done "clibStatic"

task clibMsvc, "C static library, MSVC ABI (Windows Python extension)":
  # CPython on Windows is MSVC-built and cannot link MinGW output.
  exec "nim c --cc:vcc --app:staticlib -d:staticNoAutoInit --noMain --mm:arc -d:release" &
       " -o:UniPercept.lib src/UniPercept/c_api.nim"
  done "clibMsvc"

# Nim's MinGW toolchain names it mingw32-make.
let makeExe = if findExe("mingw32-make").len > 0: "mingw32-make" else: "make"

# `make -C`, not `cd dir && make`: nimble's exec runs no shell on Windows.
task ctest, "C ABI tests":
  exec gate("clibStatic")
  exec makeExe & " -C tests/c"
  done "ctest"

task cexample, "C demo":
  exec gate("clibStatic")
  exec makeExe & " -C examples/c"
  done "cexample"

task pyDeps, "Install Python build deps (setuptools, Cython, pytest) if missing":
  exec pythonExe & " -m pip install" & pipSystemFlag() &
       " --quiet setuptools wheel \"Cython>=3.0.0\" pytest"
  # Ubuntu ships a setuptools that predates PEP 639 and cannot parse the SPDX
  # licence pyproject.toml declares. pip refuses to uninstall a distro- or
  # brew-managed package, so install over it rather than --upgrade it.
  exec pythonExe & " -m pip install" & pipSystemFlag() &
       " --quiet --ignore-installed \"setuptools>=77\""
  done "pyDeps"

# The extension links the vcc static lib on Windows, the shared lib elsewhere.
task pyLib, "Build the library the Python extension links against":
  when defined(windows):
    exec gate("clibMsvc")
  else:
    exec gate("clib")
  done "pyLib"

task pyNotebookDeps, "Install notebook build deps (nbformat, nbclient, ipykernel) if missing":
  exec pythonExe & " -m pip install" & pipSystemFlag() &
       " --quiet nbformat nbclient ipykernel"
  done "pyNotebookDeps"

task buildCython, "Cython extension in-place":
  exec gate("pyLib")
  exec gate("pyDeps")
  # nimscript `cd` (lib/system/nimscript.nim) changes the VM cwd for the next
  # exec without a shell, so the task works under nimble's no-shell exec on Windows.
  cd "py"
  exec pythonExe & " setup.py build_ext --inplace"
  cd ".."
  done "buildCython"

task pyTest, "Cython extension + pytest":
  exec gate("buildCython")
  cd "py"
  exec pythonExe & " -m pytest -q"
  cd ".."
  done "pyTest"

task pyWheel, "wheel":
  exec gate("pyLib")
  exec gate("pyDeps")
  cd "py"
  exec pythonExe & " setup.py bdist_wheel"
  cd ".."
  done "pyWheel"

task pySdist, "Python source distribution with vendored Nim source":
  exec gate("pyDeps")
  cd "py"
  exec pythonExe & " setup.py sdist"
  cd ".."
  done "pySdist"

task coverage, "LCOV + HTML coverage report for the Nim sources (needs lcov)":
  # gcov and lcov driven directly, no coco. Linux and macOS only.
  # --debugger:native attributes lines to the .nim sources, not the generated C.
  # --include keeps stdlib out. Nim 2.2 can still emit empty imported modules
  # and a synthetic counter one line past EOF; ignore only those mapping cases.
  let cache = "build/covcache"
  rmDir cache
  rmDir "coverage"
  rmFile "lcov.info"
  # One executable keeps every generated module and counter in one graph.
  # Merging separately compiled Nim modules is ambiguous because their module
  # initializers can receive different source lines in each executable.
  exec "nim c --path:src --nimcache:" & cache &
       " --debugger:native --passC:--coverage --passL:--coverage" &
       " -o:build/test_coverage tests/test_coverage.nim"
  exec "./build/test_coverage"
  exec "lcov --capture --directory " & cache & " --base-directory ." &
       " --include \"*/src/UniPercept/*\" --output-file lcov.info --quiet --ignore-errors mismatch" &
       " --ignore-errors gcov,gcov"
  # gcov can attribute a final generated expression to EOF + 1; `range` is
  # genhtml's documented filter for precisely that compiler artifact, and
  # lcov 2.x wants the matching category allowance before it applies it.
  exec "genhtml lcov.info --filter range --ignore-errors range" &
       " --output-directory coverage --legend --quiet"
  exec "lcov --summary lcov.info"
  done "coverage"
