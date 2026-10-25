"""Paper grain for the console's cards, tape, memos and notes: game/art/console/paper.png (512x512, tiling).

A white sheet with fibres and mottling in alpha, so Godot can tint it any paper colour.
  python3 tools/art/console_paper.py
"""
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
rng = np.random.default_rng(1957)
N = 512


def tile_noise(scale):
    """Smooth noise that tiles: the coarse grid wraps around before it is enlarged."""
    k = N // scale
    small = rng.random((k, k))
    padded = np.pad(small, 2, mode="wrap")
    big = Image.fromarray((padded * 255).astype(np.uint8)).resize(((k + 4) * scale, (k + 4) * scale), Image.BICUBIC)
    arr = np.asarray(big, dtype=np.float32) / 255.0
    return arr[2 * scale:2 * scale + N, 2 * scale:2 * scale + N]


mottle = 0.5 * tile_noise(64) + 0.3 * tile_noise(16) + 0.2 * tile_noise(4)
fibres = np.zeros((N, N), np.float32)
for _ in range(1400):
    x, y = rng.integers(0, N, 2)
    a = rng.random() * np.pi
    ln = rng.integers(6, 22)
    for s in range(ln):
        fx = int(x + np.cos(a) * s) % N
        fy = int(y + np.sin(a) * s) % N
        fibres[fy, fx] += 0.5
fib_im = Image.fromarray((np.clip(np.tile(fibres, (3, 3)), 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
fib = np.asarray(fib_im, dtype=np.float32)[N:2 * N, N:2 * N] / 255.0
shade = np.clip(0.55 + 0.45 * (mottle - 0.5) * 2.0 - fib * 0.5, 0, 1)
alpha = np.clip((1.0 - shade) * 0.55 + fib * 0.35, 0, 1)
rgba = np.zeros((N, N, 4), np.uint8)
rgba[..., 0] = 90
rgba[..., 1] = 70
rgba[..., 2] = 40
rgba[..., 3] = (alpha * 255).astype(np.uint8)
out = os.path.join(ROOT, "game/art/console/paper.png")
Image.fromarray(rgba, "RGBA").save(out)
print("wrote", out)
