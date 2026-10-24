#!/usr/bin/env python3
"""Lay out the Robbie designs as character sheets: the big Lab view, the in-game top-down sprite on a light and a
dark sea floor (and at real play size), a description and the parts the Lab could swap. Then one sheet of all five.

Usage: python3 tools/art/robbie_sheet.py <render_dir> <out_dir> [round]
  reads <render_dir>/robbie_<n>_lab.png, _top.png, _parts.txt; writes <out_dir>/robbie-<n>-<name>.png and an
  overview (robbies.png for round 1, robbies-2.png for round 2: designs 6-10 on dark sheets, with Bathy beside them)
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from post import font, hexc, text_size  # noqa: E402

NAMES = {1: "Bathy", 2: "Squidge", 3: "Tug", 4: "Puff", 5: "Bell", 6: "Boiler", 7: "Hardsuit", 8: "Lighthouse",
         9: "Scaphe", 10: "Phono"}
DESC = {
    1: "A brass diving bell with one big porthole. Its face is a little screen behind the glass: the eyes glow, "
       "and can blink, squint or panic.",
    2: "A soft pink squid with huge eyes and curly tentacles. Its lamp is a glowing spot under the eyes, like real "
       "deep-sea squid.",
    3: "A wind-up tin tugboat. The headlamps are its eyes, the grille is a grin, and the key in its back is the "
       "battery.",
    4: "A spiky purple puffer with a big grin. Its lamp dangles in front on a stalk like an anglerfish's lure, which "
       "suits a game about light.",
    5: "A glass jellyfish. Under the dome, a glowing little brain with a face; below it, jets and cable tentacles "
       "with pink tips.",
    6: "A riveted steam boiler on paddle wheels. Its one eye is a pressure gauge: the needle climbs when it is "
       "frightened, and the furnace glows through the grate.",
    7: "An armoured diving suit with nobody inside. Claws for hands, three portholes, a hose back to the station, "
       "and two dim lights deep behind the glass.",
    8: "A streamlined Art Deco beacon. The lantern room on top is its lamp, the glowing slit is its eye, three red "
       "fins steer it.",
    9: "A little bathyscaphe: a long float, and under it a pressure sphere with one small lit window. It trails a "
       "guide chain like the first deep divers.",
    10: "A mahogany valve radio with a brass gramophone horn. The horn throws the light and could listen for eels; "
        "the valves glow behind the grille.",
}
THEMES = {"light": dict(bg="#e9eff3", ink="#1a1f2e", muted="#6a7488", body="#3a4258"),
          "dark": dict(bg="#12161c", ink="#ece6da", muted="#8a94a6", body="#c8ccd4")}
BG = "#e9eff3"
INK = "#1a1f2e"


def wrap(draw, text, f, width):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if text_size(draw, trial, f)[0] > width and line:
            lines.append(line)
            line = word
        else:
            line = trial
    return lines + [line]


def sea_tile(size, dark):
    if dark == "slate":
        return Image.new("RGBA", (size, size), hexc("#1c222a"))
    if not dark:
        return Image.new("RGBA", (size, size), hexc("#dfe6ec"))
    y, x = np.mgrid[0:size, 0:size]
    ripple = 0.5 + 0.5 * np.sin((x + y) * 0.21 + np.sin(x * 0.05) * 2.0)
    base = np.array([0.075, 0.19, 0.23]) + 0.025 * ripple[..., None]
    return Image.fromarray((np.clip(base, 0, 1) * 255).astype(np.uint8)).convert("RGBA")


def sprite_on(top, size, sprite_px, dark):
    tile = sea_tile(size, dark)
    bbox = top.getbbox()
    s = top.crop(bbox) if bbox else top
    k = sprite_px / max(s.size)
    s = s.resize((max(1, int(s.size[0] * k)), max(1, int(s.size[1] * k))), Image.LANCZOS)
    tile.alpha_composite(s, ((size - s.size[0]) // 2, (size - s.size[1]) // 2))
    return tile


def sheet(n, render_dir, out_dir, theme="light"):
    th = THEMES[theme]
    lab = Image.open(os.path.join(render_dir, "robbie_%d_lab.png" % n)).convert("RGBA")
    top = Image.open(os.path.join(render_dir, "robbie_%d_top.png" % n)).convert("RGBA")
    parts = open(os.path.join(render_dir, "robbie_%d_parts.txt" % n)).read().split("\n")
    parts = [p for p in parts if p.strip()]
    im = Image.new("RGBA", (1280, 720), hexc(th["bg"]))
    im.alpha_composite(lab, (0, 0))
    d = ImageDraw.Draw(im)
    x0 = 740
    title_font = font("Fredoka", 72) if theme == "light" else font("BigShoulders", 80)
    body_font = "Fredoka" if theme == "light" else "SpecialElite"
    d.text((x0, 34), "ROBBIE DESIGN %d" % n, font=font("ChakraPetch", 22), fill=hexc(th["muted"]))
    d.text((x0, 60), NAMES[n], font=title_font, fill=hexc(th["ink"]))
    f = font(body_font, 24 if theme == "light" else 21)
    y = 160
    for line in wrap(d, DESC[n], f, 500):
        d.text((x0, y), line, font=f, fill=hexc(th["body"]))
        y += 32
    y += 18
    d.text((x0, y), "In the game, seen from above", font=font("ChakraPetch", 20), fill=hexc(th["muted"]))
    y += 32
    im.alpha_composite(sprite_on(top, 150, 120, "slate" if theme == "dark" else False), (x0, y))
    im.alpha_composite(sprite_on(top, 150, 120, True), (x0 + 166, y))
    im.alpha_composite(sprite_on(top, 150, 56, True), (x0 + 332, y))
    d.text((x0 + 332, y + 154), "real size", font=font("ChakraPetch", 16), fill=hexc(th["muted"]))
    y += 190
    d.text((x0, y), "Parts the Lab can swap", font=font("ChakraPetch", 20), fill=hexc(th["muted"]))
    y += 30
    for p in parts:
        d.ellipse((x0 + 2, y + 10, x0 + 12, y + 20), fill=hexc("#ff8a5c"))
        d.text((x0 + 22, y), p, font=font(body_font, 22 if theme == "light" else 19), fill=hexc(th["body"]))
        y += 31
    path = os.path.join(out_dir, "robbie-%d-%s.png" % (n, NAMES[n].lower()))
    im.convert("RGB").save(path, optimize=True)
    return path


def overview(render_dir, out):
    w = 5 * 340 + 6 * 20
    im = Image.new("RGBA", (w, 620), hexc(BG))
    d = ImageDraw.Draw(im)
    d.text((20, 16), "Robbie N+1 — five Robbies", font=font("ChakraPetch", 30), fill=hexc(INK))
    for i, n in enumerate(sorted(NAMES)):
        x = 20 + i * 360
        lab = Image.open(os.path.join(render_dir, "robbie_%d_lab.png" % n)).convert("RGBA").resize((340, 340),
                                                                                                    Image.LANCZOS)
        im.alpha_composite(lab, (x, 64))
        tw, _ = text_size(d, "%d · %s" % (n, NAMES[n]), font("Fredoka", 34))
        d.text((x + (340 - tw) // 2, 408), "%d · %s" % (n, NAMES[n]), font=font("Fredoka", 34), fill=hexc(INK))
        top = Image.open(os.path.join(render_dir, "robbie_%d_top.png" % n)).convert("RGBA")
        im.alpha_composite(sprite_on(top, 140, 110, True), (x + 30, 462))
        im.alpha_composite(sprite_on(top, 140, 52, True), (x + 180, 462))
    im.convert("RGB").save(out, optimize=True)


def overview_2(render_dir, out):
    """Round 2: the five machines on dark sheets, with Bathy (Albert's round-1 favourite) beside them."""
    ids = [6, 7, 8, 9, 10, 1]
    th = THEMES["dark"]
    w = 6 * 300 + 7 * 20
    im = Image.new("RGBA", (w, 590), hexc(th["bg"]))
    d = ImageDraw.Draw(im)
    d.text((20, 16), "Robbie N+1 — five machines of the steam colony (and Bathy, for comparison)",
           font=font("ChakraPetch", 30), fill=hexc(th["ink"]))
    for i, n in enumerate(ids):
        x = 20 + i * 320
        lab = Image.open(os.path.join(render_dir, "robbie_%d_lab.png" % n)).convert("RGBA").resize((300, 300),
                                                                                                    Image.LANCZOS)
        im.alpha_composite(lab, (x, 64))
        label = "%d · %s" % (n, NAMES[n]) if n != 1 else "Bathy (round 1)"
        f = font("BigShoulders", 36)
        tw, _ = text_size(d, label, f)
        d.text((x + (300 - tw) // 2, 372), label, font=f, fill=hexc(th["ink"] if n != 1 else th["muted"]))
        top = Image.open(os.path.join(render_dir, "robbie_%d_top.png" % n)).convert("RGBA")
        im.alpha_composite(sprite_on(top, 130, 104, True), (x + 14, 432))
        im.alpha_composite(sprite_on(top, 130, 50, True), (x + 156, 432))
    im.convert("RGB").save(out, optimize=True)


def main():
    render_dir, out_dir = sys.argv[1], sys.argv[2]
    round_ = int(sys.argv[3]) if len(sys.argv) > 3 else 1
    os.makedirs(out_dir, exist_ok=True)
    if round_ == 2:
        for n in (6, 7, 8, 9, 10):
            print("wrote", sheet(n, render_dir, out_dir, "dark"))
        overview_2(render_dir, os.path.join(out_dir, "robbies-2.png"))
        print("wrote", os.path.join(out_dir, "robbies-2.png"))
        return
    for n in (1, 2, 3, 4, 5):
        print("wrote", sheet(n, render_dir, out_dir))
    overview(render_dir, os.path.join(out_dir, "robbies.png"))
    print("wrote", os.path.join(out_dir, "robbies.png"))


if __name__ == "__main__":
    main()
