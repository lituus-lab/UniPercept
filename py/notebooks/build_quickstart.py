# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Author py/notebooks/quickstart.ipynb, then execute it so the committed file
carries real outputs for GitHub to render. Run from the repo root:

    python3 py/notebooks/build_quickstart.py

CI re-executes the notebook against an installed wheel; this script only
regenerates it after an API change."""
import os

import nbformat as nbf
from nbclient import NotebookClient

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "quickstart.ipynb")

CELLS = [
    ("md", """# UniPercept — Python quickstart

`unipercept` is a Cython extension over the UniPercept C ABI, shipped as a
self-contained wheel: the native library travels inside the package, so
installing it needs neither Nim nor a compiler.

```
pip install unipercept
```

CI executes this notebook against the wheel the release actually publishes, so
an output below that stops matching fails the build."""),
    ("md", "## The API\n\n"
           "`decode` returns an `Image`; `ahash`/`dhash`/`phash` return 64-bit "
           "integers, `blockhash(bits)` returns bytes, and `hamming(a, b)` is "
           "the popcount-of-XOR distance between two hashes."),
    ("code", "import unipercept\n\n"
             "unipercept.version(), unipercept.__version__, unipercept.abi_version()"),
    ("md", "## Decode and hash a small image\n\n"
           "A 2x2 RGB PPM (uncompressed, so the example needs no encoder):"),
    ("code", "PPM = b\"P6\\n2 2\\n255\\n\" + bytes([0xFF,0,0, 0,0xFF,0, 0,0,0xFF, 0xFF,0xFF,0xFF])\n"
             "img = unipercept.decode(PPM)\n"
             "img.width, img.height, img.channels"),
    ("code", "a, d, p = img.ahash(), img.dhash(), img.phash()\n"
             "a, d, p"),
    ("code", "unipercept.hamming(a, a), unipercept.hamming(a, d)"),
    ("code", "bh = img.blockhash(16)\n"
             "len(bh), bh[:8].hex()"),
]


def main():
    nb = nbf.v4.new_notebook()
    nb.cells = [
        nbf.v4.new_markdown_cell(src) if kind == "md" else nbf.v4.new_code_cell(src)
        for kind, src in CELLS
    ]
    nb.metadata["kernelspec"] = {
        "display_name": "Python 3",
        "language": "python",
        "name": "python3",
    }
    NotebookClient(nb, timeout=120, kernel_name="python3",
                   resources={"metadata": {"path": HERE}}).execute()
    for cell in nb.cells:
        if cell.cell_type == "code":
            cell.metadata.pop("execution", None)
    with open(OUT, "w", encoding="utf-8") as f:
        nbf.write(nb, f)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
