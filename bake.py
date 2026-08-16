#!/usr/bin/env python3
"""
bake.py - pre-compute Cobra Mk III orientations for the Agon VDP.

Produces a .VDU file per grid.  Each orientation becomes a ready-made
sequence of VDU commands - screen clear plus MOVE/DRAW for every visible
edge - which the player program drops straight into a VDP buffer.  From
then on a frame costs six bytes: VDU 23,0,&A0,id;1

File layout, repeated once per orientation:

    "<payload length in decimal>" CR
    <payload, in chunks of at most 200 bytes, each chunk followed by CR>

The decimal length line and the CR chunk terminators exist so the player
can read the file with INPUT#, which returns raw bytes up to a CR and so
moves 200 bytes per BASIC statement instead of one.  That requires byte
13 never to occur inside a payload, which is why every coordinate whose
low byte would be 13 is nudged by one pixel - invisible on screen.

Run this only when the geometry changes.  The .VDU files are the
deliverable; the player programs never regenerate them.
"""

import math
import os

# ----------------------------------------------------------------- geometry
# Cobra Mk III, 28 vertices / 38 edges / 13 faces.
# Four vertices sit on the centreline, the other 24 form 12 mirror pairs;
# a pair shares every term that does not involve x, so it costs 8
# multiplications instead of 16.

CENTRE = [(2, 26, 24), (9, 26, -40), (20, 0, 76), (21, 0, 90)]

PAIRS = [(0, 1, 32, 0, 76), (4, 3, 120, -3, -8), (6, 5, 88, 16, -40),
         (7, 8, 128, -8, -40), (11, 10, 32, -24, -40), (14, 13, 8, 12, -40),
         (15, 12, 36, 8, -40), (16, 19, 36, -12, -40), (17, 18, 8, -16, -40),
         (25, 23, 80, 6, -40), (26, 24, 88, 0, -40), (27, 22, 80, -6, -40)]

EDGES = [(0, 1, 0, 11), (0, 4, 4, 12), (1, 3, 3, 10), (3, 8, 7, 10),
         (4, 7, 8, 12), (6, 7, 8, 9), (6, 9, 6, 9), (5, 9, 5, 9),
         (5, 8, 7, 9), (2, 5, 1, 5), (2, 6, 2, 6), (3, 5, 3, 7),
         (4, 6, 4, 8), (1, 2, 0, 1), (0, 2, 0, 2), (8, 10, 9, 10),
         (10, 11, 9, 11), (7, 11, 9, 12), (1, 10, 10, 11), (0, 11, 11, 12),
         (1, 5, 1, 3), (0, 6, 2, 4), (20, 21, 0, 11), (12, 13, 9, 9),
         (18, 19, 9, 9), (14, 15, 9, 9), (16, 17, 9, 9), (15, 16, 9, 9),
         (14, 17, 9, 9), (13, 18, 9, 9), (12, 19, 9, 9), (2, 9, 5, 6),
         (22, 24, 9, 9), (23, 24, 9, 9), (22, 23, 9, 9), (25, 26, 9, 9),
         (26, 27, 9, 9), (25, 27, 9, 9)]

NORMALS = [(0, 62, 31), (-18, 55, 16), (18, 55, 16), (-16, 52, 14),
           (16, 52, 14), (-14, 47, 0), (14, 47, 0), (-61, 102, 0),
           (61, 102, 0), (0, 0, -80), (-7, -42, 9), (0, -30, 6), (7, -42, 9)]

# --------------------------------------------------------------- arithmetic
# Identical to what the BASIC does: 8 fractional bits, 64-entry sine table,
# and DIV that truncates towards zero.

SIN = [int(256 * math.sin(i * math.pi / 32) + 0.5) for i in range(64)]

DIVISOR = 300          # scale divisor; larger means a smaller ship
CENTRE_X, CENTRE_Y = 0xA0, 0x78


def idiv(a, b):
    q = abs(a) // abs(b)
    return q if (a < 0) == (b < 0) else -q


def matrix(yaw, pitch):
    sy, cy = SIN[yaw & 63], SIN[(yaw + 16) & 63]
    sp, cp = SIN[pitch & 63], SIN[(pitch + 16) & 63]
    return (cy, sy,                                   # m0, m2
            idiv(sp * sy, 256), cp, idiv(-sp * cy, 256),   # m3, m4, m5
            idiv(-cp * sy, 256), sp, idiv(cp * cy, 256))   # m6, m7, m8


