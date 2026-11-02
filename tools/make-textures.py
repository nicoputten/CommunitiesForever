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

    celebrations()

    print("textures written to", OUT)


def hexrgb(h):
    return int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255


def paint(layers):
    """A pixel function from layers drawn in order: (test(x, y) -> alpha 0..1 or bool, 'RRGGBB')."""
    def pixel(x, y):
        r = g = b = a = 0.0
        for test, colour in layers:
            alpha = test(x, y)
            alpha = (1.0 if alpha else 0.0) if isinstance(alpha, bool) else alpha
            if alpha <= 0:
                continue
            cr, cg, cb = hexrgb(colour)
            out = alpha + a * (1 - alpha)
            r = (cr * alpha + r * a * (1 - alpha)) / out
            g = (cg * alpha + g * a * (1 - alpha)) / out
            b = (cb * alpha + b * a * (1 - alpha)) / out
            a = out
        return (r, g, b, a)
    return pixel


def scaled(scale, test):
    """A test in the board's SVG units drawn at `scale` pixels per unit."""
    return lambda x, y: test(x / scale, y / scale)


def line(ax, ay, bx, by, width):
    return lambda x, y: segment_distance(x, y, ax, ay, bx, by) <= width / 2


def disc(cx, cy, r):
    return lambda x, y: circle(x, y, cx, cy, r)


def polygon(points):
    return lambda x, y: inside_polygon(x, y, points)


def polygon_outline(points, width):
    def test(x, y):
        for i, (ax, ay) in enumerate(points):
            bx, by = points[(i + 1) % len(points)]
            if segment_distance(x, y, ax, ay, bx, by) <= width / 2:
                return True
        return False
    return test


def recap_icon(name, colour, glyph):
    """A round recap icon from the boards (viewBox 128: a coloured disc with a soft highlight, a dark glyph in a
    24-unit box at translate(26 26) scale(3.1667)), drawn at 64 px."""
    k = 64 / 128

    def highlight(x, y):
        d = math.hypot(x - 0.35 * 64, y - 0.28 * 64)
        return 0.38 * max(0.0, 1 - d / (0.55 * 0.7 * 64)) if circle(x, y, 32, 32, 30) else 0.0
    unit = k * 3.1667
    layers = [(disc(32, 32, 30), colour), (highlight, "FFFFFF")]
    layers += [(lambda x, y, t=t: t((x - 26 * k) / unit, (y - 26 * k) / unit), "0B1322") for t in glyph]
    write_tga(name, 64, 64, paint(layers))


