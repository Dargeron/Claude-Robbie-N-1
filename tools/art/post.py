#!/usr/bin/env python3
"""Finish the style concepts: each style's surface treatment (paper, ink hatching, bloom, tilt-shift, halftone) and
a mock of the game's dive screen drawn in that style's UI language, then a contact sheet of all five.

Usage: python3 tools/art/post.py <raw_dir> <out_dir>
  reads <raw_dir>/final_<n>.png, writes <out_dir>/style-<n>-<slug>.png and <out_dir>/styles.png
Fonts (all SIL Open Font License, from Google Fonts) are fetched once into ~/.cache/robbie/fonts.
"""
import math
import os
import random
import re
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

FONT_DIR = os.path.expanduser("~/.cache/robbie/fonts")
FONTS = {"Cinzel": "Cinzel:wght@700", "Alegreya": "Alegreya:ital,wght@1,500", "ChakraPetch": "Chakra+Petch:wght@600",
         "ShareTechMono": "Share+Tech+Mono", "Fredoka": "Fredoka:wght@600", "PatrickHand": "Patrick+Hand",
         "Bangers": "Bangers", "ComicNeue": "Comic+Neue:wght@700"}
NAMES = {1: "Brass & Ink", 2: "Glow Abyss", 3: "Toy Aquarium", 4: "Paper Cut", 5: "Jovian Comic"}
ROBBIE_PX = (262, 392)  # where the stand-in Robbie sits in the frame

TITLE = "ROBBIE 007  ·  THE JELLYFISH"
WORDS = "I swam towards the pretty lights. Classic mistake."
RULE = "RULE 1  ›  Move towards beacon"
CLOCK = "T+00:02.0"


def font(name, size):
    path = os.path.join(FONT_DIR, name + ".ttf")
    if not os.path.exists(path):
        os.makedirs(FONT_DIR, exist_ok=True)
        req = urllib.request.Request("https://fonts.googleapis.com/css2?family=" + FONTS[name],
                                     headers={"User-Agent": "Mozilla/4.0"})
        css = urllib.request.urlopen(req, timeout=30).read().decode()
        url = re.search(r"https://fonts\.gstatic\.com/[^)]+\.ttf", css).group(0)
        urllib.request.urlretrieve(url, path)
    return ImageFont.truetype(path, size)


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def arr(im):
    return np.asarray(im.convert("RGB")).astype(np.float32) / 255.0


def img(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


def luminance(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def grain(shape, scale, seed):
    """Smooth value noise in 0..1 (paper fibres, mottling)."""
    rng = np.random.default_rng(seed)
    h, w = shape
    small = rng.random((max(2, h // scale), max(2, w // scale))).astype(np.float32)
    return np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)) / 255.0


def vignette(shape, strength, power=2.2):
    h, w = shape
    y, x = np.mgrid[0:h, 0:w]
    d = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2) / math.sqrt(2)
    return 1.0 - strength * d ** power


def bloom(im, threshold, radius, amount):
    a = arr(im)
    bright = np.clip((luminance(a) - threshold) / (1 - threshold), 0, 1)[..., None] * a
    halo = arr(img(bright).filter(ImageFilter.GaussianBlur(radius)))
    halo2 = arr(img(bright).filter(ImageFilter.GaussianBlur(radius * 3)))
    return img(1 - (1 - a) * (1 - amount * (halo + 0.6 * halo2)))


def text_size(draw, s, f):
    x0, y0, x1, y1 = draw.textbbox((0, 0), s, font=f)
    return x1 - x0, y1 - y0


def shadowed(base, draw_fn, offset=(3, 4), blur=4, alpha=110):
    """Draw a layer twice: a blurred dark copy as a drop shadow, then the layer itself."""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sh.paste((0, 0, 0, alpha), offset, layer.split()[3])
    base.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))
    base.alpha_composite(layer)


def tag(base, n):
    """A small neutral label so the concept is easy to refer to."""
    d = ImageDraw.Draw(base)
    f = font("ChakraPetch", 17)
    s = "STYLE %d  ·  %s" % (n, NAMES[n].upper())
    w, h = text_size(d, s, f)
    d.rounded_rectangle((1280 - w - 30, 720 - h - 26, 1268, 708), 8, fill=(0, 0, 0, 150))
    d.text((1280 - w - 20, 720 - h - 21), s, font=f, fill=(255, 255, 255, 230))


# --- 1. Brass & Ink -------------------------------------------------------------------------------------------------