def project(yaw, pitch):
    """Screen coordinates of all 28 vertices, plus the visible-face mask."""
    m0, m2, m3, m4, m5, m6, m7, m8 = matrix(yaw, pitch)
    sx = [0] * 28
    sy = [0] * 28
    for j, y, z in CENTRE:
        e = z * m2
        f = y * m4 + z * m5
        sx[j] = CENTRE_X + idiv(e, DIVISOR)
        sy[j] = CENTRE_Y - idiv(f, DIVISOR)
    for jp, jn, x, y, z in PAIRS:
        a = x * m0
        b = x * m3
        e = z * m2
        f = y * m4 + z * m5
        sx[jp] = CENTRE_X + idiv(e + a, DIVISOR)
        sy[jp] = CENTRE_Y - idiv(f + b, DIVISOR)
        sx[jn] = CENTRE_X + idiv(e - a, DIVISOR)
        sy[jn] = CENTRE_Y - idiv(f - b, DIVISOR)
    mask = 0
    for i, (nx, ny, nz) in enumerate(NORMALS):
        if nx * m6 + ny * m7 + nz * m8 < 0:
            mask |= 1 << i
    return sx, sy, mask


def safe(v, limit):
    """Keep the low byte away from 13 so INPUT# can be used to read the file."""
    if (v & 255) == 13:
        v += 1 if v < limit else -1
    return max(0, min(limit, v))


def word(v):
    return bytes((v & 255, (v >> 8) & 255))


def payload(sx, sy, mask, box):
    """The VDU command sequence for one orientation."""
    bx0, by0, bx1, by1 = box
    out = bytearray()
    out += bytes((18, 0, 0))                                    # GCOL 0,0
    out += bytes((25, 4)) + word(bx0) + word(by0)               # MOVE
    out += bytes((25, 101)) + word(bx1) + word(by1)             # PLOT 101
    out += bytes((18, 0, 1))                                    # GCOL 0,1
    for a, b, f1, f2 in EDGES:
        if not (mask & ((1 << f1) | (1 << f2))):
            continue
        out += bytes((25, 4)) + word(sx[a]) + word(sy[a])
        out += bytes((25, 5)) + word(sx[b]) + word(sy[b])
    assert 13 not in out, "byte 13 in payload - the INPUT# trick would break"
    return bytes(out)


def bake(yaws, pitches, path, chunk=200):
    """Write the .VDU file for a yaws x pitches grid."""
    ystep = 64 // yaws
    pstep = 64 // pitches if pitches > 1 else 0

    frames = []
    bx0 = by0 = 10 ** 6
    bx1 = by1 = -10 ** 6
    for p in range(pitches):
        for a in range(yaws):
            sx, sy, mask = project(a * ystep, PITCH_BASE if pitches == 1 else p * pstep)
            sx = [safe(v, 319) for v in sx]
            sy = [safe(v, 239) for v in sy]
            frames.append((sx, sy, mask))
            bx0 = min(bx0, min(sx)); bx1 = max(bx1, max(sx))
            by0 = min(by0, min(sy)); by1 = max(by1, max(sy))

    box = (safe(max(0, bx0 - 2), 319), safe(max(0, by0 - 2), 239),
           safe(min(319, bx1 + 2), 319), safe(min(239, by1 + 2), 239))

    total_payload = 0
    visible = []
    with open(path, "wb") as f:
        for sx, sy, mask in frames:
            data = payload(sx, sy, mask, box)
            total_payload += len(data)
            visible.append((len(data) - 18) // 12)
            f.write(str(len(data)).encode() + b"\r")
            for i in range(0, len(data), chunk):
                f.write(data[i:i + chunk] + b"\r")
    size = os.path.getsize(path)
    return dict(positions=len(frames), payload=total_payload, file=size,
                box=box, avg_edges=sum(visible) / len(visible),
                chunks_per_frame=(total_payload / len(frames) + chunk - 1) // chunk)


PITCH_BASE = 6      # fixed tilt used by the single-axis grid


GRIDS = [(64, 1), (32, 16), (32, 32), (64, 32), (64, 64)]

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    print(f"{'grid':>9} {'positions':>10} {'avg edges':>10} {'payload':>10} {'file':>10}")
    for y, p in GRIDS:
        name = f"COBRA_{y}x{p}.VDU"
        info = bake(y, p, os.path.join(here, name))
        print(f"{y:>4}x{p:<4} {info['positions']:>10} {info['avg_edges']:>10.1f} "
              f"{info['payload']:>10} {info['file']:>10}   {name}")
    print("\nclear box (identical for all single-axis grids):", info["box"])
