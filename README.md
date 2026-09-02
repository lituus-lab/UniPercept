# UniPercept

UniPercept finds images that look alike even when their files are not
byte-for-byte identical. It provides four deterministic perceptual hashes,
Hamming-distance comparison, and a BK-tree for similarity search.

The engine is written in Nim. The same functionality is available through a
public C ABI and the `unipercept` Python module. Image decoding is delegated to
[UniImage](https://github.com/lituus-lab/UniImage); UniPercept contains no
duplicate codec implementation.

## Algorithms

| Algorithm | Output | Useful for |
|---|---:|---|
| aHash | 64 bits | Fast coarse comparison of overall brightness structure |
| dHash | 64 bits | Horizontal edges and gradients |
| pHash | 64 bits | Comparisons that should tolerate moderate resizing or recompression |
| blockhash | Variable | A larger spatial signature; 256 bits by default |

These are perceptual signatures, not cryptographic hashes. Different images
can collide, so applications should treat distance as a candidate filter and
confirm important matches by another method.

## Nim quick start

```nim
import UniPercept

let first = phash("first.jpg")
let second = phash("second.jpg")

echo hammingDistance(first, second)
echo similarity(first, second) # 0.0 .. 1.0
```

Compute every supported signature after a single decode:

```nim
let hashes = computeHashes("photo.png")
echo toHex(hashes.aHash)
echo toHex(hashes.dHash)
echo toHex(hashes.pHash)
echo toHex(hashes.blockhash)
```

The low-level kernels also accept a `GrayscaleImage`, which is useful for
synthetic images or pixel data already decoded by an application.

## Similarity index

`BkTree` indexes 64-bit hashes under Hamming distance:

```nim
var index = initBkTree()
index.insert(phash("a.jpg"), 10)
index.insert(phash("b.jpg"), 11)

for (id, distance) in index.query(phash("query.jpg"), radius = 5):
  echo id, " ", distance
```

The radius is measured in differing bits. A radius of zero finds exact hash
matches; larger radii progressively admit less similar signatures.

## Python

The PyPI distribution is named `UniPercept-lituus`; the import remains
`unipercept`:

```bash
pip install lituus-unipercept
```

```python
import unipercept

a = unipercept.phash("first.jpg")
b = unipercept.phash("second.jpg")
print(unipercept.hamming(a, b))
print(unipercept.similarity(a, b))
```

Wheels bundle the native library. Building from the source distribution needs
Nim, Nimble, and a supported C compiler.

## C

The public header is [`include/UniPercept.h`](include/UniPercept.h). Call
`up_init()` before using the ABI; repeated calls are no-ops, but the first call
must be externally synchronized. `examples/c/demo.c` shows decode, hashing and
buffer ownership.

## Build and validation

```bash
nimble install -y
nimble testAll
nimble pyTest
nimble example
nimble cexample
nimble docs
```

The fixed-point grayscale, resize and DCT paths preserve the historical hash
values across supported CPUs. Floating-point image resizing is deliberately
not substituted into that pipeline because it would change stored hashes.

## License

Apache-2.0. See `LICENSE` and `NOTICE`.