def brass_plate(d, box, radius=10):
    x0, y0, x1, y1 = box
    d.rounded_rectangle(box, radius, fill=hexc("#7a4f1e"))
    d.rounded_rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 3), radius - 2, fill=hexc("#c8913f"))
    d.rounded_rectangle((x0 + 6, y0 + 6, x1 - 6, y1 - 6), radius - 4, fill=hexc("#b07a30"))
    d.line((x0 + 10, y0 + 7, x1 - 10, y0 + 7), fill=hexc("#f0c97a"), width=2)
    for cx, cy in ((x0 + 13, y0 + 13), (x1 - 13, y0 + 13), (x0 + 13, y1 - 13), (x1 - 13, y1 - 13)):
        d.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=hexc("#6a4318"))
        d.ellipse((cx - 3, cy - 4, cx + 2, cy + 1), fill=hexc("#f6d38c"))


def style_1(im):
    a = arr(im)
    h, w = a.shape[:2]
    L = luminance(a)
    # Ink hatching in the shadows, like a storybook engraving.
    y, x = np.mgrid[0:h, 0:w]
    hatch = ((x + y) % 7 < 1.2).astype(np.float32)
    cross = ((x - y) % 9 < 1.0).astype(np.float32)
    dark = np.clip((0.16 - L) / 0.16, 0, 1)
    ink = np.maximum(hatch * np.clip(dark * 1.6, 0, 1), cross * np.clip(dark * 2.5 - 1.2, 0, 1)) * 0.55
    a = a * (1 - ink[..., None]) + np.array([0.04, 0.07, 0.08]) * ink[..., None]
    # Paper: warm tint, fibres and a soft vignette.
    paper = 0.92 + 0.08 * grain((h, w), 3, 1) * grain((h, w), 41, 2)
    a = a * paper[..., None] * np.array([1.04, 1.0, 0.92]) * vignette((h, w), 0.35)[..., None]
    base = img(a).convert("RGBA")

    def hud(d):
        f = font("Cinzel", 25)
        tw, _ = text_size(d, TITLE, f)
        brass_plate(d, (24, 18, 24 + tw + 56, 74))
        d.text((52, 30), TITLE, font=f, fill=hexc("#3a220c"))
        # Energy: a brass gauge with three glowing cells.
        brass_plate(d, (1010, 18, 1256, 74))
        for i in range(3):
            c = hexc("#ffd36a") if i < 2 else hexc("#4a2f12")
            d.rounded_rectangle((1034 + i * 34, 34, 1060 + i * 34, 58), 5, fill=c, outline=hexc("#5a3812"), width=2)
        d.text((1142, 33), CLOCK, font=font("Cinzel", 20), fill=hexc("#3a220c"))
        # Last words on a parchment ribbon.
        fw = font("Alegreya", 30)
        ww, wh = text_size(d, WORDS, fw)
        cx, y0 = 640, 618
        d.polygon([(cx - ww / 2 - 70, y0 + 6), (cx - ww / 2 - 36, y0 + 30), (cx - ww / 2 - 70, y0 + 54),
                   (cx - ww / 2 - 20, y0 + 54), (cx - ww / 2 - 20, y0 + 6)], fill=hexc("#cdb88a"))
        d.polygon([(cx + ww / 2 + 70, y0 + 6), (cx + ww / 2 + 36, y0 + 30), (cx + ww / 2 + 70, y0 + 54),
                   (cx + ww / 2 + 20, y0 + 54), (cx + ww / 2 + 20, y0 + 6)], fill=hexc("#cdb88a"))
        d.rounded_rectangle((cx - ww / 2 - 34, y0, cx + ww / 2 + 34, y0 + 60), 6, fill=hexc("#f1e3bf"),
                            outline=hexc("#8a6a3a"), width=2)
        d.text((cx - ww / 2, y0 + 10), WORDS, font=fw, fill=hexc("#3a2614"))
        fr = font("Cinzel", 17)
        d.text((30, 690), RULE, font=fr, fill=hexc("#f0d9a0"))

    shadowed(base, hud)
    return base


# --- 2. Glow Abyss --------------------------------------------------------------------------------------------------

