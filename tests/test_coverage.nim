# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab

# These imports register and execute their unittest suites.
{.push warning[UnusedImport]: off.}
import test_percept
import test_gray
import test_resize
import test_hashes
import test_bktree
{.pop.}
