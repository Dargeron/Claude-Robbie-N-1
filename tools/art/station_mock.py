#!/usr/bin/env python3
"""Mock-up of the operator's console: the whole game as one dark station desk (Dead Air + Bathy).

The sonar receiver takes about a third of the screen; everything else is a machine on the desk: the wire recorder
and the teleprinter under the scope, the card rack and the keypunch (Robbie's program), the reader-load gauge (CPU),
the dispatch lever, the sector selector, the pneumatic tube, Bathy's mood porthole and the spare hulls.

Usage: python3 tools/art/station_mock.py <sonar_render.png> <out.png>
  sonar_render.png is a raw Dead Air frame (tools/art/mood_scene.py 3).
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from post import arr, bloom, font, grain, hexc, img, luminance, vignette  # noqa: E402

W, H = 1280, 720
RNG = np.random.default_rng(8)
AMBER = (255, 176, 72)
GREEN = (150, 255, 170)
INK = (26, 20, 14)
CREAM = (233, 223, 199)
BRASS, BRASS_D, BRASS_L = hexc("#b8862f"), hexc("#5a3c12"), hexc("#f0c878")
BAKELITE, BAKELITE_L = hexc("#1e1009"), hexc("#3a2214")
STEEL, STEEL_L, STEEL_D = hexc("#1b2329"), hexc("#34424b"), hexc("#0b0f12")


def layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def glow(base, lay, radius, times=2):
    g = lay.filter(ImageFilter.GaussianBlur(radius))
    for _ in range(times):
        base.alpha_composite(g)
    base.alpha_composite(lay)


def screw(d, x, y, r=6):
    d.ellipse((x - r, y - r, x + r, y + r), fill=BRASS_D)
    d.ellipse((x - r + 1, y - r + 1, x + r - 1, y + r - 1), fill=BRASS)
    a = random.uniform(0, math.pi)
    d.line((x - math.cos(a) * (r - 2), y - math.sin(a) * (r - 2), x + math.cos(a) * (r - 2),
            y + math.sin(a) * (r - 2)), fill=BRASS_D, width=2)


def plate(d, box, text, size=15, fill=BRASS, ink=hexc("#2a1a08")):
    """An engraved brass name plate."""
    x0, y0, x1, y1 = box
    d.rounded_rectangle(box, 3, fill=BRASS_D)
    d.rounded_rectangle((x0 + 1, y0 + 1, x1 - 1, y1 - 1), 3, fill=fill)
    d.text(((x0 + x1) / 2, (y0 + y1) / 2 + 1), text, font=font("BigShoulders", size), fill=ink, anchor="mm")


def panel(d, box, r=10, fill=STEEL, edge=STEEL_D, light=STEEL_L, screws=True):
    x0, y0, x1, y1 = box
    d.rounded_rectangle(box, r, fill=edge)
    d.rounded_rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 3), r - 2, fill=fill)
    d.line((x0 + r, y0 + 4, x1 - r, y0 + 4), fill=light, width=1)
    if screws:
        for x, y in ((x0 + 11, y0 + 11), (x1 - 11, y0 + 11), (x0 + 11, y1 - 11), (x1 - 11, y1 - 11)):
            screw(d, x, y, 4)


# --- the bulkhead ---------------------------------------------------------------------------------------------------

def bulkhead():
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    a = np.ones((H, W, 3), np.float32) * np.array([0.04, 0.05, 0.058])
    a *= (0.85 + 0.15 * grain((H, W), 4, 31))[..., None]
    a *= (0.9 + 0.1 * grain((H, W), 60, 32))[..., None]
    streaks = np.zeros((H, W), np.float32)
    for _ in range(26):  # condensation running down the plates
        sx = RNG.uniform(0, W)
        length = RNG.uniform(60, 320)
        sy = RNG.uniform(0, H - length)
        m = (np.abs(x - sx - 2 * np.sin(y / 37.0)) < 1.2) & (y > sy) & (y < sy + length)
        streaks = np.maximum(streaks, m * RNG.uniform(0.02, 0.05))
    a += streaks[..., None]
    base = img(a * vignette((H, W), 0.55, 2.2)[..., None]).convert("RGBA")
    d = ImageDraw.Draw(base)
    for sx in range(0, W, 160):  # plate seams with rivets
        d.line((sx, 0, sx, H), fill=(6, 8, 10, 255), width=3)
        d.line((sx + 2, 0, sx + 2, H), fill=(40, 50, 58, 255), width=1)
        for ry in range(10, H, 26):
            d.ellipse((sx - 5, ry - 2, sx - 1, ry + 2), fill=(44, 54, 62, 255))
            d.ellipse((sx + 4, ry - 2, sx + 8, ry + 2), fill=(44, 54, 62, 255))
    for py, r in ((16, 9), (34, 6)):  # pipes along the ceiling
        d.rectangle((0, py - r, W, py + r), fill=(22, 28, 33, 255))
        d.line((0, py - r + 2, W, py - r + 2), fill=(52, 62, 70, 255), width=1)
        for fx in range(40, W, 210):
            d.rectangle((fx, py - r - 3, fx + 10, py + r + 3), fill=BRASS_D)
            d.line((fx + 1, py - r - 2, fx + 1, py + r + 2), fill=BRASS, width=2)
    return base


# --- the sonar receiver -----------------------------------------------------------------------------------------------

SX0, SY0, SX1, SY1 = 26, 62, 618, 478
CROP = (40, 60, 920, 714)


def to_scope(px, py):
    k = (SX1 - SX0) / (CROP[2] - CROP[0])
    return (px - CROP[0]) * k, (py - CROP[1]) * k


def bathy_glyph(d, cx, cy, heading_deg, s=1.0, color=AMBER):
    """Robbie's transponder: Bathy drawn in amber phosphor, the only warm thing on the green screen."""
    a = math.radians(-heading_deg)
    fx, fy = math.cos(a), math.sin(a)
    r = 15 * s
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(60, 34, 6, 255), outline=color, width=max(2, int(2.5 * s)))
    for side in (-1, 1):  # propeller pods
        px, py = cx - fy * side * r * 1.05, cy + fx * side * r * 1.05
        d.ellipse((px - 4 * s, py - 4 * s, px + 4 * s, py + 4 * s), outline=color, width=2)
    px, py = cx + fx * r * 0.55, cy + fy * r * 0.55  # porthole with its little face
    pr = 8.5 * s
    d.ellipse((px - pr, py - pr, px + pr, py + pr), fill=(14, 10, 4, 255), outline=color, width=2)
    for side in (-1, 1):
        ex, ey = px - fy * side * 3.2 * s, py + fx * side * 3.2 * s
        d.ellipse((ex - 1.6 * s, ey - 2.6 * s, ex + 1.6 * s, ey + 2.6 * s), fill=(255, 236, 200, 255))
    ax, ay = cx - fx * r * 0.2, cy - fy * r * 0.2  # antenna light on top-back
    d.ellipse((ax - 2.2 * s, ay - 2.2 * s, ax + 2.2 * s, ay + 2.2 * s), fill=(160, 255, 170, 255))


