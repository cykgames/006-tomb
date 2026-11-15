"""Procedural voxel-style app icon generator (stdlib PNG writer).

Writes icon.png (192x192) used as project icon + Android launcher icon.
Run: python tools/gen_icon.py
"""
import os
import struct
import zlib

ROOT = os.path.join(os.path.dirname(__file__), "..")
W = H = 192


def write_png(path, w, h, rows):
    raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in rows)

    def chunk(typ, data):
        return (struct.pack(">I", len(data)) + typ + data
                + struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF))

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n"
                + chunk(b"IHDR", ihdr)
                + chunk(b"IDAT", zlib.compress(raw, 9))
                + chunk(b"IEND", b""))
    print("wrote", path)


def main():
    sky = (96, 156, 240)
    sky2 = (140, 190, 250)
    grass = (92, 184, 60)
    dirt = (122, 82, 44)
    skin = (224, 172, 120)
    hair = (70, 48, 30)
    eye = (40, 40, 60)
    shirt = (60, 120, 210)
    rows = []
    for y in range(H):
        row = []
        for x in range(W):
            c = sky if y < 96 else sky2
            # grass block bottom strip
            if y >= 150:
                c = grass if y < 162 else dirt
            row.append(c)
        rows.append(row)

    def rect(x0, y0, x1, y1, c):
        for y in range(max(0, y0), min(H, y1)):
            for x in range(max(0, x0), min(W, x1)):
                rows[y][x] = c

    # character body (shirt) + head, voxel proportions
    rect(66, 118, 126, 152, shirt)      # torso
    rect(56, 120, 66, 146, skin)        # left arm
    rect(126, 120, 136, 146, skin)      # right arm
    rect(58, 44, 134, 120, skin)        # head
    rect(58, 44, 134, 62, hair)         # hair top
    rect(58, 62, 66, 78, hair)          # hair side
    rect(126, 62, 134, 78, hair)
    rect(74, 78, 90, 92, eye)           # left eye
    rect(102, 78, 118, 92, eye)         # right eye
    rect(86, 100, 106, 108, (160, 100, 70))  # mouth
    write_png(os.path.join(ROOT, "icon.png"), W, H, rows)


if __name__ == "__main__":
    main()