def style_2(im):
    base = bloom(im, 0.45, 10, 0.75)
    a = arr(base)
    h, w = a.shape[:2]
    a = a * vignette((h, w), 0.55)[..., None]
    # Faint scanlines: this is a transmission.
    a = a * (1 - 0.06 * ((np.arange(h) % 3) == 0))[:, None, None]
    base = img(a).convert("RGBA")
    glow_layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(glow_layer)
    cyan = hexc("#3ff0ff")
    f = font("ChakraPetch", 24)
    d.line((24, 62, 470, 62), fill=cyan, width=2)
    d.line((24, 62, 24, 30), fill=cyan, width=2)
    d.text((40, 26), TITLE.replace("·", "//"), font=f, fill=cyan)
    for i in range(12):  # segmented energy bar
        c = cyan if i < 8 else hexc("#3ff0ff", 60)
        d.rectangle((1030 + i * 18, 34, 1043 + i * 18, 54), fill=c)
    d.text((1030, 62), "ENERGY  " + CLOCK, font=font("ShareTechMono", 16), fill=hexc("#9ff8ff"))
    fw = font("ShareTechMono", 28)
    s = "> " + WORDS + "_"
    ww, wh = text_size(d, s, fw)
    x0 = 640 - ww / 2
    d.line((x0 - 24, 612, x0 - 24, 668), fill=cyan, width=2)
    d.line((x0 - 24, 612, x0 - 4, 612), fill=cyan, width=2)
    d.line((x0 - 24, 668, x0 - 4, 668), fill=cyan, width=2)
    d.line((x0 + ww + 24, 612, x0 + ww + 24, 668), fill=cyan, width=2)
    d.line((x0 + ww + 4, 612, x0 + ww + 24, 612), fill=cyan, width=2)
    d.line((x0 + ww + 4, 668, x0 + ww + 24, 668), fill=cyan, width=2)
    d.text((x0, 624), s, font=fw, fill=hexc("#e8fdff"))
    d.text((28, 690), RULE.replace("›", ">"), font=font("ShareTechMono", 18), fill=hexc("#a6ff4f"))
    halo = glow_layer.filter(ImageFilter.GaussianBlur(6))
    base.alpha_composite(halo)
    base.alpha_composite(halo)
    base.alpha_composite(glow_layer)
    return base


# --- 3. Toy Aquarium ------------------------------------------------------------------------------------------------

def pill(d, box, fill, outline, r=None):
    x0, y0, x1, y1 = box
    r = r or (y1 - y0) // 2
    d.rounded_rectangle((x0, y0 + 4, x1, y1 + 4), r, fill=hexc(outline))
    d.rounded_rectangle(box, r, fill=hexc(fill), outline=hexc(outline), width=3)


def style_3(im):
    # Tilt-shift: the top and bottom of the frame fall out of focus, like a photo of a model.
    sharp = im.convert("RGB")
    blurred = sharp.filter(ImageFilter.GaussianBlur(5))
    h = sharp.size[1]
    yy = np.linspace(-1, 1, h)
    m = np.clip((np.abs(yy) - 0.35) / 0.45, 0, 1) ** 1.5
    mask = Image.fromarray((np.repeat(m[:, None], sharp.size[0], 1) * 255).astype(np.uint8))
    out = Image.composite(blurred, sharp, mask)
    out = ImageEnhance.Color(out).enhance(1.15)
    a = arr(out) * vignette((h, sharp.size[0]), 0.18)[..., None] + np.array([0.02, 0.015, 0.0])
    base = img(a).convert("RGBA")

    def hud(d):
        f = font("Fredoka", 27)
        tw, _ = text_size(d, TITLE, f)
        pill(d, (22, 18, 22 + tw + 48, 70), "#ffffff", "#7a68b8")
        d.text((46, 27), TITLE, font=f, fill=hexc("#5a4a9a"))
        pill(d, (1010, 18, 1258, 70), "#ffffff", "#ff8a8a")
        for i in range(3):
            c = "#ff6b6b" if i < 2 else "#ffd9d9"
            d.ellipse((1032 + i * 36, 30, 1060 + i * 36, 58), fill=hexc(c), outline=hexc("#d94a4a"), width=2)
        d.text((1146, 29), CLOCK, font=font("Fredoka", 22), fill=hexc("#d94a4a"))
        fw = font("Fredoka", 29)
        ww, wh = text_size(d, WORDS, fw)
        cx = 640
        box = (cx - ww / 2 - 32, 606, cx + ww / 2 + 32, 670)
        d.rounded_rectangle((box[0], box[1] + 5, box[2], box[3] + 5), 28, fill=hexc("#7a68b8"))
        d.rounded_rectangle(box, 28, fill=hexc("#ffffff"), outline=hexc("#7a68b8"), width=3)
        d.polygon([(box[0] + 60, box[1] + 2), (box[0] + 40, box[1] - 26), (box[0] + 96, box[1] + 2)],
                  fill=hexc("#ffffff"))
        d.line([(box[0] + 60, box[1] + 1), (box[0] + 40, box[1] - 26), (box[0] + 96, box[1] + 1)],
               fill=hexc("#7a68b8"), width=3)
        d.text((cx - ww / 2, 619), WORDS, font=fw, fill=hexc("#4a3a7a"))
        pill(d, (22, 684, 330, 712), "#ffd23f", "#c99a1a", r=14)
        d.text((40, 686), RULE, font=font("Fredoka", 19), fill=hexc("#6a4a0a"))

    shadowed(base, hud, offset=(0, 3), blur=3, alpha=60)
    return base