def scope(base, sonar):
    sw, sh = SX1 - SX0, SY1 - SY0
    content = sonar.convert("RGB").crop(CROP).resize((sw, sh), Image.LANCZOS)
    d = ImageDraw.Draw(content)
    rx, ry = to_scope(288, 400)
    d.ellipse((rx - 30, ry - 30, rx + 30, ry + 30), fill=(0, 0, 0))  # Bathy is drawn on top in amber
    f = font("VT323", 22)
    d.text((16, 10), "RX 38.2 Mc   ROBBIE 007   SECTOR 2: THE JELLYFISH", font=f, fill=GREEN)
    d.text((sw - 140, 10), "DEPTH 412 fm", font=f, fill=GREEN)
    for i, (x, y) in enumerate(((548, 330), (808, 455), (1015, 238))):
        cx, cy = to_scope(x, y)
        if cx < sw - 40:
            d.text((cx + 14, cy - 26), "C-%d" % (i + 1), font=font("VT323", 18), fill=GREEN)
    d.text((to_scope(396, 566)[0], to_scope(396, 566)[1]), "?? ECHO", font=font("VT323", 18), fill=(110, 200, 130))
    a = arr(content)
    L = luminance(a) ** 0.85
    a = np.array([0.01, 0.04, 0.015]) + L[..., None] * np.array([0.42, 1.0, 0.55])
    a = arr(bloom(img(a), 0.4, 5, 0.6))
    h, w = a.shape[:2]
    # Robbie's lamp, an amber wedge, and Robbie himself: drawn after the green mapping so they stay warm.
    warm = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    wd = ImageDraw.Draw(warm, "RGBA")
    heading = 8
    for k in range(18, 0, -1):
        reach = 30 + k * 9
        half = math.radians(24)
        hx = math.radians(-heading)
        pts = [(rx, ry)] + [(rx + math.cos(hx + t) * reach, ry + math.sin(hx + t) * reach)
                            for t in np.linspace(-half, half, 12)]
        wd.polygon(pts, fill=(255, 170, 60, 11))
    bathy_glyph(wd, rx, ry, heading, 1.6)
    warm_b = warm.filter(ImageFilter.GaussianBlur(4))
    scr = img(a).convert("RGBA")
    scr.alpha_composite(warm_b)
    scr.alpha_composite(warm)
    a = arr(scr)
    yy = np.arange(h)[:, None]
    band = (np.sin(yy * 0.05 + 1.3) > 0.94) * 0.16
    a = a + (RNG.normal(0, 1, (h, w)) * (0.07 + band))[..., None] * np.array([0.55, 1.0, 0.6])
    a = a + (RNG.random((h, w)) > 0.997)[..., None] * 0.6
    a[::3] *= 0.72
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    nu, nv = (u - w / 2) / (w / 2), (v - h / 2) / (h / 2)
    r2 = nu * nu + nv * nv
    su = np.clip((nu * (0.94 + 0.06 * r2) * (w / 2) + w / 2).astype(int), 0, w - 1)
    sv = np.clip((nv * (0.94 + 0.06 * r2) * (h / 2) + h / 2).astype(int), 0, h - 1)
    a = a[sv, su] * vignette((h, w), 0.6, 3.0)[..., None]
    screen = img(a).convert("RGBA")
    # The receiver's case: bakelite, a brass ring, screws; green light spills onto the bulkhead.
    spill = layer()
    ImageDraw.Draw(spill).rounded_rectangle((SX0 - 30, SY0 - 30, SX1 + 30, SY1 + 30), 60, fill=(40, 255, 120, 40))
    base.alpha_composite(spill.filter(ImageFilter.GaussianBlur(40)))
    d = ImageDraw.Draw(base)
    d.rounded_rectangle((SX0 - 16, SY0 - 16, SX1 + 16, SY1 + 16), 46, fill=BAKELITE)
    d.rounded_rectangle((SX0 - 9, SY0 - 9, SX1 + 9, SY1 + 9), 40, outline=BRASS, width=5)
    for x, y in ((SX0 - 4, SY0 - 4), (SX1 + 4, SY0 - 4), (SX0 - 4, SY1 + 4), (SX1 + 4, SY1 + 4)):
        screw(d, x, y, 5)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, sh - 1), 34, fill=255)
    base.paste(screen, (SX0, SY0), mask.filter(ImageFilter.GaussianBlur(1.2)))
    lay = layer()
    ld = ImageDraw.Draw(lay)
    ld.ellipse((SX0 + 18, SY1 - 30, SX0 + 30, SY1 - 18), fill=(255, 60, 40, 255))
    ld.text((SX0 + 36, SY1 - 33), "LIVE", font=font("VT323", 18), fill=(255, 120, 100, 255))
    glow(base, lay, 4)
    d = ImageDraw.Draw(base)
    plate(d, (SX0 + 20, SY0 - 40, SX0 + 260, SY0 - 22), "SONAR RECEIVER Mk II  ·  JOVIAN TELEGRAPH Co.", 13)
    # The magnifier: pull the hood down over the scope for full screen.
    mx, my = SX1 - 40, SY0 - 31
    d.rounded_rectangle((mx - 48, my - 10, mx + 34, my + 10), 4, fill=BAKELITE_L)
    d.rectangle((mx + 8, my - 6, mx + 28, my + 6), fill=BRASS)
    d.text((mx - 44, my), "MAGNIFY", font=font("BigShoulders", 13), fill=BRASS_L, anchor="lm")


