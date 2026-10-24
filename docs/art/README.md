# Art direction: first concepts (2026-10-24)

Albert's brief: cool backgrounds, a cute Robbie sprite, the whole game and its UI looking like a proper game, and a
big Robbie in the Lab that changes as it is customised. Earlier notes (docs/design/feedback-2026-10-17.md): cute,
steampunky, Outer Wilds but 2D and more cartoonish, drawn not 3D, organic shapes, the top-down view kept.

Everything here is rendered in Blender and drawn to look 2D (flat colour bands, ink outlines, a lamp light computed
in the shader). Albert picks one style and one Robbie; the pair becomes the art direction.

## Five styles

The same stretch of a dive in each: Robbie (a neutral stand-in), three jellyfish, a lurker in the rock, the valve,
plants and the exit beacon, with that style's version of the dive screen's UI.

| | Style | In one line |
|---|---|---|
| 1 | Brass & Ink | A storybook: ink outlines, engraved hatching in the dark, brass plates and a parchment ribbon. |
| 2 | Glow Abyss | Near-black water, bioluminescent neon, a hard white beam, a sonar-style HUD. |
| 3 | Toy Aquarium | A toy diorama: candy pebbles, warm sand, soft light, tilt-shift blur, rounded bubbly UI. |
| 4 | Paper Cut | Layered cut paper with drop shadows, paper grain, torn-paper labels. |
| 5 | Jovian Comic | Bold ink, hard cel shading, halftone dots, an orange rim of Jupiter light, speech bubbles. |

`concepts/styles.png` shows all five; `concepts/style-<n>-*.png` each one full size.

## Five Robbies

Drawn in a neutral sheet style so the design is judged, not the rendering; each sheet also shows the top-down
sprite the game would use, on a light and a dark floor and at real play size.

| | Robbie | In one line |
|---|---|---|
| 1 | Bathy | A brass diving bell; its face is a screen behind one big porthole. |
| 2 | Squidge | A soft pink squid with huge eyes; the lamp is a glowing spot under them. |
| 3 | Tug | A wind-up tin tugboat; headlamp eyes, a grille grin, a key in its back. |
| 4 | Puff | A spiky puffer with a big grin; the lamp dangles in front like an anglerfish's lure. |
| 5 | Bell | A glass jellyfish; a glowing little brain with a face under the dome. |

`robbies/robbies.png` shows all five; `robbies/robbie-<n>-*.png` each sheet.

## How they are made

- `tools/art/kit.py`: Blender helpers (cartoon shading, the lamp light, outlines, primitives).
- `tools/art/concept_scene.py <style> <out.png> [samples]`: one style concept (Blender).
- `tools/art/post.py <raw_dir> <out_dir>`: surface treatment and the UI mock for each style (Python + Pillow).
- `tools/art/robbie_designs.py <design> <out_prefix> [samples]`: one Robbie, Lab view and top-down view (Blender).
- `tools/art/robbie_sheet.py <render_dir> <out_dir>`: the Robbie sheets (Python + Pillow).

Blender 5.2.3 LTS runs headless on the CPU (no GPU here); a style concept takes about two minutes at 64 samples.
Fonts are from Google Fonts (SIL Open Font License) and are fetched into ~/.cache/robbie/fonts.
