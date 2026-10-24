#!/usr/bin/env python3
"""Finish the round-2 worlds: each one's medium (noir halftone, silent film, sonar CRT, painterly gouache, three-ink
woodcut) and its own UI, then a contact sheet.

Usage: python3 tools/art/mood_post.py <raw_dir> <out_dir>
  reads <raw_dir>/world_<n>.png, writes <out_dir>/world-<n>-<slug>.png and <out_dir>/worlds.png
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from post import arr, bloom, font, grain, hexc, img, luminance, text_size, vignette  # noqa: E402

NAMES = {1: "The Drowned Colony", 2: "The Pleasure Gardens", 3: "Dead Air", 4: "The Verdigris Reef",
         5: "The Red Spot Mine"}
WORDS = "I swam towards the pretty lights. Classic mistake."
RNG = np.random.default_rng(3)


def tag(base, n):
    d = ImageDraw.Draw(base)
    f = font("ChakraPetch", 17)
    s = "WORLD %d  ·  %s" % (n, NAMES[n].upper())
    w, h = text_size(d, s, f)
    d.rounded_rectangle((1280 - w - 30, 720 - h - 26, 1268, 708), 8, fill=(0, 0, 0, 170))
    d.text((1280 - w - 20, 720 - h - 21), s, font=f, fill=(255, 255, 255, 230))


def layer():
    return Image.new("RGBA", (1280, 720), (0, 0, 0, 0))


def composite(base, lay, shadow=None, glow=None):
    if shadow:
        off, blur, alpha = shadow
        sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
        sh.paste((0, 0, 0, alpha), off, lay.split()[3])
        base.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))
    if glow:
        g = lay.filter(ImageFilter.GaussianBlur(glow))
        base.alpha_composite(g)
        base.alpha_composite(g)
    base.alpha_composite(lay)


def halftone(a, cell, threshold, amount, ink=(0.0, 0.0, 0.0), angle=45):
    h, w = a.shape[:2]
    L = luminance(a)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    t = math.radians(angle)
    u, v = x * math.cos(t) + y * math.sin(t), -x * math.sin(t) + y * math.cos(t)
    du, dv = (u % cell) - cell / 2, (v % cell) - cell / 2
    radius = np.clip((threshold - L) / threshold, 0, 1) * cell * 0.55
    dots = (np.sqrt(du * du + dv * dv) < radius).astype(np.float32) * amount
    return a * (1 - dots[..., None]) + np.array(ink) * dots[..., None]


# --- 1. The Drowned Colony: noir, iron plates, nixie tubes, a telegram ------------------------------------------

def rivet_plate(d, box, fill="#2b3237", edge="#0c1013", light="#56626a", r=8):
    x0, y0, x1, y1 = box
    d.rounded_rectangle(box, r, fill=hexc(edge))
    d.rounded_rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 3), r - 2, fill=hexc(fill))
    d.line((x0 + 8, y0 + 5, x1 - 8, y0 + 5), fill=hexc(light), width=1)
    for cx, cy in ((x0 + 11, y0 + 11), (x1 - 11, y0 + 11), (x0 + 11, y1 - 11), (x1 - 11, y1 - 11)):
        d.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=hexc("#0c1013"))
        d.ellipse((cx - 2, cy - 3, cx + 1, cy), fill=hexc("#8a9aa2"))


def nixie(base, x, y, digits, size=40):
    """Glass tubes with glowing orange numerals."""
    tubes, glow = layer(), layer()
    d, g = ImageDraw.Draw(tubes), ImageDraw.Draw(glow)
    f = font("BigShoulders", size)
    for i, ch in enumerate(digits):
        tx = x + i * (size * 0.7 + 8)
        box = (tx, y, tx + size * 0.7, y + size * 1.25)
        d.rounded_rectangle(box, 10, fill=(10, 8, 6, 230), outline=(160, 150, 130, 120), width=2)
        w, h = text_size(g, ch, f)
        g.text((tx + (size * 0.7 - w) / 2, y + 2), ch, font=f, fill=hexc("#ff8a2a"))
    base.alpha_composite(tubes)
    gl = glow.filter(ImageFilter.GaussianBlur(5))
    base.alpha_composite(gl)
    base.alpha_composite(gl)
    base.alpha_composite(glow)


def world_1(im):
    a = arr(im)
    a = np.clip((a - 0.015) / 0.985, 0, 1) ** 1.08
    a = halftone(a, 6.0, 0.3, 0.55)
    a = a + RNG.normal(0, 0.018, a.shape[:2])[..., None]
    a = a * vignette(a.shape[:2], 0.5)[..., None]
    base = img(a).convert("RGBA")
    lay = layer()
    d = ImageDraw.Draw(lay)
    f = font("BigShoulders", 30)
    title = "ROBBIE 007  ·  THE JELLYFISH"
    tw, _ = text_size(d, title, f)
    rivet_plate(d, (22, 18, 22 + tw + 60, 72))
    d.text((52, 24), title, font=f, fill=hexc("#d8d0bc"))
    rivet_plate(d, (1000, 14, 1258, 92))
    d.text((1016, 30), "ENERGY", font=font("BigShoulders", 16), fill=hexc("#9aa4a8"))
    d.text((1016, 52), "02.0 s", font=font("BigShoulders", 16), fill=hexc("#9aa4a8"))
    composite(base, lay, shadow=((3, 4), 4, 140))
    nixie(base, 1090, 26, "072", 40)
    # The telegram: a form with tape pasted on it, slightly askew.
    t = layer()
    d = ImageDraw.Draw(t)
    fw = font("SpecialElite", 24)
    msg = "I SWAM TOWARDS THE PRETTY LIGHTS STOP CLASSIC MISTAKE STOP"
    mw, mh = text_size(d, msg, fw)
    x0, y0 = 640 - mw / 2 - 40, 586
    d.rectangle((x0, y0, x0 + mw + 80, y0 + 104), fill=hexc("#e4d6b4"))
    d.rectangle((x0, y0, x0 + mw + 80, y0 + 26), fill=hexc("#7a1a14"))
    d.text((x0 + 14, y0 + 2), "JOVIAN TELEGRAPH Co.", font=font("BigShoulders", 20), fill=hexc("#f0e0c0"))
    d.text((x0 + mw - 150, y0 + 4), "FROM: ROBBIE 007   02.0 SEC", font=font("SpecialElite", 15),
           fill=hexc("#f0e0c0"))
    d.rectangle((x0 + 26, y0 + 46, x0 + mw + 54, y0 + 84), fill=hexc("#f6eedc"))
    d.text((x0 + 40, y0 + 52), msg, font=fw, fill=hexc("#1a1410"))
    t = t.rotate(-0.8, resample=Image.BICUBIC, center=(640, 640))
    composite(base, t, shadow=((4, 6), 5, 160))
    rl = layer()
    ImageDraw.Draw(rl).text((26, 684), "RULE 1  >  MOVE TOWARDS BEACON", font=font("BigShoulders", 20),
                            fill=hexc("#8a9498"))
    base.alpha_composite(rl)
    return base


# --- 2. The Pleasure Gardens: tinted silent film, intertitles ---------------------------------------------------

def deco_frame(d, box, color, inset=8):
    x0, y0, x1, y1 = box
    d.rectangle(box, outline=color, width=2)
    d.rectangle((x0 + inset, y0 + inset, x1 - inset, y1 - inset), outline=color, width=1)
    for cx, cy, sx, sy in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
        for k in range(3):  # stepped corners
            s = 14 + k * 8
            d.line((cx + sx * (inset + 4), cy + sy * s, cx + sx * s, cy + sy * s), fill=color, width=1)
            d.line((cx + sx * s, cy + sy * (inset + 4), cx + sx * s, cy + sy * s), fill=color, width=1)


def world_2(im):
    a = arr(im)
    L = np.clip((luminance(a) - 0.02) / 0.88, 0, 1)
    L = L * L * (3 - 2 * L) * 0.8 + L * 0.2
    dark, light = np.array([0.015, 0.025, 0.06]), np.array([0.84, 0.89, 0.97])
    a = dark + (light - dark) * L[..., None]
    a = arr(bloom(img(a), 0.55, 9, 0.45))
    h, w = a.shape[:2]
    noise = np.asarray(Image.fromarray(((RNG.normal(0.5, 0.18, (h, w)).clip(0, 1)) * 255).astype(np.uint8))
                       .filter(ImageFilter.GaussianBlur(0.7))) / 255.0 - 0.5
    a = a + noise[..., None] * 0.16
    a = a * 0.97 * vignette((h, w), 0.8, 2.6)[..., None]
    base = img(a).convert("RGBA")
    d = ImageDraw.Draw(base)
    rnd = random.Random(5)
    for _ in range(8):  # scratches
        x = rnd.uniform(60, 1220)
        y = 0
        shade = rnd.choice((235, 20))
        while y < 720:
            seg = rnd.uniform(40, 260)
            if rnd.random() < 0.7:
                d.line((x, y, x + rnd.uniform(-2, 2), y + seg), fill=(shade, shade, shade, rnd.randint(50, 130)),
                       width=rnd.choice((1, 1, 2)))
            y += seg + rnd.uniform(0, 80)
            x += rnd.uniform(-3, 3)
    for _ in range(60):  # dust
        x, y, r = rnd.uniform(0, 1280), rnd.uniform(0, 720), rnd.uniform(0.6, 2.6)
        c = rnd.choice((0, 255))
        d.ellipse((x - r, y - r, x + r, y + r * rnd.uniform(0.6, 1.8)), fill=(c, c, c, rnd.randint(90, 200)))
    # The film gate: rounded corners in black.
    mask = Image.new("L", (1280, 720), 0)
    ImageDraw.Draw(mask).rounded_rectangle((14, 12, 1266, 708), 40, fill=255)
    gate = Image.new("RGBA", (1280, 720), (0, 0, 0, 255))
    gate.paste(base, (0, 0), mask.filter(ImageFilter.GaussianBlur(2)))
    base = gate
    lay = layer()
    d = ImageDraw.Draw(lay)
    silver = (226, 232, 244, 255)
    f = font("PoiretOne", 30)
    title = "ROBBIE  No. 7   ·   THE JELLYFISH"
    tw, th = text_size(d, title, f)
    d.text((640 - tw / 2, 30), title, font=f, fill=silver)
    for s in (-1, 1):
        x = 640 + s * (tw / 2 + 24)
        d.line((x, 48, x + s * 120, 48), fill=silver, width=1)
        d.line((x + s * 8, 54, x + s * 90, 54), fill=silver, width=1)
        d.polygon([(x + s * 128, 48), (x + s * 134, 42), (x + s * 140, 48), (x + s * 134, 54)], fill=silver)
    for i, hgt in enumerate((14, 24, 34)):  # energy as stepped deco bars
        d.rectangle((1150 + i * 22, 64 - hgt, 1164 + i * 22, 64), fill=silver if i < 2 else (120, 126, 140, 255))
    # The intertitle card.
    fl = font("Limelight", 32)
    lines = ["I swam towards the pretty lights.", "Classic mistake."]
    widths = [text_size(d, s, fl)[0] for s in lines]
    cw, ch = max(widths) + 120, 132
    box = (640 - cw / 2, 560, 640 + cw / 2, 560 + ch)
    d.rectangle(box, fill=(6, 6, 10, 245))
    deco_frame(d, box, silver)
    for i, (s, sw) in enumerate(zip(lines, widths)):
        d.text((640 - sw / 2, 584 + i * 44), s, font=fl, fill=silver)
    d.text((40, 676), "RULE 1 · Move towards beacon", font=font("PoiretOne", 20), fill=silver)
    base.alpha_composite(lay)
    return base


# --- 3. Dead Air: the sonar on a valve-radio screen ---------------------------------------------------------------

def world_3(im):
    sx0, sy0, sx1, sy1 = 64, 44, 1216, 666
    sw, sh = sx1 - sx0, sy1 - sy0
    content = im.convert("RGB").crop((sx0, sy0 + 6, sx1, sy1 + 6))
    d = ImageDraw.Draw(content)
    osd = (190, 255, 200)
    f = font("VT323", 30)
    d.text((26, 18), "RX 38.2 Mc    ROBBIE 007    THE JELLYFISH", font=f, fill=osd)
    d.text((sw - 260, 18), "SIGNAL", font=f, fill=osd)
    for i in range(6):
        d.rectangle((sw - 168 + i * 22, 26, sw - 154 + i * 22, 44), fill=osd if i < 2 else (40, 80, 50))
    rx, ry = 288 - sx0, 420 - sy0 - 6
    for k, r in enumerate((2, 4, 6, 8)):
        d.text((rx + r * 53.3 + 6, ry - 22), "%d fm" % r, font=font("VT323", 20), fill=(120, 220, 140))
    for i, (x, y) in enumerate(((548, 330), (808, 455), (1015, 238))):
        d.text((x - sx0 + 18, y - sy0 - 30), "C-%d" % (i + 1), font=font("VT323", 22), fill=osd)
    d.text((396 - sx0, 566 - sy0), "?? ECHO", font=font("VT323", 22), fill=(120, 200, 130))
    d.text((1120 - sx0 - 80, 392 - sy0), "BEACON 1.2 kc", font=font("VT323", 22), fill=osd)
    d.text((sw / 2 - 150, 60), "· · ·  CARRIER LOST 00:02.0  · · ·", font=font("VT323", 24), fill=(150, 240, 170))
    d.text((40, sh - 60), "> I SWAM TOWARDS THE PRETTY LIGHTS. CLASSIC MISTAKE._", font=font("VT323", 34), fill=osd)
    a = arr(content)
    L = luminance(a) ** 0.85
    a = np.array([0.01, 0.04, 0.015]) + L[..., None] * np.array([0.42, 1.0, 0.55])
    a = arr(bloom(img(a), 0.4, 6, 0.6))
    h, w = a.shape[:2]
    yy = np.arange(h)[:, None]
    band = (np.sin(yy * 0.045 + 1.3) > 0.93) * 0.22 + (np.sin(yy * 0.013 + 0.2) > 0.97) * 0.3
    static = RNG.normal(0, 1, (h, w)) * (0.09 + band)
    salt = (RNG.random((h, w)) > 0.996) * 0.8
    a = a + (static + salt)[..., None] * np.array([0.55, 1.0, 0.6])
    roll = np.exp(-((yy - h * 0.3) / 26.0) ** 2) * 0.09
    a = a + roll[..., None]
    for y0, y1, shift in ((210, 226, 14), (452, 460, -9), (470, 474, 22)):
        a[y0:y1] = np.roll(a[y0:y1], shift, axis=1)
    a[::3] *= 0.68
    # Curved glass: barrel distortion.
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    nu, nv = (u - w / 2) / (w / 2), (v - h / 2) / (h / 2)
    r2 = nu * nu + nv * nv
    k = 0.07
    su = np.clip(((nu * (1 - k + k * r2)) * (w / 2) + w / 2).astype(int), 0, w - 1)
    sv = np.clip(((nv * (1 - k + k * r2)) * (h / 2) + h / 2).astype(int), 0, h - 1)
    a = a[sv, su] * vignette((h, w), 0.6, 3.0)[..., None]
    screen = img(a).convert("RGBA")
    # The receiver: bakelite, a brass ring, screws, knobs and a maker's plate.
    y, x = np.mgrid[0:720, 0:1280]
    bak = np.array([0.13, 0.075, 0.04]) * (0.75 + 0.25 * (1 - y / 720.0))[..., None]
    bak = bak * (0.92 + 0.08 * grain((720, 1280), 3, 4))[..., None]
    base = img(bak).convert("RGBA")
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, sh - 1), 46, fill=255)
    base.paste(screen, (sx0, sy0), mask.filter(ImageFilter.GaussianBlur(1.5)))
    lay = layer()
    d = ImageDraw.Draw(lay)
    d.rounded_rectangle((sx0 - 9, sy0 - 9, sx1 + 9, sy1 + 9), 54, outline=hexc("#b8862f"), width=6)
    d.rounded_rectangle((sx0 - 3, sy0 - 3, sx1 + 3, sy1 + 3), 48, outline=hexc("#3a2410"), width=3)
    for cx, cy in ((24, 22), (1256, 22), (24, 698), (1256, 698)):
        d.ellipse((cx - 8, cy - 8, cx + 8, cy + 8), fill=hexc("#8a6a3a"))
        d.line((cx - 6, cy - 2, cx + 6, cy + 2), fill=hexc("#3a2810"), width=2)
    for kx, label in ((150, "TUNING"), (1130, "GAIN")):
        d.ellipse((kx - 20, 674, kx + 20, 714), fill=hexc("#1a0e06"), outline=hexc("#b8862f"), width=3)
        d.line((kx, 678, kx + 8, 690), fill=hexc("#d8b070"), width=3)
        d.text((kx + 30, 684), label, font=font("BigShoulders", 18), fill=hexc("#c8a878"))
    plate = "JOVIAN TELEGRAPH Co.  ·  SONAR RECEIVER Mk II"
    pw, _ = text_size(d, plate, font("BigShoulders", 18))
    d.rectangle((640 - pw / 2 - 14, 680, 640 + pw / 2 + 14, 708), fill=hexc("#b8862f"))
    d.text((640 - pw / 2, 682), plate, font=font("BigShoulders", 18), fill=hexc("#2a1a08"))
    base.alpha_composite(lay)
    glare = np.zeros((720, 1280), np.float32)
    glare[sy0:sy1, sx0:sx1] = np.clip(1 - (x[sy0:sy1, sx0:sx1] + y[sy0:sy1, sx0:sx1] * 1.6) / 700.0, 0, 1) * 0.07
    gl = Image.new("RGBA", (1280, 720), (255, 255, 255, 0))
    gl.putalpha(Image.fromarray((glare * 255).astype(np.uint8)))
    base.alpha_composite(gl)
    return base


# --- 4. The Verdigris Reef: painterly gouache, wood and paper tags ----------------------------------------------

def kuwahara(a, r):
    """Kuwahara filter: each pixel takes the mean of its calmest neighbouring quadrant, which reads as brushwork."""
    h, w, _ = a.shape
    p = np.pad(a, ((r, r), (r, r), (0, 0)), mode="reflect")
    L = luminance(p)

    def integral(x):
        pad = ((1, 0), (1, 0)) + ((0, 0),) * (x.ndim - 2)
        return np.pad(x, pad).cumsum(0).cumsum(1)

    I, IL, I2 = integral(p), integral(L), integral(L * L)
    s = r + 1

    def box(S, oy, ox):
        return S[oy + s:oy + s + h, ox + s:ox + s + w] - S[oy:oy + h, ox + s:ox + s + w] \
            - S[oy + s:oy + s + h, ox:ox + w] + S[oy:oy + h, ox:ox + w]

    n = float(s * s)
    best, best_var = None, None
    for oy, ox in ((0, 0), (0, r), (r, 0), (r, r)):
        mean = box(I, oy, ox) / n
        m = box(IL, oy, ox) / n
        var = box(I2, oy, ox) / n - m * m
        if best is None:
            best, best_var = mean, var
        else:
            pick = var < best_var
            best = np.where(pick[..., None], mean, best)
            best_var = np.where(pick, var, best_var)
    return best


def world_4(im):
    a = arr(im)
    a = kuwahara(a, 4)
    a = kuwahara(a, 2)
    h, w = a.shape[:2]
    strokes = np.asarray(Image.fromarray((RNG.random((h, w)) * 255).astype(np.uint8))
                         .filter(ImageFilter.BoxBlur(3)).resize((w // 2, h // 6)).resize((w, h), Image.BICUBIC))
    strokes = strokes / 255.0 - 0.5
    y, x = np.mgrid[0:h, 0:w]
    weave = (np.sin(x * 1.9) * np.sin(y * 1.9)) * 0.5
    L = luminance(a)
    warm, cool = np.array([1.06, 1.0, 0.9]), np.array([0.92, 1.0, 1.08])
    a = a * (cool + (warm - cool) * np.clip(L * 2.2, 0, 1)[..., None])
    a = a * (1 + 0.1 * strokes[..., None] + 0.025 * weave[..., None]) * vignette((h, w), 0.4)[..., None]
    base = img(a).convert("RGBA")
    lay = layer()
    d = ImageDraw.Draw(lay)
    f = font("SpecialElite", 27)
    title = "Robbie 007  ·  The Jellyfish"
    tw, _ = text_size(d, title, f)
    x0, y0, x1, y1 = 22, 18, 22 + tw + 64, 72
    d.polygon([(x0, y0 + 3), (x1, y0), (x1 - 4, y1), (x0 + 3, y1 - 2)], fill=hexc("#6b4423"))
    rnd = random.Random(2)
    for k in range(7):
        yy = y0 + 7 + k * 8 + rnd.uniform(-2, 2)
        d.line((x0 + 6, yy, x1 - 8, yy + rnd.uniform(-2, 2)), fill=hexc("#4a2c14"), width=1)
    for nx in (x0 + 14, x1 - 16):
        d.ellipse((nx - 5, y0 + 21, nx + 5, y0 + 31), fill=hexc("#8a8a8a"))
    d.text((x0 + 32, y0 + 11), title, font=f, fill=hexc("#f0e2c0"))
    d.rounded_rectangle((1012, 18, 1258, 76), 8, fill=hexc("#8a8a80"), outline=hexc("#4a4a40"), width=2)
    for i in range(3):
        cx = 1030 + i * 56
        d.rounded_rectangle((cx, 30, cx + 44, 64), 7, fill=hexc("#b8693a"), outline=hexc("#5a2c14"), width=2)
        d.rectangle((cx + 44, 40, cx + 50, 54), fill=hexc("#5a2c14"))
        if i < 2:
            d.rounded_rectangle((cx + 6, 36, cx + 38, 58), 4, fill=hexc("#9dff7a"))
    composite(base, lay, shadow=((3, 5), 4, 150))
    t = layer()
    d = ImageDraw.Draw(t)
    fw = font("SpecialElite", 25)
    mw, mh = text_size(d, WORDS, fw)
    tx0, ty0 = 640 - mw / 2 - 70, 104
    tx1, ty1 = 640 + mw / 2 + 40, 176
    d.polygon([(tx0 + 34, ty0), (tx1, ty0), (tx1, ty1), (tx0 + 34, ty1), (tx0, ty1 - 22), (tx0, ty0 + 22)],
              fill=hexc("#e8d8b0"))
    d.ellipse((tx0 + 12, ty0 + 26, tx0 + 32, ty0 + 46), fill=hexc("#b8862f"))
    d.ellipse((tx0 + 17, ty0 + 31, tx0 + 27, ty0 + 41), fill=(0, 0, 0, 0))
    d.line([(tx0 + 22, ty0 + 36), (tx0 + 6, ty0 - 40), (tx0 + 30, ty0 - 110)], fill=hexc("#c0a070"), width=3)
    d.text((tx0 + 56, ty0 + 20), WORDS, font=fw, fill=hexc("#3a2414"))
    t = t.rotate(-1.2, resample=Image.BICUBIC, center=(640, 140))
    composite(base, t, shadow=((4, 7), 5, 150))
    sl = layer()
    d = ImageDraw.Draw(sl)
    d.rounded_rectangle((22, 676, 346, 710), 6, fill=hexc("#2a2e2c"), outline=hexc("#6b4423"), width=3)
    d.text((36, 678), "Rule 1: move towards beacon", font=font("PatrickHand", 24), fill=hexc("#e8e8e0"))
    composite(base, sl, shadow=((2, 3), 3, 120))
    return base


# --- 5. The Red Spot Mine: three-ink woodcut, Company banners ---------------------------------------------------

def shift(x, dx, dy):
    return np.roll(np.roll(x, dy, axis=0), dx, axis=1)


def world_5(im):
    a = arr(im)
    h, w = a.shape[:2]
    L = luminance(a)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    wob = grain((h, w), 70, 9) * 2.2
    t = math.radians(28)
    u = (x * math.cos(t) + y * math.sin(t)) / 6.5 + wob
    s = np.abs((u % 1.0) - 0.5) * 2
    dark = np.clip(1.08 - L * 2.4, 0, 1)
    key = (s < dark).astype(np.float32)
    t2 = math.radians(-18)
    v = (x * math.cos(t2) + y * math.sin(t2)) / 13.0 + grain((h, w), 40, 11) * 1.5
    carve = (np.abs((v % 1.0) - 0.5) * 2 > 0.9) & (dark > 0.92)
    key[carve] = 0.0
    redness = np.clip((a[..., 0] - 0.55 * (a[..., 1] + a[..., 2])) * 3.0, 0, 1)
    gold = np.clip((L - 0.5) * 3.0, 0, 1) * np.clip((a[..., 0] - a[..., 2]) * 2 + 0.4, 0, 1)
    ink_noise = lambda seed: 0.75 + 0.25 * grain((h, w), 2, seed)  # noqa: E731
    cov_r = np.clip(redness * 1.3 + 0.18 * (1 - np.abs(L - 0.3) * 3).clip(0, 1), 0, 1) * ink_noise(21)
    cov_g = np.clip(gold * 1.4, 0, 1) * ink_noise(22)
    paper = np.array([0.94, 0.9, 0.81]) * (0.94 + 0.06 * grain((h, w), 3, 23))[..., None]
    out = paper.copy()
    crimson, gld, black = np.array([0.78, 0.07, 0.17]), np.array([0.95, 0.70, 0.11]), np.array([0.07, 0.06, 0.09])
    cr = shift(cov_r, 3, -2)[..., None]
    gd = shift(cov_g, -2, 2)[..., None]
    out = out * (1 - cr + cr * crimson)
    out = out * (1 - gd + gd * gld)
    key = key * ink_noise(24)
    out = out * (1 - key[..., None]) + black * key[..., None]
    base = img(out).convert("RGBA")
    # The Company's banners, printed in the same inks (crimson slightly off register).
    for dx, dy, which in ((3, -2, "crimson"), (0, 0, "key")):
        lay = layer()
        d = ImageDraw.Draw(lay)
        cri, blk, gol, pap = hexc("#c8102e"), hexc("#141018"), hexc("#f2b21c"), hexc("#efe4cc")
        title = "ROBBIE 007  ·  THE JELLYFISH"
        f = font("BigShoulders", 36)
        tw, _ = text_size(d, title, f)
        poly = [(20 + dx, 18 + dy), (tw + 90 + dx, 14 + dy), (tw + 70 + dx, 74 + dy), (28 + dx, 78 + dy)]
        if which == "crimson":
            d.polygon(poly, fill=cri)
            for k in range(9):
                ang = math.radians(200 + k * 17)
                d.polygon([(1150 + dx, 56 + dy), (1150 + math.cos(ang) * 140 + dx, 56 + math.sin(ang) * 140 + dy),
                           (1150 + math.cos(ang + 0.08) * 140 + dx, 56 + math.sin(ang + 0.08) * 140 + dy)],
                          fill=(200, 16, 46, 110))
        else:
            d.line(poly + [poly[0]], fill=blk, width=4)
            d.text((50, 22), title, font=f, fill=gol, stroke_width=2, stroke_fill=blk)
            note = "THE COMPANY THANKS ROBBIE 007 FOR ITS SERVICE"
            nw, _ = text_size(d, note, font("BigShoulders", 18))
            d.rectangle((30, 82, 54 + nw, 106), fill=pap, outline=blk, width=2)
            d.text((42, 83), note, font=font("BigShoulders", 18), fill=blk)
            for i in range(3):
                cx = 1110 + i * 44
                d.polygon([(cx, 34), (cx + 16, 56), (cx, 78), (cx - 16, 56)], fill=cri if i < 2 else pap,
                          outline=blk, width=3)
            fw = font("BigShoulders", 34)
            msg = WORDS.upper()
            mw, _ = text_size(d, msg, fw)
            box = (640 - mw / 2 - 40, 604, 640 + mw / 2 + 40, 668)
            d.rectangle(box, fill=blk)
            d.rectangle((box[0] + 6, box[1] + 6, box[2] - 6, box[3] - 6), outline=gol, width=2)
            d.text((640 - mw / 2, 610), msg, font=fw, fill=pap)
            d.text((28, 684), "RULE 1  >  MOVE TOWARDS BEACON", font=font("BigShoulders", 22), fill=pap,
                   stroke_width=2, stroke_fill=blk)
        base.alpha_composite(lay)
    return base


SLUGS = {n: NAMES[n].lower().replace("the ", "").replace(" ", "-") for n in NAMES}


def contact_sheet(paths, out):
    tw, th = 624, 351
    sheet = Image.new("RGB", (3 * tw + 4 * 24, 2 * (th + 54) + 70), (12, 12, 16))
    d = ImageDraw.Draw(sheet)
    d.text((24, 18), "Robbie N+1 — five worlds for a steampunk colony under the ice", font=font("ChakraPetch", 30),
           fill=(240, 240, 240))
    for i, (n, p) in enumerate(paths):
        im = Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS)
        col, row = (i, 0) if i < 3 else (i - 3 + 0.5, 1)
        x, y = int(24 + col * (tw + 24)), 70 + row * (th + 54)
        sheet.paste(im, (x, y))
        d.text((x, y + th + 8), "%d · %s" % (n, NAMES[n]), font=font("ChakraPetch", 26), fill=(255, 255, 255))
    sheet.save(out)


def main():
    raw_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    done = []
    for n in sorted(NAMES):
        src = os.path.join(raw_dir, "world_%d.png" % n)
        if not os.path.exists(src):
            print("missing", src)
            continue
        out = globals()["world_%d" % n](Image.open(src).convert("RGB"))
        tag(out, n)
        path = os.path.join(out_dir, "world-%d-%s.png" % (n, SLUGS[n]))
        out.convert("RGB").save(path, optimize=True)
        done.append((n, path))
        print("wrote", path)
    if len(done) == 5:
        contact_sheet(done, os.path.join(out_dir, "worlds.png"))
        print("wrote", os.path.join(out_dir, "worlds.png"))


if __name__ == "__main__":
    main()
