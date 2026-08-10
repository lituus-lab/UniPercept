# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Keep the package root available to tasks that compile C ABI entry points
## directly rather than through the Nimble package target.
switch("path", "src")