# --- wire recorder and teleprinter -----------------------------------------------------------------------------------

def recorder(base):
    d = ImageDraw.Draw(base)
    box = (SX0 - 16, 520, SX1 + 16, 598)
    panel(d, box, screws=False)
    for cx in (66, 146):
        d.ellipse((cx - 30, 559 - 30, cx + 30, 559 + 30), fill=BAKELITE, outline=BRASS_D, width=3)
        d.ellipse((cx - 22, 559 - 22, cx + 22, 559 + 22), fill=(70, 62, 50, 255))
        for k in range(3):
            a = k * 2 * math.pi / 3 + (0.4 if cx > 100 else 0)
            d.line((cx, 559, cx + math.cos(a) * 20, 559 + math.sin(a) * 20), fill=BRASS, width=3)
        d.ellipse((cx - 5, 554, cx + 5, 564), fill=BRASS)
    d.line((66, 531, 146, 531), fill=(160, 160, 150, 255), width=1)
    t0, t1, ty = 196, 600, 540
    d.rounded_rectangle((t0, ty - 5, t1, ty + 5), 4, fill=STEEL_D)
    for k in range(21):
        x = t0 + k * (t1 - t0) / 20
        d.line((x, ty + 7, x, ty + (13 if k % 5 == 0 else 10)), fill=(110, 120, 120, 255), width=1)
    lay = layer()
    ld = ImageDraw.Draw(lay)
    for x, c in ((262, AMBER), (330, GREEN), (402, GREEN)):  # events on the wire: contacts, the active card
        ld.polygon([(x, ty - 7), (x - 5, ty - 15), (x + 5, ty - 15)], fill=c + (255,))
    ld.rounded_rectangle((t0, ty - 3, 402, ty + 3), 3, fill=GREEN + (255,))
    glow(base, lay, 3)
    d = ImageDraw.Draw(base)
    d.ellipse((396, ty - 9, 408, ty + 9), fill=BRASS_L)
    for i, label in enumerate(("◀◀", "▶", "▶▶", "TO LAST LOSS")):
        x0 = 196 + i * 64 if i < 3 else 388
        x1 = x0 + 54 if i < 3 else 520
        d.rounded_rectangle((x0, 562, x1, 588), 5, fill=BAKELITE_L, outline=(10, 6, 4, 255))
        d.text(((x0 + x1) / 2, 575), label, font=font("BigShoulders", 15), fill=BRASS_L, anchor="mm")
    cx, cy = 572, 575  # the speed dial
    d.ellipse((cx - 17, cy - 17, cx + 17, cy + 17), fill=BAKELITE, outline=BRASS, width=2)
    d.line((cx, cy, cx + 10, cy - 10), fill=BRASS_L, width=3)
    for k, s in enumerate(("½", "1", "2", "4", "8")):
        a = math.radians(200 + k * 35)
        d.text((cx + math.cos(a) * 27, cy + math.sin(a) * 27), s, font=font("BigShoulders", 11), fill=BRASS_L,
               anchor="mm")
    plate(d, (26, 500, 146, 514), "WIRE RECORDER", 12)


