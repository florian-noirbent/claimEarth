"""Generate the SVG diagrams used by the technical blog post.

Run from the repository root:  python3 blog/images/generate_diagrams.py
Each diagram explains one idea from one section of the post.
"""

from __future__ import annotations

import math
from pathlib import Path

OUT = Path(__file__).resolve().parent
W = 800
FONT = "-apple-system, 'Segoe UI', Helvetica, Arial, sans-serif"
SQ3 = math.sqrt(3)

C = {
    "ink": "#1f2933",
    "muted": "#5f6b7a",
    "line": "#9aa5b1",
    "border": "#e3e7ec",
    "panel": "#f5f7fa",
    "accent": "#2f6fde",
    "accent_bg": "#e6efff",
    "warm_bg": "#fff1e0",
    "bad": "#d64545",
    "bad_bg": "#fde8e8",
    "good": "#2e9e5b",
    "good_bg": "#e3f5ea",
    "air": "#eef2f6",
    "sand": "#e2b65a",
    "water": "#4a90d9",
    "lava": "#e8572a",
    "stone": "#8b8f96",
    "dirt": "#8d6a4a",
    "steam": "#c9d1db",
    "sulfur": "#e9d43b",
    "acid": "#9ccc3c",
    "so2": "#b08ad8",
}


def esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


class Svg:
    def __init__(self, name: str, title: str, height: int) -> None:
        self.name = name
        self.title = title
        self.h = height
        self.parts: list[str] = []
        self._clip = 0

    def add(self, s: str) -> None:
        self.parts.append(s)

    # --- primitives -------------------------------------------------------
    def text(self, x, y, s, size=15, weight=400, fill=None, anchor="middle", italic=False):
        fill = fill or C["ink"]
        style = ' font-style="italic"' if italic else ""
        self.add(
            f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}"{style}>{esc(s)}</text>'
        )

    def lines(self, x, y, items, size=15, weight=400, fill=None, anchor="middle", gap=None):
        gap = gap or size * 1.3
        for i, s in enumerate(items):
            self.text(x, y + i * gap, s, size, weight if i == 0 else 400, fill, anchor)

    def rect(self, x, y, w, h, fill=None, stroke=None, rx=8, sw=1.5, dash=False, opacity=1.0):
        fill = fill or C["panel"]
        stroke = stroke or C["line"]
        d = ' stroke-dasharray="6 5"' if dash else ""
        self.add(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{rx}" '
            f'fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d} opacity="{opacity}"/>'
        )

    def box(self, x, y, w, h, label, fill=None, stroke=None, size=15):
        self.rect(x, y, w, h, fill, stroke)
        n = len(label)
        gap = size * 1.3
        top = y + h / 2 - (n - 1) * gap / 2 + size * 0.35
        for i, s in enumerate(label):
            self.text(x + w / 2, top + i * gap, s, size if i == 0 else size - 2,
                      600 if i == 0 else 400, C["ink"] if i == 0 else C["muted"])

    def arrow(self, x1, y1, x2, y2, color="ink", sw=2, dash=False):
        d = ' stroke-dasharray="6 5"' if dash else ""
        self.add(
            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{C[color]}" '
            f'stroke-width="{sw}"{d} marker-end="url(#ah-{color})"/>'
        )

    def path_arrow(self, d, color="ink", sw=2, dash=False):
        ds = ' stroke-dasharray="6 5"' if dash else ""
        self.add(
            f'<path d="{d}" fill="none" stroke="{C[color]}" stroke-width="{sw}"{ds} '
            f'marker-end="url(#ah-{color})"/>'
        )

    def line(self, x1, y1, x2, y2, color="line", sw=1.5, dash=False):
        d = ' stroke-dasharray="4 4"' if dash else ""
        self.add(
            f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
            f'stroke="{C[color]}" stroke-width="{sw}"{d}/>'
        )

    @staticmethod
    def hex_points(cx, cy, r):
        pts = []
        for i in range(6):
            a = math.radians(60 * i)
            pts.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
        return " ".join(pts)

    def hexagon(self, cx, cy, r, fill, stroke="#ffffff", sw=2, dash=False, opacity=1.0):
        d = ' stroke-dasharray="5 4"' if dash else ""
        self.add(
            f'<polygon points="{self.hex_points(cx, cy, r)}" fill="{fill}" stroke="{stroke}" '
            f'stroke-width="{sw}"{d} opacity="{opacity}"/>'
        )

    def filled_hex(self, cx, cy, r, material, frac, stroke=None, sw=2):
        """Air hex with the bottom `frac` filled by `material`."""
        stroke = stroke or C["line"]
        self._clip += 1
        cid = f"clip-{self.name}-{self._clip}"
        h = r * SQ3 / 2
        self.add(f'<clipPath id="{cid}"><polygon points="{self.hex_points(cx, cy, r)}"/></clipPath>')
        self.hexagon(cx, cy, r, C["air"], "none", 0)
        top = cy + h - 2 * h * frac
        self.add(
            f'<rect x="{cx - r:.1f}" y="{top:.1f}" width="{2 * r:.1f}" height="{2 * h * frac + 1:.1f}" '
            f'fill="{C[material]}" clip-path="url(#{cid})"/>'
        )
        self.hexagon(cx, cy, r, "none", stroke, sw)

    # --- output -------------------------------------------------------------
    def render(self) -> str:
        markers = "".join(
            f'<marker id="ah-{k}" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="10" '
            f'markerHeight="10" markerUnits="userSpaceOnUse" orient="auto-start-reverse">'
            f'<path d="M0,0 L10,5 L0,10 z" fill="{C[k]}"/></marker>'
            for k in ("ink", "accent", "bad", "good", "muted")
        )
        head = (
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {self.h}" '
            f'width="{W}" height="{self.h}" font-family="{FONT}" role="img">\n'
            f"<title>{esc(self.title)}</title>\n<defs>{markers}</defs>\n"
            f'<rect x="1" y="1" width="{W - 2}" height="{self.h - 2}" rx="14" fill="#ffffff" '
            f'stroke="{C["border"]}" stroke-width="2"/>\n'
            f'<text x="28" y="40" font-size="21" font-weight="700" fill="{C["ink"]}">{esc(self.title)}</text>\n'
        )
        return head + "\n".join(self.parts) + "\n</svg>\n"

    def save(self) -> None:
        (OUT / f"{self.name}.svg").write_text(self.render(), encoding="utf-8")


