# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## The table of contents, and the two settings that decide the theme.
import std/tables
import nimibook
# `from ... import` and not a plain import: the theme module re-exports nimib
# for the chapters, and nimib's NbConfig has a `favicon_escaped` field too, so
# a plain import makes `book.favicon_escaped` below ambiguous.
from lituus_theme import faviconTag

var book = initBookWithToc:
  entry("UniPercept", "index.nim")
  entry("Four ways to summarize an image", "hashes.nim")
  entry("Measuring a difference", "distance.nim")
  entry("Searching more than two images", "search.nim")
  entry("Hashing image files", "files.nim")
  entry("Choosing responsibly", "choosing.nim")

book.title = "UniPercept"
book.description =
  "Perceptual image hashes: what they summarise, how they are compared, " &
  "and what a distance does and does not mean."

# The two BookConfig fields that select a theme. nimibook's inline script picks
# between them with `prefers-color-scheme`, and localStorage overrides.
book.default_theme = "lituus-light"
book.preferred_dark_theme = "lituus-dark"
book.theme_option = {"lituus-light": "Light", "lituus-dark": "Dark"}.toTable

# From the theme package, not from a path beside this checkout: CI checks out
# one repository. Without it nimibook ships nimib's default, a whale emoji.
book.favicon_escaped = faviconTag()

nimibookCli(book)