# --- 4. Paper Cut ---------------------------------------------------------------------------------------------------

def torn(d, box, fill, seed, angle_jitter=2.0):
    """A strip of paper with ragged edges."""
    rng = random.Random(seed)
    x0, y0, x1, y1 = box
    top = [(x, y0 + rng.uniform(-2.5, 2.5)) for x in np.arange(x0, x1 + 1, 7)]
    bottom = [(x, y1 + rng.uniform(-2.5, 2.5)) for x in np.arange(x1, x0 - 1, -7)]
    left = [(x0 + rng.uniform(-3, 3), y) for y in np.arange(y1, y0, -6)]
    right = [(x1 + rng.uniform(-3, 3), y) for y in np.arange(y0, y1, 6)]
    d.polygon(top + right + bottom + left, fill=hexc(fill))


def style_4(im):
    a = arr(im)
    h, w = a.shape[:2]
    fibres = grain((h, w), 2, 5) * 0.5 + grain((h, w), 9, 6) * 0.5
    a = a * (0.9 + 0.14 * fibres)[..., None] * vignette((h, w), 0.3)[..., None]
    base = img(a).convert("RGBA")

    def hud(d):
        f = font("PatrickHand", 32)
        tw, _ = text_size(d, TITLE, f)
        torn(d, (24, 18, 24 + tw + 44, 70), "#f5ead8", 1)
        d.text((46, 22), TITLE, font=f, fill=hexc("#2b2960"))
        torn(d, (1014, 18, 1258, 70), "#f5ead8", 2)
        for i in range(3):
            c = "#ff8a5c" if i < 2 else "#d9cbb5"
            d.regular_polygon(((1046 + i * 36, 44), 14), 6, rotation=30 + i * 7, fill=hexc(c))
        d.text((1150, 26), CLOCK, font=font("PatrickHand", 26), fill=hexc("#2b2960"))
        fw = font("PatrickHand", 36)
        ww, wh = text_size(d, WORDS, fw)
        torn(d, (640 - ww / 2 - 30, 606, 640 + ww / 2 + 30, 668), "#fff6e6", 3)
        d.text((640 - ww / 2, 612), WORDS, font=fw, fill=hexc("#3a2a5e"))
        torn(d, (24, 680, 330, 712), "#ffd25c", 4)
        d.text((40, 680), RULE, font=font("PatrickHand", 24), fill=hexc("#3a2a10"))

    shadowed(base, hud, offset=(4, 6), blur=3, alpha=120)
    return base


# --- 5. Jovian Comic ------------------------------------------------------------------------------------------------

