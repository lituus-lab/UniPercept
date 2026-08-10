# UniPercept-lituus

Perceptual image hashing and similarity search backed by the native
[UniPercept](https://github.com/lituus-lab/UniPercept) engine.

```bash
pip install UniPercept-lituus
```

The installed module is named `unipercept`:

```python
import unipercept

left = unipercept.phash("left.jpg")
right = unipercept.phash("right.jpg")

print(unipercept.to_hex(left))
print(unipercept.hamming(left, right))
print(unipercept.similarity(left, right))
```

## What it provides

- aHash, dHash and fixed-point DCT pHash as 64-bit integers;
- variable-size blockhash signatures;
- decoding from memory or files through UniImage;
- grayscale conversion and deterministic resize kernels;
- a BK-tree for Hamming-radius lookup;
- wheels containing the native UniPercept library.

```python
tree = unipercept.BkTree()
tree.insert(100, left)
tree.insert(101, right)

for image_id, distance in tree.query(left, radius=5):
    print(image_id, distance)
```

For an already decoded RGB or RGBA buffer:

```python
gray = unipercept.to_grayscale(rgb_bytes, width, height, channels=3)
small = gray.resize(32, 32)
signature = small.phash()
```

Perceptual hashes are similarity signatures, not cryptographic hashes. Use
them to select candidates and perform an application-specific confirmation
when false positives matter.

## Building from source

An sdist build requires Nim and Nimble on `PATH`, plus a supported C compiler.
From a repository checkout:

```bash
nimble pyLib
cd py
python -m pip install -e .
python -m pytest -q
```

`python setup.py build_ext --inplace` remains available as a direct extension
rebuild command.