def hex_center(ox, oy, r, col, row):
    """Flat-top, odd-q offset layout (odd columns are shifted down)."""
    x = ox + col * 1.5 * r
    y = oy + row * SQ3 * r + (SQ3 / 2 * r if col % 2 else 0)
    return x, y


# ---------------------------------------------------------------------------
# Intro
# ---------------------------------------------------------------------------
def d00_overview():
    s = Svg("00-overview", "One texture, three jobs", 340)
    s.rect(300, 95, 200, 170, C["panel"], C["ink"], sw=2)
    s.text(400, 122, "World texture", 16, 700)
    mats = ["air"] * 8 + ["air", "air", "sand", "air", "air", "water", "air", "air"] + \
           ["dirt", "sand", "sand", "dirt", "water", "water", "dirt", "dirt"] + \
           ["dirt", "dirt", "stone", "lava", "lava", "dirt", "stone", "dirt"]
    for i, m in enumerate(mats):
        cx, cy = 321 + (i % 8) * 20, 138 + (i // 8) * 20
        s.rect(cx, cy, 18, 18, C[m], "#ffffff", rx=2, sw=0.5)
    s.text(400, 245, "1 texel = 1 hex cell", 13, fill=C["muted"])

    s.box(30, 135, 170, 90, ["Simulate", "GPU render passes"], C["accent_bg"], C["accent"])
    s.arrow(298, 160, 204, 160)
    s.text(250, 152, "reads", 13, fill=C["muted"])
    s.arrow(202, 200, 296, 200)
    s.text(250, 192, "writes", 13, fill=C["muted"])

    s.box(600, 80, 170, 80, ["Draw", "presentation shader"], C["warm_bg"], "#e09a3e")
    s.arrow(502, 150, 596, 125)
    s.text(548, 124, "every frame", 13, fill=C["muted"])
    s.box(600, 200, 170, 80, ["Collide", "CPU copy for physics"], C["good_bg"], C["good"])
    s.arrow(502, 215, 596, 240)
    s.text(548, 250, "after each tick", 13, fill=C["muted"])

    s.text(400, 310, "A bomb edits a few bytes here, and all three jobs see the change.", 15, fill=C["muted"])
    s.save()


# ---------------------------------------------------------------------------
# Four bytes per hex
# ---------------------------------------------------------------------------
def d01_cell_bytes():
    s = Svg("01-four-bytes-per-hex", "Each hex is one texel of four bytes", 340)
    r = 30
    mats = {(0, 0): "air", (1, 0): "air", (2, 0): "air",
            (0, 1): "sand", (1, 1): "water", (2, 1): "air",
            (0, 2): "dirt", (1, 2): "dirt", (2, 2): "water"}
    for (col, row), m in mats.items():
        x, y = hex_center(80, 120, r, col, row)
        s.hexagon(x, y, r, C[m], "#ffffff", 2)
    hx, hy = hex_center(80, 120, r, 1, 1)
    s.hexagon(hx, hy, r, "none", C["accent"], 4)
    s.text(125, 300, "one hex on screen", 13, fill=C["muted"])

    s.arrow(195, 185, 255, 185, "accent")
    s.rect(265, 160, 50, 50, C["water"], C["accent"], rx=3, sw=3)
    s.text(290, 235, "one texel", 13, fill=C["muted"])
    s.arrow(325, 185, 380, 185, "accent")

    s.text(582, 128, "these bytes are data, not colors", 13, fill=C["muted"], italic=True)
    chans = [
        ("R", "#efe6fb", "#8a63c9", ["2 material IDs", "(4 bits each)"]),
        ("G", "#e3f5ea", C["good"], ["primary", "quantity"]),
        ("B", C["accent_bg"], C["accent"], ["light"]),
        ("A", C["warm_bg"], "#e09a3e", ["secondary", "quantity"]),
    ]
    for i, (ch, bg, st, desc) in enumerate(chans):
        x = 390 + i * 98
        s.rect(x, 145, 90, 80, bg, st, sw=2)
        s.text(x + 45, 195, ch, 28, 700, st)
        if ch == "R":
            s.line(x + 45, 205, x + 45, 222, "line", 1)
            s.text(x + 24, 219, "ID 1", 10, fill=C["muted"])
            s.text(x + 67, 219, "ID 2", 10, fill=C["muted"])
        s.lines(x + 45, 250, desc, 13, 400, C["muted"])
    s.text(400, 320, "100 × 512 cells × 4 bytes = 200 KiB for the whole world", 15, 600)
    s.save()


def d02_quantity():
    s = Svg("02-quantity-and-pressure", "Quantity: how full, and how compressed", 330)
    x0, x1, xm = 80, 720, 80 + 640 * 128 / 256
    s.text((x0 + xm) / 2, 82, "normal fill", 14, 600, C["water"])
    s.text((xm + x1) / 2, 82, "overpressure", 14, 600, "#2f5f9e")
    s.rect(x0, 92, xm - x0, 26, "#cfe2f6", C["water"], rx=4)
    s.rect(xm, 92, x1 - xm, 26, "#9dbbe0", "#2f5f9e", rx=4)
    for v, x in ((0, x0), (127, xm), (255, x1)):
        s.text(x, 138, str(v), 13, fill=C["muted"])

    items = [(0, 0.0, "0: empty"), (64, 0.5, "64: half full"), (127, 1.0, "127: looks full"),
             (200, 1.0, "200: full + pressure")]
    for i, (_, frac, label) in enumerate(items):
        cx = 150 + i * 170
        s.filled_hex(cx, 210, 36, "water", frac)
        s.text(cx, 275, label, 14)
    cx, cy = 150 + 3 * 170, 210
    for ang in (-150, -90, -30):
        a = math.radians(ang)
        s.arrow(cx + 40 * math.cos(a), cy + 40 * math.sin(a),
                cx + 58 * math.cos(a), cy + 58 * math.sin(a), "accent", 2.5)
    s.text(400, 312, "Water, sand and lava never look bigger than full. Extra quantity is stored pressure.",
           14, fill=C["muted"])
    s.save()


# ---------------------------------------------------------------------------
# Simulating terrain with render passes
# ---------------------------------------------------------------------------
def d03_why_pairs():
    s = Svg("03-why-pairs", "Why cells trade material in pairs", 370)
    s.rect(20, 60, 370, 250, C["bad_bg"], C["bad"], sw=1)
    s.rect(410, 60, 370, 250, C["good_bg"], C["good"], sw=1)
    s.text(205, 88, "If every cell pushes on its own…", 15, 700, C["bad"])
    s.text(595, 88, "…fixed pairs can't collide", 15, 700, C["good"])

    r = 30
    h = SQ3 / 2 * r
    tx, ty = 205, 225
    sources = [(tx - 1.5 * r, ty - h), (tx, ty - 2 * h), (tx + 1.5 * r, ty - h)]
    for sx, sy in sources:
        s.hexagon(sx, sy, r, C["water"], "#ffffff", 2)
    s.filled_hex(tx, ty, r, "water", 0.4, C["bad"], 3)
    for sx, sy in sources:
        s.arrow(sx + (tx - sx) * 0.25, sy + (ty - sy) * 0.25,
                sx + (tx - sx) * 0.75, sy + (ty - sy) * 0.75, "bad", 3)
    s.text(205, 280, "room for 1 unit, but 3 neighbors", 13, 600, C["bad"])
    s.text(205, 297, "each send 1 at the same time", 13, 600, C["bad"])

    r2 = 24
    step = SQ3 * r2
    cx = 545
    ys = [118, 118 + step, 118 + 2 * step + 22, 118 + 3 * step + 22]
    for i, y in enumerate(ys):
        if i % 2 == 0:
            s.hexagon(cx, y, r2, C["water"], "#ffffff", 2)
        else:
            s.filled_hex(cx, y, r2, "water", 0.3)
    for a, b, name in ((0, 1, "pair A"), (2, 3, "pair B")):
        s.rect(cx - 32, ys[a] - 26, 64, ys[b] - ys[a] + 52, "none", C["good"], rx=16, sw=2.5, dash=True)
        s.arrow(cx, ys[a] + 8, cx, ys[b] - 8, "good", 2.5)
        s.text(cx + 50, (ys[a] + ys[b]) / 2 + 5, name, 14, 600, C["good"], "start")
    s.lines(690, 210, ["only the two", "cells of a pair", "decide what", "moves between", "them"],
            12, 400, C["muted"])
    s.text(400, 345, "Each cell belongs to exactly one pair per pass, so no space is claimed twice.",
           15, fill=C["muted"])
    s.save()


def d04_even_odd():
    s = Svg("04-even-and-odd-pairs", "Even and odd pairings take turns", 380)
    r = 21
    step = SQ3 * r
    ys = [100 + i * step for i in range(6)]
    for cx, title, pairs in ((260, "Even pass", [(0, 1), (2, 3), (4, 5)]),
                             (540, "Odd pass", [(1, 2), (3, 4)])):
        s.text(cx, 72, title, 16, 700)
        paired = {i for p in pairs for i in p}
        owner = {i: k for k, p in enumerate(pairs) for i in p}
        for i, y in enumerate(ys):
            if i in paired:
                k = owner[i]
                s.hexagon(cx, y, r, C["accent_bg"] if k % 2 == 0 else C["good_bg"],
                          C["accent"] if k % 2 == 0 else C["good"], 2)
            else:
                s.hexagon(cx, y, r, "#f7f7f7", C["line"], 1.5, opacity=0.6)
            s.text(cx - 40, y + 5, f"row {i}", 12, fill=C["muted"], anchor="end")
        for k, (a, b) in enumerate(pairs):
            col = "accent" if k % 2 == 0 else "good"
            s.add(f'<line x1="{cx}" y1="{ys[a] + 6:.1f}" x2="{cx}" y2="{ys[b] - 6:.1f}" '
                  f'stroke="{C[col]}" stroke-width="2.5" marker-start="url(#ah-{col})" '
                  f'marker-end="url(#ah-{col})"/>')
        for i in set(range(6)) - paired:
            s.text(cx + 32, ys[i] + 5, "sits out", 12, fill=C["muted"], anchor="start", italic=True)
    s.text(400, 340, "Alternating the pairs lets material cross every boundary between rows.", 15,
           fill=C["muted"])
    s.text(400, 362, "The same trick is used for the two diagonal directions.", 13, fill=C["muted"])
    s.save()


def d05_six_passes():
    s = Svg("05-six-pass-tick", "One tick = six passes, always in this order", 280)
    dirs = [("vertical", 90), ("down-right", 30), ("down-left", 150)]
    for i in range(6):
        x = 40 + i * 123
        even = i < 3
        name, ang = dirs[i % 3]
        s.rect(x, 80, 110, 110, C["accent_bg"] if even else C["warm_bg"],
               C["accent"] if even else "#e09a3e", sw=2)
        s.text(x + 16, 102, str(i + 1), 15, 700, C["muted"])
        a = math.radians(ang)
        cx, cy = x + 55, 130
        s.arrow(cx - 20 * math.cos(a), cy - 20 * math.sin(a), cx + 20 * math.cos(a),
                cy + 20 * math.sin(a), "accent" if even else "ink", 3)
        s.text(x + 55, 172, name, 13, 600)
        if i < 5:
            s.arrow(x + 111, 135, x + 121, 135, "muted", 1.5)
    for x0, x1, label, col in ((40, 396, "even pairs", "accent"), (409, 765, "odd pairs", "ink")):
        s.line(x0, 205, x1, 205, col, 2)
        s.line(x0, 199, x0, 211, col, 2)
        s.line(x1, 199, x1, 211, col, 2)
        s.text((x0 + x1) / 2, 226, label, 14, 600, C[col])
    s.text(400, 262, "10 ticks per second  =  60 passes per second", 15, 600)
    s.save()


def d06_time_not_fps():
    s = Svg("06-time-not-frame-rate", "Terrain speed follows time, not frame rate", 330)
    x0, px = 210, 5.4  # 0 ms at x0, pixels per ms

    def X(ms):
        return x0 + ms * px

    passes = [100 / 6 * k for k in range(1, 7)]
    for p in passes:
        s.line(X(p), 82, X(p), 262, "accent", 1.2, dash=True)
    rows = [(100, "passes due"), (170, "fast: 120 fps"), (240, "slow: 20 fps")]
    for y, label in rows:
        s.text(195, y + 5, label, 14, 600, anchor="end")
    for p in passes:
        s.add(f'<polygon points="{X(p):.1f},{88} {X(p) + 9:.1f},{100} {X(p):.1f},{112} '
              f'{X(p) - 9:.1f},{100}" fill="{C["accent"]}"/>')
    for k in range(12):
        a, b = k * 100 / 12, (k + 1) * 100 / 12
        n = 1 if k % 2 == 1 else 0
        s.rect(X(a) + 1, 152, (b - a) * px - 2, 36, C["accent_bg"] if n else "#f7f7f7",
               C["accent"] if n else C["line"], rx=4, sw=1)
        s.text((X(a) + X(b)) / 2, 175, str(n), 13, 600, C["ink"] if n else C["muted"])
    for k in range(2):
        a, b = k * 50, (k + 1) * 50
        s.rect(X(a) + 1, 222, 50 * px - 2, 36, C["accent_bg"], C["accent"], rx=4, sw=1)
        s.text((X(a) + X(b)) / 2, 245, "3 passes in one frame", 13, 600)
    s.line(X(0), 278, X(100), 278, "muted", 1.5)
    for ms in (0, 50, 100):
        s.line(X(ms), 273, X(ms), 283, "muted", 1.5)
        s.text(X(ms), 298, f"{ms} ms", 12, fill=C["muted"])
    s.text(400, 320, "Numbers = passes submitted in that frame. Both rows finish one full tick.", 13,
           fill=C["muted"])
    s.save()


# ---------------------------------------------------------------------------
# Keeping displaced material inside a cell
# ---------------------------------------------------------------------------
def d07_displaced():
    s = Svg("07-hidden-secondary-material", "Displaced water hides inside the cell", 370)
    r = 32
    h = SQ3 / 2 * r
    steps = [
        ("1. Sand above water", "sand", "water", 0.0, ["primary: water", "secondary: none"]),
        ("2. Sand falls in", "air", "sand", 0.0, ["primary: sand (visible)", "secondary: water (hidden)"]),
        ("3. Water finds room", "air", "sand", 0.6, ["primary: sand", "secondary: none"]),
    ]
    for i, (title, top, bottom, side_frac, desc) in enumerate(steps):
        px = 20 + i * 260
        s.rect(px, 60, 240, 250, C["panel"], C["border"])
        s.text(px + 120, 86, title, 15, 700)
        cx = px + 80
        y_top, y_bot = 135, 135 + 2 * h
        sx, sy = cx + 1.5 * r, y_bot - h  # up-right neighbour of the bottom cell
        s.hexagon(cx, y_top, r, C[top] if top != "air" else C["air"], C["line"] if top == "air" else "#ffffff")
        s.hexagon(cx, y_bot, r, C[bottom], C["accent"], 3)
        s.filled_hex(sx + 0, sy + 2 * h, r, "water", side_frac)  # down-right neighbour
        if i == 0:
            s.arrow(cx, y_top + 4, cx, y_bot - 6, "ink", 2.5)
        if i == 1:
            s.hexagon(cx, y_bot, r * 0.5, "none", C["water"], 2.5, dash=True)
        if i == 2:
            s.arrow(cx + 10, y_bot + 6, sx - 8, sy + 2 * h - 4, "accent", 2.5)
        s.text(px + 20, 262, "Highlighted cell:", 12, 700, C["muted"], "start")
        s.lines(px + 20, 280, desc, 13, 400, C["ink"], "start", gap=17)
    s.text(400, 345, "Hidden water is never deleted: later passes move it out when there is room.", 15,
           fill=C["muted"])
    s.save()


# ---------------------------------------------------------------------------
# How the materials interact
# ---------------------------------------------------------------------------
def node(s: Svg, x, y, mat, label, r=30, ring=None):
    s.hexagon(x, y, r, C[mat], ring or "#ffffff", 3 if ring else 2)
    s.text(x, y + r + 22, label, 14, 600)


def d08_water_lava():
    s = Svg("08-water-lava-steam", "Water, lava and steam", 380)
    s.text(40, 85, "Boiling and condensing", 14, 700, C["accent"], "start")
    y = 150
    node(s, 80, y, "water", "water")
    s.text(135, y + 6, "+", 22, 700, C["muted"])
    node(s, 190, y, "lava", "lava")
    s.arrow(232, y, 358, y)
    s.text(295, y - 12, "1 water → 10 steam", 13, fill=C["muted"])
    node(s, 400, y, "steam", "steam")
    s.arrow(400, y - 34, 400, y - 62, "muted", 2)
    s.text(412, y - 50, "can vent out at the top", 12, fill=C["muted"], anchor="start")
    s.arrow(442, y, 608, y)
    s.text(525, y - 12, "10 steam → 1 water", 13, fill=C["muted"])
    s.text(525, y + 22, "10% / tick under stone or dirt", 12, fill=C["muted"])
    node(s, 650, y, "water", "drips back down")

    s.line(40, 230, 760, 230, "border", 1.5)
    s.text(40, 262, "Lava cooling", 14, 700, C["accent"], "start")
    y = 310
    node(s, 190, y, "lava", "lava touching water")
    s.arrow(232, y, 358, y)
    s.text(295, y - 12, "2% / tick", 13, fill=C["muted"])
    node(s, 400, y, "stone", "stone")
    s.lines(450, y - 4, ["the crust can seal the water", "away from the heat"], 13, 400, C["muted"],
            "start")
    s.save()


def d09_sulfur():
    s = Svg("09-sulfur-routes", "Sulfur's two routes", 380)
    s.text(40, 85, "With water: acid", 14, 700, C["accent"], "start")
    y = 150
    node(s, 80, y, "water", "water")
    s.text(135, y + 6, "+", 22, 700, C["muted"])
    node(s, 190, y, "sulfur", "sulfur")
    s.arrow(232, y, 358, y)
    s.text(295, y - 12, "slowly", 13, fill=C["muted"])
    node(s, 400, y, "acid", "acid (sinks)")
    s.arrow(442, y, 608, y)
    s.text(525, y - 12, "eats sand below it", 13, fill=C["muted"])
    node(s, 650, y, "water", "back to water")

    s.line(40, 230, 760, 230, "border", 1.5)
    s.text(40, 262, "With lava: poison gas", 14, 700, C["accent"], "start")
    y = 310
    node(s, 80, y, "lava", "lava")
    s.text(135, y + 6, "+", 22, 700, C["muted"])
    node(s, 190, y, "sulfur", "sulfur")
    s.arrow(232, y, 358, y)
    s.text(295, y - 12, "ignites", 13, fill=C["muted"])
    node(s, 400, y, "sulfur", "burning sulfur", ring=C["lava"])
    s.arrow(442, y, 608, y)
    s.text(525, y - 12, "keeps burning,", 13, fill=C["muted"])
    s.text(525, y + 22, "even after the lava leaves", 12, fill=C["muted"])
    node(s, 650, y, "so2", "SO₂: poisons player")
    s.save()


# ---------------------------------------------------------------------------
# Drawing the cave with one quad
# ---------------------------------------------------------------------------
def d10_one_quad():
    s = Svg("10-one-quad-shader", "How the shader colors one pixel", 300)
    titles = [("1. A screen pixel", ["for every pixel", "of the one quad"]),
              ("2. Which hex?", ["hex coordinate +", "spot inside it"]),
              ("3. Read the texel", ["material, fill,", "light"]),
              ("4. Pick a color", ["atlas art, edges,", "shading"])]
    for i, (t, cap) in enumerate(titles):
        x = 30 + i * 190
        s.rect(x, 70, 160, 160, C["panel"], C["border"])
        s.text(x + 80, 96, t, 15, 700)
        cx, cy = x + 80, 142
        if i == 0:
            for gx in range(4):
                for gy in range(3):
                    hl = (gx, gy) == (2, 1)
                    s.rect(cx - 40 + gx * 20, cy - 30 + gy * 20, 18, 18,
                           C["accent"] if hl else "#ffffff", C["line"], rx=1, sw=1)
        elif i == 1:
            s.hexagon(cx, cy, 32, C["air"], C["line"])
            s.add(f'<circle cx="{cx + 12}" cy="{cy + 8}" r="5" fill="{C["accent"]}"/>')
        elif i == 2:
            for k, col in enumerate(("#8a63c9", C["good"], C["accent"], "#e09a3e")):
                s.rect(cx - 44 + k * 23, cy - 18, 20, 36, "#ffffff", col, rx=3, sw=2)
                s.text(cx - 34 + k * 23, cy + 5, "RGBA"[k], 12, 700, col)
        else:
            s.filled_hex(cx, cy, 32, "sand", 0.75, C["dirt"], 3)
        s.lines(x + 80, 198, cap, 13, 400, C["muted"])
        if i < 3:
            s.arrow(x + 163, 150, x + 187, 150, "ink", 2)
    s.text(400, 272, "No terrain mesh: after a bomb, the next frame simply reads the new bytes.", 15,
           fill=C["muted"])
    s.save()


# ---------------------------------------------------------------------------
# Colliding with the committed world
# ---------------------------------------------------------------------------
def d11_two_copies():
    s = Svg("11-gpu-cpu-loop", "Two copies of the world", 370)
    s.box(40, 150, 190, 70, ["CPU cells", "WorldGrid (committed)"], C["good_bg"], C["good"])
    s.box(305, 70, 190, 70, ["GPU passes", "6 per tick"], C["accent_bg"], C["accent"])
    s.box(570, 150, 190, 70, ["Completed texture", "on the GPU"], C["accent_bg"], C["accent"])
    s.arrow(200, 148, 300, 112)
    s.text(232, 118, "upload", 13, fill=C["muted"])
    s.arrow(498, 112, 598, 148)
    s.text(570, 118, "after pass 6", 13, fill=C["muted"])
    s.arrow(566, 200, 234, 200, "good", 2.5)
    s.text(400, 192, "read back after every complete tick", 13, 600, C["good"])

    s.box(570, 280, 190, 56, ["Draw the cave"], C["warm_bg"], "#e09a3e")
    s.arrow(665, 222, 665, 276)
    s.text(675, 255, "every frame", 12, fill=C["muted"], anchor="start")
    s.box(40, 280, 190, 56, ["Collision & gameplay"], C["good_bg"], C["good"])
    s.arrow(135, 222, 135, 276)
    s.text(145, 255, "queries", 12, fill=C["muted"], anchor="start")
    s.lines(400, 290, ["Physics only ever sees", "finished ticks."], 13, 400, C["muted"])
    s.save()


def d12_collision_query():
    s = Svg("12-collision-query", "Collision only checks nearby hexes", 380)
    r = 26
    ox, oy = 62, 95
    floor = {0: 3, 1: 3, 2: 3, 3: 3, 4: 3, 5: 2, 6: 2, 7: 2}
    body = (125, 158, 30, 48)  # x, y, w, h
    bcx, bcy = body[0] + body[2] / 2, body[1] + body[3] / 2
    for col in range(8):
        for row in range(5):
            x, y = hex_center(ox, oy, r, col, row)
            if row < floor[col]:
                mat = "air"
            elif (col, row) in ((5, 2), (6, 2)):
                mat = "water"
            elif (col, row) == (1, 3):
                mat = "sand"
            else:
                mat = "dirt"
            near = math.hypot(x - bcx, y - bcy) < 82
            fill = C[mat]
            s.hexagon(x, y, r, fill, C["line"] if mat == "air" else "#ffffff", 1.5,
                      opacity=1.0 if near else 0.35)
            if near:
                solid = mat in ("dirt", "sand")
                s.hexagon(x, y, r - 2, "none", C["accent"] if solid else C["muted"], 3 if solid else 1.5,
                          dash=not solid)
    s.rect(*body, C["bad"], "#7a1f1f", rx=6, sw=2)
    s.add(f'<text x="{bcx}" y="{body[1] - 8}" font-size="12" font-weight="700" fill="{C["bad"]}" '
          f'text-anchor="middle" stroke="#ffffff" stroke-width="4" paint-order="stroke">player</text>')

    steps = [("1. Find nearby cells", "from the body's position"),
             ("2. Keep the solid ones", "material + fill (sand: half full)"),
             ("3. Test the shapes", "body vs. hex polygon")]
    for i, (t, sub) in enumerate(steps):
        y = 105 + i * 72
        s.text(470, y, t, 15, 700, anchor="start")
        s.text(470, y + 20, sub, 13, fill=C["muted"], anchor="start")
    s.hexagon(482, 318, 11, "none", C["accent"], 3)
    s.text(500, 323, "solid candidate", 12, fill=C["muted"], anchor="start")
    s.hexagon(632, 318, 11, "none", C["muted"], 1.5, dash=True)
    s.text(650, 323, "ignored", 12, fill=C["muted"], anchor="start")
    s.text(400, 362, "Hex polygons are computed on the fly. There are no collider objects.", 14,
           fill=C["muted"])
    s.save()


# ---------------------------------------------------------------------------
# Making explosions and simulation agree
# ---------------------------------------------------------------------------
def d13_explosion():
    s = Svg("13-explosion-restart", "When a bomb lands in the middle of a tick", 360)
    s.text(118, 125, "GPU", 15, 700, anchor="end")
    s.text(118, 255, "Gameplay", 15, 700, anchor="end")
    s.line(130, 120, 780, 120, "border", 1)
    s.line(130, 250, 780, 250, "border", 1)

    def pass_box(x, n, kind):
        fill, st = {"ok": (C["accent_bg"], C["accent"]), "dead": ("#f3f3f3", C["line"]),
                    "new": (C["good_bg"], C["good"])}[kind]
        s.rect(x, 100, 44, 40, fill, st, rx=5, sw=1.5)
        s.text(x + 22, 125, str(n), 14, 600, C["muted"] if kind == "dead" else C["ink"])
        if kind == "dead":
            s.line(x + 8, 108, x + 36, 132, "bad", 1.2)
            s.line(x + 36, 108, x + 8, 132, "bad", 1.2)

    for k in range(3):
        pass_box(140 + k * 50, k + 1, "ok")
    for k in range(3):
        pass_box(320 + k * 50, k + 4, "dead")
    s.box(482, 100, 112, 40, ["upload world"], C["good_bg"], C["good"], 14)
    for k in range(3):
        pass_box(610 + k * 50, k + 1, "new")
    s.text(212, 88, "tick in progress", 13, fill=C["muted"])
    s.text(392, 88, "cancelled", 13, 700, C["bad"])
    s.text(685, 88, "restart from new state", 13, 700, C["good"])

    s.line(302, 70, 302, 280, "bad", 2, dash=True)
    s.add(f'<circle cx="302" cy="250" r="16" fill="{C["lava"]}" stroke="#7a2a10" stroke-width="2"/>')
    s.text(302, 300, "bomb edits CPU cells", 13, 600)
    s.path_arrow("M 320 250 C 440 250 520 230 536 146", "good", 2.5)
    s.text(470, 268, "exact list of changed cells", 13, fill=C["good"])
    s.text(400, 338, "The old tick never commits, so it can't paint over the crater.", 15, fill=C["muted"])
    s.save()


# ---------------------------------------------------------------------------
# The costs of this architecture
# ---------------------------------------------------------------------------
def d14_costs():
    s = Svg("14-what-scales", "What a bigger map costs", 320)
    s.rect(30, 65, 360, 190, C["good_bg"], C["good"], sw=1)
    s.rect(410, 65, 360, 190, C["warm_bg"], "#e09a3e", sw=1)
    s.text(210, 95, "Stays the same", 16, 700, C["good"])
    s.text(590, 95, "Grows with cell count", 16, 700, "#b36b12")
    left = ["1 terrain quad, 1 shader", "0 scene Nodes per cell", "0 physics colliders per cell"]
    right = ["texture memory (4 bytes / cell)", "work in each simulation pass", "CPU readback every tick"]
    for i, t in enumerate(left):
        s.text(60, 140 + i * 38, "✓  " + t, 15, anchor="start")
    for i, t in enumerate(right):
        s.text(440, 140 + i * 38, "↑  " + t, 15, anchor="start")
    s.text(400, 288, "Drawing cost follows screen pixels: one draw call doesn't mean free shading.", 14,
           fill=C["muted"])
    s.save()


if __name__ == "__main__":
    for fn in (d00_overview, d01_cell_bytes, d02_quantity, d03_why_pairs, d04_even_odd, d05_six_passes,
               d06_time_not_fps, d07_displaced, d08_water_lava, d09_sulfur, d10_one_quad,
               d11_two_copies, d12_collision_query, d13_explosion, d14_costs):
        fn()
    print("wrote diagrams to", OUT)