def celebrations():
    """CF-67: the celebration banners' shapes and medallion icons, from the boards in
    docs/design/celebrations-2026-11/ (their SVG paths, polygons where the board has curves)."""
    # The plaque's angled end: a triangle pointing left (mirrored in code for the right end), white for tinting.
    write_tga("plaqueend.tga", 32, 64, lambda x, y: rgb(WHITE) + (1.0,) if x >= abs(y - 32) else empty())
    # The bright line on the plaque's top edge, fading out at both ends.
    write_tga("edgeline.tga", 64, 4, lambda x, y: rgb(WHITE) + (max(0.0, 1 - abs(x - 32) / 32),))
    # A soft round glow (big feats' medallion).
    write_tga("glow.tga", 64, 64, lambda x, y: rgb(WHITE) + (max(0.0, 1 - math.hypot(x - 32, y - 32) / 32) ** 2,))

    # Rays behind a big feat's medallion: 7 degrees on in every 20, faded towards the edge.
    def rays(x, y):
        d = math.hypot(x - 64, y - 64) / 64
        angle = math.degrees(math.atan2(y - 64, x - 64)) % 20
        fade = max(0.0, min(1.0, (0.7 - d) / 0.4))
        return rgb(WHITE) + ((1.0 if angle < 7 else 0.0) * fade,)
    write_tga("rays.tga", 128, 128, rays)

    # The medallion (drawn for the 74 px one, 3 px border): a bronze outer line, a dark gap, a gap for the tinted
    # border (medalring.tga) and the face, a radial gradient from #22324D to #0A111D.
    size = 74 + 7
    k = 128 / size

    def medal(x, y):
        d = math.hypot(x - 64, y - 64) / k
        if d > size / 2:
            return empty()
        if d > size / 2 - 1.5:
            return hexrgb("B8975A") + (1.0,)
        if d > size / 2 - 3.5:
            return hexrgb("0A111D") + (1.0,)
        if d > 74 / 2 - 3:
            return empty()
        t = min(1.0, math.hypot(x - 0.4 * 128, y - 0.32 * 128) / (0.75 * 64))
        a, b = hexrgb("22324D"), hexrgb("0A111D")
        return tuple(a[i] + (b[i] - a[i]) * t for i in range(3)) + (1.0,)
    write_tga("medal.tga", 128, 128, medal)

    def medalring(x, y):
        d = math.hypot(x - 64, y - 64) / k
        return rgb(WHITE) + (1.0,) if 74 / 2 - 3 <= d <= 74 / 2 + 0.3 else empty()
    write_tga("medalring.tga", 128, 128, medalring)

    # A done goal box with its check (CB01, viewBox 16).
    s = 64 / 16
    write_tga("goaldone.tga", 64, 64, paint([
        (scaled(s, lambda x, y: 0.5 <= x <= 15.5 and 0.5 <= y <= 15.5), "D4AF6A"),
        (scaled(s, lambda x, y: 1.0 <= x <= 15.0 and 1.0 <= y <= 15.0), "2A2210"),
        (scaled(s, line(3.6, 8.2, 6.2, 10.8, 2)), "F0D08E"),
        (scaled(s, line(6.2, 10.8, 12.2, 4.6, 2)), "F0D08E"),
    ]))

    # The Doomsday emblem (CB02, viewBox 64): a sun with rays over the horizon, a bowl with a cross.
    def bowl(x, y):
        return y >= 40 and ((x - 32) / 18) ** 2 + ((y - 40) / 10.5) ** 2 <= 1

    def bowl_edge(x, y):
        if y < 38.8:
            return False
        d = math.hypot((x - 32) / 18, (y - 40) / 10.5)
        return abs(d - 1) * 12 <= 1.2 or (abs(y - 40) <= 1.2 and abs(x - 32) <= 18)
    sun_rays = [line(32, 34, 52.8, 22.0, 3), line(32, 34, 44.0, 13.2, 3), line(32, 34, 32.0, 10.0, 3),
                line(32, 34, 20.0, 13.2, 3), line(32, 34, 11.2, 22.0, 3)]
    write_tga("emblem.tga", 64, 64, paint(
        [(lambda x, y, t=t: 0.8 if t(x, y) else 0.0, "D4AF6A") for t in sun_rays]
        + [(disc(32, 34, 14), "F0D08E"), (line(6, 40, 58, 40, 3), "D4AF6A"), (bowl, "121B2A"),
           (bowl_edge, "F0D08E"), (line(27, 46, 37, 46, 2.4), "F0D08E"), (line(32, 41, 32, 51, 2.4), "F0D08E")]))

    # The crown of the first to finish (CB02, viewBox 16).
    s = 32 / 16
    crown = [(2, 12), (14, 12), (15, 4), (11, 7), (8, 2), (5, 7), (1, 4)]
    write_tga("crown.tga", 32, 32, paint([
        (scaled(s, polygon_outline(crown, 0.8)), "B88A3A"), (scaled(s, polygon(crown)), "F0D08E"),
        (scaled(s, lambda x, y: 2 <= x <= 14 and 12.5 <= y <= 14.5), "D4AF6A"),
    ]))

    # The streak's flame (CB02, viewBox 14).
    s = 32 / 14
    flame = [(7, 1), (8.5, 4), (10.4, 6), (11, 9), (10, 11.8), (7, 13), (4, 11.8), (3, 9), (3.6, 7), (5, 5),
             (5.6, 6.6), (6.2, 7), (6, 5), (6.5, 3)]
    write_tga("flame.tga", 32, 32, paint([(scaled(s, polygon(flame)), "F0A774")]))

    # Recap icons (CB03): the hourglass of a weekly, the crossed swords of PvP.
    hourglass = [(8, 4), (16, 4), (16, 6), (12.4, 12), (16, 18), (16, 20), (8, 20), (8, 18), (11.6, 12), (8, 6)]
    recap_icon("hourglass.tga", "C69B6D", [line(6.5, 3, 17.5, 3, 2.2), line(6.5, 21, 17.5, 21, 2.2),
                                           polygon(hourglass)])
    recap_icon("swords.tga", "E0625A", [
        line(6.2, 6.2, 14.6, 14.6, 3), line(17.8, 6.2, 9.4, 14.6, 3), line(11, 18, 18, 11, 2.6),
        line(13, 18, 6, 11, 2.6), line(15.6, 15.6, 18.8, 18.8, 2.4), line(8.4, 15.6, 5.2, 18.8, 2.4),
        polygon([(3.4, 3.4), (7.5, 4.7), (4.7, 7.5)]), polygon([(20.6, 3.4), (16.5, 4.7), (19.3, 7.5)]),
        disc(19.9, 19.9, 1.8), disc(4.1, 19.9, 1.8)])

    # A PvP rank's shield (CB04, viewBox 26) and the first epic's robe (CB04, viewBox 64).
    s = 64 / 26
    shield = [(13, 2), (22, 6), (22, 13), (20.5, 18.5), (13, 24), (5.5, 18.5), (4, 13), (4, 6)]
    write_tga("rank.tga", 64, 64, paint([
        (scaled(s, polygon(shield)), "D4AF6A"), (scaled(s, polygon_outline(shield, 0.8)), "7A5A22"),
        (scaled(s, disc(13, 13, 1.4)), "0B0F14"),
    ]))
    robe = [(14, 10), (50, 10), (46, 24), (52, 54), (12, 54), (18, 24)]
    write_tga("epic.tga", 64, 64, paint([
        (polygon(robe), "2A1438"), (polygon_outline(robe, 2.4), "C27BFF"),
        (line(22, 10, 32, 22, 2.4), "C27BFF"), (line(32, 22, 42, 10, 2.4), "C27BFF"),
        (lambda x, y: 0.6 if segment_distance(x, y, 32, 22, 32, 54) <= 0.8 else 0.0, "C27BFF"),
    ]))


if __name__ == "__main__":
    main()
