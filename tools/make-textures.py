"""Draws the kit's textures (CF-39) as 32-bit TGA files into media/textures/.

Plain Python, no image library. White or gold shapes on transparency, anti-aliased by 4x4 supersampling;
white ones are tinted in game with SetVertexColor. Run from the repo root:
    python tools/make-textures.py
"""
import math
import os
import struct

OUT = os.path.join("media", "textures")
GOLD = (0xD4, 0xAF, 0x6A)
GOLD_LIGHT = (0xF0, 0xD0, 0x8E)
DARK = (0x02, 0x05, 0x0A)
SHIELD_FILL = (0x12, 0x1B, 0x2A)
WHITE = (255, 255, 255)
SS = 4  # supersampling per axis


def write_tga(name, width, height, pixel):
    """pixel(x, y) -> (r, g, b, a) floats 0..1 for the pixel's centre area; y = 0 is the top row."""
    rows = []
    for y in range(height):
        row = bytearray()
        for x in range(width):
            r = g = b = a = 0.0
            for sy in range(SS):
                for sx in range(SS):
                    pr, pg, pb, pa = pixel(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS)
                    r, g, b, a = r + pr * pa, g + pg * pa, b + pb * pa, a + pa
            n = SS * SS
            if a > 0:
                r, g, b = r / a, g / a, b / a
            row += bytes((int(b * 255 + .5), int(g * 255 + .5), int(r * 255 + .5), int(a / n * 255 + .5)))
        rows.append(bytes(row))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 0x28)  # top-left origin
    with open(os.path.join(OUT, name), "wb") as f:
        f.write(header + b"".join(rows))


def rgb(c):
    return c[0] / 255, c[1] / 255, c[2] / 255


def empty():
    return (0.0, 0.0, 0.0, 0.0)


def circle(x, y, cx, cy, r):
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def inside_polygon(x, y, points):
    hit = False
    j = len(points) - 1
    for i, (xi, yi) in enumerate(points):
        xj, yj = points[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def segment_distance(x, y, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(x - (ax + t * dx), y - (ay + t * dy))


def main():
    os.makedirs(OUT, exist_ok=True)

    # Corner diamond: gold square turned 45 degrees with a dark outline (8 px in the design, drawn at 16).
    def diamond(x, y):
        d = abs(x - 8) + abs(y - 8)
        if d <= 5.2:
            return rgb(GOLD) + (1.0,)
        if d <= 7.6:
            return rgb(DARK) + (1.0,)
        return empty()
    write_tga("diamond.tga", 16, 16, diamond)

    # Filled circle: online dots, badges, and the mask for round portraits.
    write_tga("circle.tga", 64, 64, lambda x, y: rgb(WHITE) + (1.0,) if circle(x, y, 32, 32, 31) else empty())

    # Ring around portraits (tinted with the class colour).
    def ring(x, y):
        d = math.hypot(x - 32, y - 32)
        return rgb(WHITE) + (1.0,) if 26.5 <= d <= 31 else empty()
    write_tga("ring.tga", 64, 64, ring)

    # Shield emblem from the title bar: dark fill, gold outline and cross.
    outline = [(16, 2), (27, 7), (27, 16), (24.5, 23.5), (16, 30), (7.5, 23.5), (5, 16), (5, 7)]
    inner = [(16, 4.4), (25, 8.4), (25, 15.8), (23, 22.4), (16, 27.6), (9, 22.4), (7, 15.8), (7, 8.4)]

    def shield(x, y):
        if segment_distance(x, y, 16, 9, 16, 24) <= 1.1 or segment_distance(x, y, 10, 15, 22, 15) <= 1.1:
            return rgb(GOLD_LIGHT) + (1.0,)
        if inside_polygon(x, y, inner):
            return rgb(SHIELD_FILL) + (1.0,)
        if inside_polygon(x, y, outline):
            return rgb(GOLD_LIGHT) + (1.0,)
        return empty()
    write_tga("shield.tga", 32, 32, shield)

    # Close cross and settings gear (white, tinted gold in code).
    def cross(x, y):
        hit = segment_distance(x, y, 4, 4, 12, 12) <= 1.0 or segment_distance(x, y, 12, 4, 4, 12) <= 1.0
        return rgb(WHITE) + (1.0,) if hit else empty()
    write_tga("close.tga", 16, 16, cross)

    def gear(x, y):
        d = math.hypot(x - 8, y - 8)
        angle = math.atan2(y - 8, x - 8)
        tooth = abs(math.cos(4 * angle)) > 0.7
        if 2.2 <= d <= 4.6 or (4.6 < d <= 6.6 and tooth):
            return rgb(WHITE) + (1.0,)
        return empty()
    write_tga("gear.tga", 16, 16, gear)

    # Check mark for checkboxes.
    def check(x, y):
        hit = segment_distance(x, y, 4, 8.5, 7, 11.5) <= 1.1 or segment_distance(x, y, 7, 11.5, 12.5, 5) <= 1.1
        return rgb(WHITE) + (1.0,) if hit else empty()
    write_tga("check.tga", 16, 16, check)

    # Shine streak for the LEVEL UP chip: transparent edges, bright middle.
    write_tga("shine.tga", 64, 16, lambda x, y: rgb(WHITE) + (max(0.0, 1 - abs(x - 32) / 32) ** 2 * 0.8,))

    # Soft shadow: a blurred square for a nine-slice behind windows (corners 16 px).
    def shadow(x, y):
        edge = min(x, y, 64 - x, 64 - y)
        return (0.0, 0.0, 0.0, max(0.0, min(1.0, edge / 16)) ** 2 * 0.6)
    write_tga("shadow.tga", 64, 64, shadow)

    # Fold arrow (pointing down; turned in code for folded groups).
    write_tga("arrow.tga", 16, 16,
              lambda x, y: rgb(WHITE) + (1.0,) if inside_polygon(x, y, [(3, 5), (13, 5), (8, 11)]) else empty())

    # Quest scroll icon for the shared-quest count (CF-40): a page outline with three lines.
    def quest(x, y):
        page = (4 <= x <= 12 and 2 <= y <= 14) and not (5.4 <= x <= 10.6 and 3.4 <= y <= 12.6)
        lines = 5.8 <= x <= 10.2 and any(abs(y - ly) <= 0.55 for ly in (5.5, 8, 10.5))
        return rgb(WHITE) + (1.0,) if page or lines else empty()
    write_tga("quest.tga", 16, 16, quest)

    print("textures written to", OUT)


if __name__ == "__main__":
    main()
