#!/usr/bin/env python3
"""Pure-python PNG crop-diff (no PIL/ImageMagick on the QA hosts).

Usage: imgcrop_diff.py X0 Y0 X1 Y1 base.png frame1.png [frame2.png ...]
Coords are PIXELS of the source PNG (simctl @3x: multiply device points by 3).
Prints per-frame mean-absolute-difference (MAD, 0-255) and %pixels changed>20.
"""
import sys, zlib, struct

def read_png(path):
    d = open(path, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n', path
    pos = 8; idat = b''; w = h = bd = ct = None
    while pos < len(d):
        ln, typ = struct.unpack('>I4s', d[pos:pos+8]); pos += 8
        data = d[pos:pos+ln]; pos += ln + 4
        if typ == b'IHDR':
            w, h, bd, ct = struct.unpack('>IIBB', data[:10])
        elif typ == b'IDAT':
            idat += data
        elif typ == b'IEND':
            break
    assert bd == 8, 'only 8-bit'
    nch = {0:1, 2:3, 3:1, 4:2, 6:4}[ct]
    raw = zlib.decompress(idat)
    stride = w * nch
    out = bytearray(h * stride); prev = bytearray(stride); p = 0
    for y in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p+stride]); p += stride
        if f == 1:
            for i in range(nch, stride): line[i] = (line[i] + line[i-nch]) & 255
        elif f == 2:
            for i in range(stride): line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i-nch] if i >= nch else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i-nch] if i >= nch else 0
                b = prev[i]; c = prev[i-nch] if i >= nch else 0
                pp = a + b - c
                pa, pb, pc = abs(pp-a), abs(pp-b), abs(pp-c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out[y*stride:(y+1)*stride] = line; prev = line
    return w, h, nch, out

def gray_crop(path, box):
    w, h, nch, buf = read_png(path)
    x0, y0, x1, y1 = box
    x1 = min(x1, w); y1 = min(y1, h)
    px = []
    for y in range(y0, y1):
        row = y * w * nch
        for x in range(x0, x1):
            i = row + x * nch
            if nch >= 3:
                px.append((buf[i]*299 + buf[i+1]*587 + buf[i+2]*114)//1000)
            else:
                px.append(buf[i])
    return px

if __name__ == '__main__':
    box = tuple(int(v) for v in sys.argv[1:5])
    base = gray_crop(sys.argv[5], box)
    for f in sys.argv[6:]:
        cur = gray_crop(f, box)
        n = min(len(base), len(cur))
        diffs = [abs(base[i]-cur[i]) for i in range(n)]
        mad = sum(diffs)/n
        chg = sum(1 for d in diffs if d > 20)/n*100
        print(f"{f.split('/')[-1]}\tMAD {mad:6.3f}\tchanged {chg:5.1f}%")
