"""Art-direction mock-up C: the console inked like a graphic novel (Mignola's blacks, engraved hatching).

Flattens a game frame into a few tones per colour, turns the deep shadows into solid black, cross-hatches the
half-dark, draws ink outlines where the forms change, and keeps what glows (the scope, the lamps, the nixies)
as the only light, on toothy paper.
  python3 tools/art/ink.py <frame.png> <out.png>
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mood_post import kuwahara  # noqa: E402

src = Image.open(sys.argv[1]).convert("RGB").resize((2560, 1440), Image.LANCZOS)
a = np.asarray(src, np.float32) / 255.0
H, W = a.shape[:2]
flat = kuwahara(a, 5)
flat = kuwahara(flat, 3)
lum = flat @ np.array([0.299, 0.587, 0.114], np.float32)
mx = flat.max(axis=2)
mn = flat.min(axis=2)
sat = (mx - mn) / np.maximum(mx, 1e-4)
ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)

# Flat colour: each pixel's hue at one of three values.
hue_col = flat / np.maximum(mx[..., None], 1e-4)
levels = np.select([lum < 0.10, lum < 0.22, lum < 0.42], [0.0, 0.30, 0.58], 0.86)
paint = hue_col * levels[..., None]
paint = paint * (0.55 + 0.45 * np.clip(sat, 0, 1))[..., None] + levels[..., None] * (0.45 - 0.45 * np.clip(sat, 0, 1))[..., None] * 0.9
ink = np.array([0.03, 0.028, 0.03], np.float32)
out = paint.copy()
# Solid blacks.
out[lum < 0.10] = ink
# Hatching in the half-dark: diagonal lines, crossed where it is darker.
h1 = ((xs + ys) % 9.0) < 2.2
h2 = ((xs - ys) % 9.0) < 2.2
dark = (lum >= 0.10) & (lum < 0.22)
mid = (lum >= 0.22) & (lum < 0.30)
out[dark & (h1 | h2)] = ink
out[mid & h1] = ink * 1.5
# Ink outlines where the forms change.
g = np.asarray(Image.fromarray((lum * 255).astype(np.uint8)).filter(ImageFilter.FIND_EDGES), np.float32) / 255.0
edges = np.asarray(Image.fromarray(((g > 0.08) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3)), np.float32) / 255.0
out = out * (1 - edges[..., None]) + ink * edges[..., None]
# What glows stays glowing: the brightest, most saturated light keeps its colour.
glow = np.clip((np.asarray(src, np.float32).max(axis=2) / 255.0 - 0.55) * 3.0, 0, 1) * np.clip(sat * 2.0, 0, 1)
gl = np.asarray(Image.fromarray((glow * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(10)), np.float32) / 255.0
out = out * (1 - glow[..., None]) + a * 1.15 * glow[..., None]
out = out + a * 0.6 * gl[..., None]
# Paper and cards stay legible: posterised rather than flattened, with the same ink lines.
lum0 = a @ np.array([0.299, 0.587, 0.114], np.float32)
paperish = np.asarray(Image.fromarray(((lum0 > 0.5) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
                      .filter(ImageFilter.GaussianBlur(2)), np.float32)[..., None] / 255.0
post = np.round(a * 4.0) / 4.0
post = np.where(lum0[..., None] < 0.3, ink, post)
out = out * (1 - paperish) + post * paperish
# The scope is light, not ink: its picture goes in untouched.
sx, sy, sw, sh = [v * 2 for v in (28, 36, 596, 335)]
out[sy:sy + sh, sx:sx + sw] = a[sy:sy + sh, sx:sx + sw] * 1.1
# Paper tooth.
rng = np.random.default_rng(7)
tooth = np.asarray(Image.fromarray((rng.random((H // 2, W // 2)) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
                   .filter(ImageFilter.GaussianBlur(0.8)), np.float32) / 255.0
out = out * (0.93 + 0.1 * tooth[..., None])
Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).resize((1920, 1080), Image.LANCZOS).save(sys.argv[2])
print("inked:", sys.argv[2])
