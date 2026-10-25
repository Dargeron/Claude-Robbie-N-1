"""Weather a rendered desk plate (art-direction variant B): years of use painted in where they would be.

Knows the console's layout, so the wear goes where it belongs: rust streaks bleed down from rivets and the pipe run,
paint chips off the corners of every housing, dirt settles along the bottom of each panel, grease darkens the
recesses, and the metal round the controls is rubbed bright by hands.
  python3 tools/art/weather.py <plate.png> <out.png>
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
L = json.load(open(os.path.join(ROOT, "game/content/console_layout.json")))
rng = np.random.default_rng(1961)
im = np.asarray(Image.open(sys.argv[1]).convert("RGB"), np.float32) / 255.0
H, W = im.shape[:2]
S = W / 1280.0


def noise(scale, octaves=4):
    out = np.zeros((H, W), np.float32)
    amp = 1.0
    for o in range(octaves):
        k = max(2, int(W / (scale * (2 ** o))))
        small = rng.random((int(k * H / W) + 2, k + 2)).astype(np.float32)
        big = np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), np.float32) / 255.0
        out += big * amp
        amp *= 0.5
    return out / (2 - amp * 2)


def blur(a, r):
    return np.asarray(Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r * S)),
                      np.float32) / 255.0


grain = noise(6, 3)
blotch = noise(120, 4)
rust_col = np.array([0.36, 0.17, 0.07], np.float32)
dirt_col = np.array([0.05, 0.04, 0.03], np.float32)
primer = np.array([0.42, 0.18, 0.10], np.float32)

rects = {k: v for k, v in L.items() if isinstance(v, list) and len(v) == 4 and all(isinstance(x, (int, float)) for x in v)}
housings = ["scope", "recorder", "teleprinter", "tube", "sector", "shift", "porthole", "hangar", "rack", "chute", "counter",
            "trials", "dispatch", "press"]
ys, xs = np.mgrid[0:H, 0:W].astype(np.float32)

dirt = np.zeros((H, W), np.float32)
chips = np.zeros((H, W), np.float32)
rust = np.zeros((H, W), np.float32)
rub = np.zeros((H, W), np.float32)
for name in housings:
    x, y, w, h = [v * S for v in rects[name]]
    inside = (xs >= x) & (xs < x + w) & (ys >= y) & (ys < y + h)
    # Dirt settles towards the bottom of each panel and into its lower corners.
    t = np.clip((ys - y) / max(h, 1), 0, 1)
    dirt += inside * (t ** 3) * (0.55 + 0.45 * blotch)
    # Paint chips off near the edges, more at the corners.
    edge = np.minimum.reduce([xs - x, x + w - xs, ys - y, y + h - ys]) / S
    corner = np.minimum(np.hypot(np.minimum(xs - x, x + w - xs), np.minimum(ys - y, y + h - ys)) / S, 60)
    chip = inside * np.clip(1 - edge / 10.0, 0, 1) * (grain > 0.52) + inside * np.clip(1 - corner / 40.0, 0, 1) * (grain > 0.45)
    chips += chip
    # Rust weeping down from rivets along the top edge of each panel.
    for rx in np.arange(x + 7 * S, x + w - 7 * S, 46 * S):
        if rng.random() < 0.45:
            length = rng.uniform(15, 170) * S
            wdt = rng.uniform(1.5, 5.5) * S
            sx = rx + rng.uniform(-3, 3) * S
            streak = np.exp(-((xs - sx) ** 2) / (2 * wdt ** 2)) * np.clip(1 - (ys - (y + 7 * S)) / length, 0, 1) ** rng.uniform(0.6, 2.0) * (ys > y + 6 * S)
            rust += streak * inside * rng.uniform(0.25, 1.0)
# Under the pipe run and the upright pipe: water stains.
for (px, py, ln) in ((1004, 136, 120), (760, 136, 70), (900, 136, 160), (645, 320, 200), (690, 40, 60)):
    rust += np.exp(-((xs - px * S) ** 2) / (2 * (6 * S) ** 2)) * np.clip(1 - (ys - py * S) / (ln * S), 0, 1) * (ys > py * S) * 0.9
# Hands: the metal round what gets touched is rubbed bright and greasy.
for key, rad in (("order_wheel", None), ("cond_wheel", None), ("print_lever", 40), ("dispatch", 70), ("lid_handle", 40),
                 ("crank", None), ("speed_knob", 40), ("keys", 60), ("sector_knob", 46)):
    v = L[key]
    if len(v) == 3:
        cx, cy, r = v[0], v[1], v[2] + 22
    else:
        cx, cy, r = v[0] + v[2] / 2, v[1] + v[3] / 2, rad
    d = np.hypot(xs - cx * S, ys - cy * S) / S
    rub += np.clip(1 - d / r, 0, 1) ** 1.5
dirt = blur(np.clip(dirt, 0, 1), 3) * (0.6 + 0.4 * grain)
rust = blur(np.clip(rust, 0, 1), 1.2) * (0.5 + 0.5 * noise(30, 3))
chips = blur(np.clip(chips, 0, 1), 0.6)
rub = np.clip(rub, 0, 1) * (0.5 + 0.5 * grain)

out = im.copy()
out = out * (1 - 0.8 * dirt[..., None]) + dirt_col * (0.8 * dirt[..., None])
rust = np.clip(rust * 1.6, 0, 1)
out = out * (1 - 0.85 * rust[..., None]) + rust_col * (0.85 * rust[..., None]) * (0.7 + 1.4 * out.mean(axis=2, keepdims=True))
lum = out.mean(axis=2, keepdims=True)
out = out * (1 - 0.7 * chips[..., None]) + (primer * 0.6 + lum * 0.4) * (0.7 * chips[..., None])
out = out + rub[..., None] * 0.06 * np.array([1.0, 0.9, 0.7], np.float32)
# Brass tarnishes green-black where it isn't handled.
r_, g_, b_ = im[..., 0], im[..., 1], im[..., 2]
brassy = np.clip((r_ - b_) * 4.0 - 0.3, 0, 1) * np.clip((g_ - b_) * 4.0, 0, 1)
verd = brassy * np.clip((noise(18, 4) - 0.45) * 3.0, 0, 1) * (1 - rub)
out = out * (1 - 0.75 * verd[..., None]) + np.array([0.16, 0.24, 0.18], np.float32) * (0.75 * verd[..., None]) * (0.5 + lum)
out = out * (1 - 0.35 * brassy[..., None] * (1 - rub[..., None]))
# Dust over everything, a little.
out = out * (0.94 + 0.08 * grain[..., None]) + 0.012 * blotch[..., None]
Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(sys.argv[2])
print("weathered:", sys.argv[2])