def style_5(im):
    a = arr(ImageEnhance.Color(im.convert("RGB")).enhance(1.2))
    h, w = a.shape[:2]
    # Halftone: dots in the darker half, bigger where it is darker, on a 45-degree grid.
    L = luminance(a)
    cell = 7.0
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = (x + y) / math.sqrt(2), (x - y) / math.sqrt(2)
    du, dv = (u % cell) - cell / 2, (v % cell) - cell / 2
    dist = np.sqrt(du * du + dv * dv)
    radius = np.clip((0.42 - L) / 0.42, 0, 1) * cell * 0.5
    dots = (dist < radius).astype(np.float32) * 0.45
    a = a * (1 - dots[..., None]) + np.array([0.02, 0.06, 0.08]) * dots[..., None]
    base = img(a).convert("RGBA")
    d = ImageDraw.Draw(base)
    # Panel border.
    d.rectangle((0, 0, w - 1, h - 1), outline=(10, 15, 20, 255), width=10)
    d.rectangle((10, 10, w - 11, h - 11), outline=(255, 255, 255, 255), width=3)
    # Caption box.
    f = font("Bangers", 34)
    title = TITLE.replace("·", "—") + "!"
    tw, _ = text_size(d, title, f)
    d.polygon([(22, 22), (52 + tw, 18), (58 + tw, 70), (26, 74)], fill=hexc("#ffd23f"), outline=hexc("#0a0f14"))
    d.line([(22, 22), (52 + tw, 18), (58 + tw, 70), (26, 74), (22, 22)], fill=hexc("#0a0f14"), width=4)
    d.text((38, 24), title, font=f, fill=hexc("#0a0f14"))
    # Energy as chunky bolts.
    for i in range(3):
        c = "#ff6a2a" if i < 2 else "#5a6a70"
        cx = 1056 + i * 46
        d.polygon([(cx, 22), (cx - 14, 50), (cx - 2, 50), (cx - 8, 74), (cx + 14, 40), (cx + 2, 40), (cx + 8, 22)],
                  fill=hexc(c), outline=hexc("#0a0f14"))
    d.text((1188, 34), CLOCK, font=font("Bangers", 24), fill=hexc("#ffffff"), stroke_width=3,
           stroke_fill=hexc("#0a0f14"))
    # Speech bubble from Robbie.
    fw = font("ComicNeue", 27)
    ww, wh = text_size(d, WORDS.upper(), fw)
    bx0, by0 = 340, 560
    box = (bx0, by0, bx0 + ww + 48, by0 + 70)
    rx, ry = ROBBIE_PX
    d.polygon([(bx0 + 40, by0 + 8), (rx + 30, ry + 40), (bx0 + 90, by0 + 8)], fill=hexc("#ffffff"),
              outline=hexc("#0a0f14"))
    d.ellipse((box[0] - 14, box[1] - 10, box[2] + 14, box[3] + 10), fill=hexc("#ffffff"), outline=hexc("#0a0f14"),
              width=4)
    d.polygon([(bx0 + 44, by0 + 2), (rx + 30, ry + 40), (bx0 + 86, by0 + 2)], fill=hexc("#ffffff"))
    d.line([(bx0 + 40, by0 + 4), (rx + 30, ry + 40), (bx0 + 90, by0 + 4)], fill=hexc("#0a0f14"), width=4)
    d.text((bx0 + 24, by0 + 20), WORDS.upper(), font=fw, fill=hexc("#0a0f14"))
    d.text((30, 678), RULE.upper(), font=font("Bangers", 24), fill=hexc("#7dff6a"), stroke_width=3,
           stroke_fill=hexc("#0a0f14"))
    return base


SLUGS = {n: NAMES[n].lower().replace(" & ", "-").replace(" ", "-") for n in NAMES}


def contact_sheet(paths, out):
    tw, th = 624, 351
    sheet = Image.new("RGB", (3 * tw + 4 * 24, 2 * (th + 54) + 70), hexc("#14161c")[:3])
    d = ImageDraw.Draw(sheet)
    d.text((24, 18), "Robbie N+1 — five art styles (same dive, same stand-in Robbie)", font=font("ChakraPetch", 30),
           fill=(240, 240, 240))
    for i, (n, p) in enumerate(paths):
        im = Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS)
        col, row = (i, 0) if i < 3 else (i - 3 + 0.5, 1)
        x = int(24 + col * (tw + 24))
        y = 70 + row * (th + 54)
        sheet.paste(im, (x, y))
        d.text((x, y + th + 8), "%d · %s" % (n, NAMES[n]), font=font("ChakraPetch", 26), fill=(255, 255, 255))
    sheet.save(out)


def main():
    raw_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    done = []
    for n in sorted(NAMES):
        src = os.path.join(raw_dir, "final_%d.png" % n)
        if not os.path.exists(src):
            print("missing", src)
            continue
        im = Image.open(src).convert("RGB")
        out = globals()["style_%d" % n](im)
        tag(out, n)
        path = os.path.join(out_dir, "style-%d-%s.png" % (n, SLUGS[n]))
        out.convert("RGB").save(path, optimize=True)
        done.append((n, path))
        print("wrote", path)
    if len(done) == 5:
        contact_sheet(done, os.path.join(out_dir, "styles.png"))
        print("wrote", os.path.join(out_dir, "styles.png"))


if __name__ == "__main__":
    main()
