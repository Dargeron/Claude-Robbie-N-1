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

# Round 2 (2026-10-24): five worlds and five machines

Albert's picks from round 1: the Jovian Comic style and Bathy. His new direction: darker; the whole game steampunk,
set in a space colonisation that began in a steampunk age (Catherynne Valente's *Radiance*, *Outer Wilds*); and the
styles truly different, not one scene through five filters: different places, shapes, rendering, everything. This
round tests the mood of the whole game. Robbie is Bathy in all five worlds.

## Five worlds

| | World | Place and shapes | Medium | UI |
|---|---|---|---|---|
| 1 | The Drowned Colony | Flooded iron streets of a dead steam colony: deck plates, bulkheads, burst pipes, rooftops | Noir comic, crushed blacks, halftone | Riveted plates, nixie tubes, last words as a telegram |
| 2 | The Pleasure Gardens | A sunken Art Deco promenade: stepped columns, sunburst mosaic, fallen chandelier | Tinted silent film: grain, scratches, iris | Deco ornaments, last words as an intertitle |
| 3 | Dead Air | The world only as sonar returns: contour lines, echoes, contacts, a sweeping scan | Green phosphor CRT, static, tearing | A bakelite and brass receiver, on-screen readouts |
| 4 | The Verdigris Reef | A living reef at an abyss's edge, something huge below; the colonists' stakes, rope, lanterns | Painterly gouache, no outlines | Wooden sign, copper cells, a luggage tag |
| 5 | The Red Spot Mine | A jagged ice canyon, the Company's drill, rails, vents, red light through the ice | Three-ink woodcut (engraved lines, misregistration) | Company propaganda banners |

`worlds/worlds.png` shows all five; `worlds/world-<n>-*.png` each one.

## Five machines

All machine-like, not animal, less cute; drawn on dark sheets in the comic look Albert chose.

| | Robbie | In one line |
|---|---|---|
| 6 | Boiler | A riveted steam boiler on paddle wheels; its eye is a pressure gauge. |
| 7 | Hardsuit | An armoured diving suit with nobody inside; two dim lights behind the glass. |
| 8 | Lighthouse | A streamlined Art Deco beacon; lantern room for a lamp, a glowing visor slit for an eye. |
| 9 | Scaphe | A bathyscaphe: a long float, a pressure sphere below with one lit window. |
| 10 | Phono | A mahogany valve radio with a gramophone horn that throws the light. |

`robbies/robbies-2.png` shows them with Bathy for comparison; `robbies/robbie-<n>-*.png` each sheet.

## Tools

- `tools/art/mood_scene.py <world 1-5> <out.png> [samples]`: one world (Blender).
- `tools/art/mood_post.py <raw_dir> <out_dir>`: each world's medium and UI (Python + Pillow + numpy).
- `tools/art/robbie_designs.py <6-10> <prefix> [samples] [light|dark]` and `tools/art/robbie_sheet.py <dir> <out> 2`.