def teleprinter(base):
    d = ImageDraw.Draw(base)
    d.rounded_rectangle((SX0 - 16, 606, SX1 + 16, 626), 6, fill=BAKELITE)
    d.rectangle((40, 614, 600, 618), fill=(4, 2, 1, 255))
    tape = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    td = ImageDraw.Draw(tape)
    top, bottom = 617, 714
    pts = [(46, top), (594, top), (594, bottom - 6)]
    x = 594
    while x > 46:
        pts.append((x, bottom - (6 if (x // 9) % 2 else 0)))
        x -= 9
    pts.append((46, bottom))
    td.polygon(pts, fill=CREAM + (255,))
    lines = ["0:00.0  DISPATCHED  ROBBIE 007  TO SECTOR 2", "0:01.4  CONTACT C-1  BRG 040  RNG 3 fm",
             "0:01.6  CARD 1  KEEP DISTANCE 4  RUNNING", "0:01.9  CONTACT C-2  BRG 075  RNG 5 fm"]
    for i, s in enumerate(lines):
        td.text((60, top + 6 + i * 21), s, font=font("SpecialElite", 15), fill=INK + (255,))
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shade.paste((0, 0, 0, 120), (4, 6), tape.split()[3])
    base.alpha_composite(shade.filter(ImageFilter.GaussianBlur(4)))
    base.alpha_composite(tape)
    plate(ImageDraw.Draw(base), (486, 609, 606, 623), "TELEPRINTER", 12)


# --- top row: tube, sector selector, shift, Bathy's mood, spare hulls ----------------------------------------------

def top_row(base):
    d = ImageDraw.Draw(base)
    # The pneumatic tube: Company memos arrive here.
    d.rectangle((646, 0, 690, 118), fill=BRASS_D)
    d.rectangle((650, 0, 686, 118), fill=BRASS)
    d.rectangle((654, 34, 682, 98), fill=(30, 40, 44, 255))
    d.rounded_rectangle((657, 44, 679, 92), 8, fill=hexc("#8a6a3a"), outline=BRASS_D)
    d.rectangle((686, 58, 716, 74), fill=hexc("#8a1e1e"))
    d.text((701, 66), "NEW", font=font("BigShoulders", 12), fill=CREAM, anchor="mm")
    d.rounded_rectangle((640, 116, 696, 134), 4, fill=BRASS_D)
    plate(d, (632, 140, 706, 154), "COMPANY TUBE", 11)
    # The sector selector: turn it to choose the room.
    cx, cy = 806, 86
    d.ellipse((cx - 44, cy - 44, cx + 44, cy + 44), fill=STEEL_D)
    d.ellipse((cx - 34, cy - 34, cx + 34, cy + 34), fill=BAKELITE, outline=BRASS, width=3)
    names = (("1 DARK", 756, 118, "rm"), ("2 JELLY", 750, 86, "rm"), ("3 NURSERY", 772, 52, "rm"),
             ("4 VALVE", 840, 52, "lm"), ("5 LISTEN", 862, 86, "lm"), ("6 LOCK", 856, 118, "lm"))
    for k, (s_, lx, ly, anc) in enumerate(names):
        d.text((lx, ly), s_, font=font("BigShoulders", 12), fill=BRASS_L if k == 1 else (120, 110, 90, 255),
               anchor=anc)
    a = math.radians(196)
    d.polygon([(cx + math.cos(a) * 30, cy + math.sin(a) * 30), (cx + math.cos(a + 2.6) * 10,
                                                                 cy + math.sin(a + 2.6) * 10),
               (cx + math.cos(a - 2.6) * 10, cy + math.sin(a - 2.6) * 10)], fill=BRASS_L)
    plate(d, (770, 140, 842, 154), "SECTOR", 11)
    # Shift counter, in nixie tubes.
    lay = layer()
    ld = ImageDraw.Draw(lay)
    for i, ch in enumerate("03"):
        x0 = 920 + i * 34
        d.rounded_rectangle((x0, 44, x0 + 28, 92), 9, fill=(10, 8, 6, 255), outline=(120, 110, 100, 255), width=1)
        ld.text((x0 + 14, 68), ch, font=font("BigShoulders", 32), fill=(255, 138, 42, 255), anchor="mm")
    glow(base, lay, 5)
    d = ImageDraw.Draw(base)
    plate(d, (916, 100, 986, 114), "SHIFT", 11)
    # Bathy's mood: a porthole on the console that shows his face screen, live.
    cx, cy, r = 1058, 84, 54
    spill = layer()
    ImageDraw.Draw(spill).ellipse((cx - 80, cy - 80, cx + 80, cy + 80), fill=(80, 220, 255, 50))
    base.alpha_composite(spill.filter(ImageFilter.GaussianBlur(26)))
    d = ImageDraw.Draw(base)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=hexc("#7a4a22"))
    d.ellipse((cx - r + 6, cy - r + 6, cx + r - 6, cy + r - 6), fill=hexc("#c8893a"))
    for k in range(12):
        a = k * math.pi / 6
        d.ellipse((cx + math.cos(a) * (r - 3) - 3, cy + math.sin(a) * (r - 3) - 3, cx + math.cos(a) * (r - 3) + 3,
                   cy + math.sin(a) * (r - 3) + 3), fill=hexc("#5a3216"))
    ri = r - 14
    d.ellipse((cx - ri, cy - ri, cx + ri, cy + ri), fill=hexc("#16202c"))
    lay = layer()
    ld = ImageDraw.Draw(lay)
    for side in (-1, 1):  # worried eyes: tall ovals, inner corners raised
        ex = cx + side * 13
        ld.ellipse((ex - 7, cy - 16, ex + 7, cy + 8), fill=(122, 240, 255, 255))
        ld.polygon([(ex - 9, cy - 18), (ex + 9, cy - 18), (ex + 9 * side, cy - 9)], fill=(22, 32, 44, 255))
    for side in (-1, 1):
        ld.ellipse((cx + side * 25 - 6, cy + 10, cx + side * 25 + 6, cy + 17), fill=(255, 154, 168, 200))
    glow(base, lay, 4)
    d = ImageDraw.Draw(base)
    d.arc((cx - ri + 6, cy - ri + 6, cx + ri - 18, cy + ri - 18), 200, 250, fill=(255, 255, 255, 90), width=3)
    plate(d, (1012, 146, 1104, 160), "ROBBIE 007 · MOOD", 11)
    # Spare hulls hanging in the hangar window: the way to the Lab.
    x0, y0, x1, y1 = 1136, 22, 1262, 160
    d.rounded_rectangle((x0, y0, x1, y1), 10, fill=BRASS_D)
    d.rounded_rectangle((x0 + 5, y0 + 5, x1 - 5, y1 - 5), 8, fill=(8, 10, 12, 255))
    for i, (hx, hy) in enumerate(((1162, 74), (1199, 92), (1236, 70))):
        d.line((hx, y0 + 6, hx, hy - 14), fill=(90, 90, 90, 255), width=1)
        d.ellipse((hx - 13, hy - 13, hx + 13, hy + 13), fill=hexc("#8c5a24"))
        d.ellipse((hx - 11, hy - 12, hx + 9, hy + 9), fill=hexc("#c8893a"))
        d.ellipse((hx + 2, hy - 6, hx + 12, hy + 4), fill=hexc("#5a3216"))
        d.ellipse((hx + 4, hy - 4, hx + 10, hy + 2), fill=hexc("#16202c"))
    d.text(((x0 + x1) / 2, 132), "TO THE HANGAR >", font=font("BigShoulders", 15), fill=BRASS_L, anchor="mm")
    plate(d, (1140, 166, 1258, 180), "SPARE HULLS · 3", 11)


# --- the program: card rack, load gauge, dispatch lever, keypunch -------------------------------------------------

CARDS = [("1", "KEEP DISTANCE  4", "IF  HOSTILE NEAR  4", 6, "run"),
         ("2", "LAMP  OFF", "IF  HOSTILE NEAR  6", 4, "skip"),
         ("3", "MOVE TOWARDS  BEACON", "", 2, "idle"),
         ("4", "FOLLOW WALL  LEFT", "IF  WALL AHEAD", 5, "idle")]


def card(base, x, y, num, order, cond, cpu, state):
    w, h = 362, 60
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    d.polygon([(x + 12, y), (x + w, y), (x + w, y + h), (x, y + h), (x, y + 12)], fill=CREAM + (255,))
    rnd = random.Random(int(num))
    for col in range(30):  # punched holes, a pattern per card
        for row in range(2):
            if rnd.random() < 0.45:
                hx, hy = x + 46 + col * 9.6, y + h - 17 + row * 8
                d.rectangle((hx, hy, hx + 4, hy + 5), fill=(30, 26, 20, 255))
    d.text((x + 22, y + 22), num, font=font("BigShoulders", 30), fill=INK + (255,), anchor="mm")
    d.text((x + 44, y + 6), order, font=font("SpecialElite", 18), fill=INK + (255,))
    if cond:
        d.text((x + 44, y + 25), cond, font=font("SpecialElite", 15), fill=hexc("#5a3a20"))
    d.ellipse((x + w - 34, y + 8, x + w - 10, y + 32), outline=hexc("#8a1e1e"), width=2)
    d.text((x + w - 22, y + 20), str(cpu), font=font("BigShoulders", 16), fill=hexc("#8a1e1e"), anchor="mm")
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shade.paste((0, 0, 0, 140), (3, 5), lay.split()[3])
    base.alpha_composite(shade.filter(ImageFilter.GaussianBlur(3)))
    base.alpha_composite(lay)
    # The pilot lamp beside each card: amber while it runs, dim red when its condition failed.
    lamp = layer()
    ld = ImageDraw.Draw(lamp)
    lx, ly = x - 22, y + 30
    color = {"run": (255, 176, 60, 255), "skip": (150, 40, 30, 255), "idle": (40, 30, 24, 255)}[state]
    d2 = ImageDraw.Draw(base)
    d2.ellipse((lx - 11, ly - 11, lx + 11, ly + 11), fill=BRASS_D)
    ld.ellipse((lx - 7, ly - 7, lx + 7, ly + 7), fill=color)
    glow(base, lamp, 6 if state == "run" else 2, 3 if state == "run" else 1)
    if state == "skip":
        d2.text((x + w - 44, y + 44), "NO CONTACT", font=font("BigShoulders", 11), fill=hexc("#8a1e1e"), anchor="rm")


def program(base):
    d = ImageDraw.Draw(base)
    panel(d, (632, 190, 1032, 532))
    d.rectangle((646, 206, 652, 518), fill=BRASS_D)
    for i, (num, order, cond, cpu, state) in enumerate(CARDS):
        card(base, 664, 206 + i * 78, num, order, cond, cpu, state)
    d = ImageDraw.Draw(base)
    plate(d, (842, 183, 1022, 197), "PROGRAM · READ TOP TO BOTTOM", 11)
    # A note from the operator before you, taped to card 2.
    note = Image.new("RGBA", (232, 52), (0, 0, 0, 0))
    nd = ImageDraw.Draw(note)
    nd.rectangle((0, 6, 226, 50), fill=(238, 222, 150, 255))
    nd.rectangle((90, 0, 136, 11), fill=(220, 220, 200, 150))
    nd.text((8, 8), "jellies LOVE the light.", font=font("PatrickHand", 18), fill=(40, 40, 90, 255))
    nd.text((8, 28), "lamp OFF near them!  — Op. 5", font=font("PatrickHand", 16), fill=(40, 40, 90, 255))
    note = note.rotate(-3, resample=Image.BICUBIC, expand=True)
    sh = Image.new("RGBA", note.size, (0, 0, 0, 0))
    sh.paste((0, 0, 0, 110), (0, 0), note.split()[3])
    base.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3)), (394, 444))
    base.alpha_composite(note, (390, 440))
    # Reader load (CPU): what the punch cards weigh against Robbie's card reader.
    d = ImageDraw.Draw(base)
    panel(d, (1046, 190, 1262, 334))
    cx, cy, r = 1154, 300, 82
    d.pieslice((cx - r, cy - r, cx + r, cy + r), 180, 360, fill=CREAM)
    d.pieslice((cx - r, cy - r, cx + r, cy + r), 342, 360, fill=hexc("#c0392b"))
    d.pieslice((cx - r + 14, cy - r + 14, cx + r - 14, cy + r - 14), 180, 360, fill=CREAM)
    for k in range(11):
        a = math.radians(180 + k * 18)
        d.line((cx + math.cos(a) * (r - 4), cy + math.sin(a) * (r - 4), cx + math.cos(a) * (r - 16),
                cy + math.sin(a) * (r - 16)), fill=INK, width=2 if k % 5 == 0 else 1)
        if k % 2 == 0:
            d.text((cx + math.cos(a) * (r - 28), cy + math.sin(a) * (r - 28)), str(k * 2), font=font("BigShoulders", 13),
                   fill=INK, anchor="mm")
    a = math.radians(180 + 17 * 18 / 2)
    d.line((cx, cy, cx + math.cos(a) * (r - 10), cy + math.sin(a) * (r - 10)), fill=hexc("#1a1010"), width=3)
    d.ellipse((cx - 7, cy - 7, cx + 7, cy + 7), fill=BRASS)
    d.text((cx, cy - 30), "17 / 20", font=font("BigShoulders", 18), fill=INK, anchor="mm")
    plate(d, (1084, 312, 1224, 326), "CARD READER LOAD", 11)
    # Dispatch: the lever that sends Robbie down.
    panel(d, (1046, 344, 1262, 532))
    d.rounded_rectangle((1144, 372, 1164, 500), 8, fill=(4, 4, 4, 255))
    d.line((1154, 486, 1110, 392), fill=hexc("#6a6a6a"), width=9)
    d.line((1154, 486, 1110, 392), fill=hexc("#a0a0a0"), width=3)
    d.ellipse((1092, 372, 1128, 408), fill=hexc("#8a1e1e"), outline=hexc("#3a0808"), width=2)
    d.ellipse((1100, 378, 1112, 390), fill=(220, 120, 110, 255))
    d.polygon([(1176, 372), (1240, 360), (1240, 420), (1176, 410)], fill=hexc("#8a1e1e"))
    d.text((1208, 390), "SAFETY", font=font("BigShoulders", 11), fill=CREAM, anchor="mm")
    lay = layer()
    ImageDraw.Draw(lay).ellipse((1214, 470, 1230, 486), fill=(120, 255, 140, 255))
    glow(base, lay, 5)
    d = ImageDraw.Draw(base)
    d.text((1206, 478), "READY", font=font("BigShoulders", 13), fill=GREEN, anchor="rm")
    plate(d, (1066, 508, 1244, 524), "DISPATCH  ROBBIE 008", 13)


