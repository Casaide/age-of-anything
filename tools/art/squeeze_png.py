# Recompresses PNGs in place (the game's own PNG writer, model/build_mats.lobster bmat_png, stores the pixels
# uncompressed: a building look's sheets are ~7x smaller deflated). Pixels unchanged; only IDAT is rewritten.
#   python3 tools/art/squeeze_png.py <folder> [...]
import os, sys, zlib, struct
from concurrent.futures import ProcessPoolExecutor

def chunks(data):
    i = 8
    while i < len(data):
        n, = struct.unpack('>I', data[i:i + 4])
        yield data[i + 4:i + 8], data[i + 8:i + 8 + n]
        i += 12 + n

def chunk(kind, body):
    return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)

def squeeze(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    parts = list(chunks(data))
    raw = zlib.decompress(b''.join(body for kind, body in parts if kind == b'IDAT'))
    out = [data[:8]]
    done = False
    for kind, body in parts:
        if kind == b'IDAT':
            if not done: out.append(chunk(b'IDAT', zlib.compress(raw, 9)))
            done = True
        else: out.append(chunk(kind, body))
    small = b''.join(out)
    if len(small) < len(data):
        open(path, 'wb').write(small)
    return len(data), min(len(small), len(data))

if __name__ == '__main__':
    files = [os.path.join(d, f) for top in sys.argv[1:] for d, _, fs in os.walk(top) for f in fs if f.endswith('.png')]
    with ProcessPoolExecutor(4) as pool: sizes = list(pool.map(squeeze, files, chunksize=16))
    before = sum(b for b, _ in sizes)
    after = sum(a for _, a in sizes)
    print(f'{len(files)} PNGs: {before / 1e6:.0f} MB -> {after / 1e6:.0f} MB')