def keypunch(base):
    d = ImageDraw.Draw(base)
    x0, y0, x1, y1 = 632, 548, 1262, 712
    d.rounded_rectangle((x0, y0, x1, y1), 14, fill=hexc("#0e1614"))
    d.rounded_rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 3), 12, fill=hexc("#22302c"))
    d.line((x0 + 14, y0 + 6, x1 - 14, y0 + 6), fill=hexc("#3c524c"), width=1)
    d.rectangle((x0 + 30, y0 - 6, x0 + 330, y0 + 8), fill=(4, 4, 4, 255))  # the card throat

    def drum(bx, by, bw, label, rows, pick):
        d.rounded_rectangle((bx, by, bx + bw, by + 96), 8, fill=(6, 8, 8, 255), outline=BRASS, width=3)
        for k, s in enumerate(rows):
            yy = by + 16 + k * 32
            bright = k == pick
            d.text((bx + 14, yy), s, font=font("SpecialElite", 19 if bright else 15),
                   fill=CREAM if bright else (90, 96, 92, 255), anchor="lm")
        d.line((bx + 6, by + 32, bx + bw - 6, by + 32), fill=(40, 46, 44, 255))
        d.line((bx + 6, by + 64, bx + bw - 6, by + 64), fill=(40, 46, 44, 255))
        plate(d, (bx + 10, by + 100, bx + 130, by + 114), label, 11)

    drum(x0 + 18, y0 + 26, 232, "ORDER DRUM", ["KEEP DISTANCE", "MOVE TOWARDS", "FOLLOW WALL"], 1)
    d.text((x0 + 172, y0 + 74), "BEACON", font=font("SpecialElite", 17), fill=AMBER, anchor="lm")
    drum(x0 + 262, y0 + 26, 210, "CONDITION DRUM", ["ALWAYS", "IF HOSTILE NEAR", "IF WALL AHEAD"], 1)
    wx, wy = x0 + 482, y0 + 26  # the parameter wheel
    d.rounded_rectangle((wx, wy, wx + 40, wy + 96), 8, fill=(6, 8, 8, 255), outline=BRASS, width=3)
    for k, s_ in enumerate(("2", "4", "6")):
        d.text((wx + 20, wy + 16 + k * 32), s_, font=font("BigShoulders", 24 if k == 1 else 16),
               fill=AMBER if k == 1 else (90, 96, 92, 255), anchor="mm")
    sx, sy = x0 + 534, y0 + 58  # NOT switch
    d.rounded_rectangle((sx, sy - 18, sx + 26, sy + 18), 6, fill=BAKELITE_L)
    d.line((sx + 13, sy, sx + 13, sy - 24), fill=hexc("#c0c0c0"), width=5)
    d.text((sx + 13, sy + 32), "NOT", font=font("BigShoulders", 12), fill=BRASS_L, anchor="mm")
    px, py = x1 - 46, y0 + 80  # the punch lever
    d.rectangle((px - 6, py - 4, px + 6, py + 60), fill=(6, 6, 6, 255))
    d.line((px, py + 50, px, py - 30), fill=hexc("#9a9a9a"), width=8)
    d.ellipse((px - 16, py - 48, px + 16, py - 16), fill=hexc("#8a1e1e"), outline=hexc("#3a0808"), width=2)
    d.text((px, py + 76), "PUNCH", font=font("BigShoulders", 13), fill=BRASS_L, anchor="mm")
    plate(d, (x0 + 360, y1 - 26, x0 + 560, y1 - 12), "KEYPUNCH · NEW CARD COSTS 4", 11)


def main():
    sonar = Image.open(sys.argv[1])
    out = sys.argv[2]
    random.seed(4)
    base = bulkhead()
    scope(base, sonar)
    recorder(base)
    teleprinter(base)
    top_row(base)
    program(base)
    keypunch(base)
    a = arr(base) * vignette((H, W), 0.35, 2.4)[..., None]
    img(a).save(out, optimize=True)
    print("wrote", out)


if __name__ == "__main__":
    main()
