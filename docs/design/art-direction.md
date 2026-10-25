# Art direction: three ways to make the console feel real (for Albert to choose)

Status: **mock-ups, waiting for Albert's pick**, 2026-10-25. After playtesting 0.1.0 Albert found the desk "a bit too
clean... bland" and wondered about 3D or another style. The scope stays Dead Air in all three; Bathy stays the only
warm, cute thing. The mock-ups show the same moment (Sector 2, Robbie 004 running dark among the jellyfish) on the
new 0.2.0 desk.

| | A. 3D, from the chair | B. Lived-in 2D | C. Inked |
|---|---|---|---|
| Mock-up | `docs/art/direction/a-3d.jpg` | `docs/art/direction/b-lived-in.jpg` | `docs/art/direction/c-inked.jpg` |
| What it is | The console built as a 3D room: you sit at it, the lower machines slope towards you as a desk, a lamp hangs over it, the desk edge has your mug and papers | The same flat, face-on desk as now, re-rendered as forty years old: mismatched replacement panels, rust weeping from rivets, tarnished brass, chipped paint, cables, a pipe run, one lamp with dark beyond it | A graphic-novel look: solid blacks, ink outlines, flat colour in three tones, hatching, paper tooth; only the scope and lamps glow |
| Feels | Most real. You are *in* a place | Real, grimy, but still a panel you look at | Most stylised; strongest identity; least "real" |
| Touch on the tablet | Same gestures; the view can lean or zoom towards a machine when you use it | Exactly as now | Exactly as now |
| What it costs | The presentation rebuilt in Godot 3D (the sim, the story, the rules and most machine logic stay). Two or three sessions. Lighting baked in Blender so it runs on the tablet | Half a session: the art pipeline already makes it | A session or two: every piece of art redrawn through an ink pass, and the text kept readable |
| Risks | Performance on the tablet (manageable with baked light); small text at an angle needs the zoom | May still feel like a UI if the clutter is too timid | Legibility of cards and tape; clashes with the soft glow of Dead Air |

**Recommended: A, with B's weathering on its surfaces.** It answers "make it feel real" most directly, and the
3D mock-up already shows the machine as a place you sit in. B's rust, grime and mismatched panels carry over as its
materials. C is the bold alternative if we want a strong graphic identity over realism.

Albert's call. If he picks A, the next step is a small Godot 3D test on his tablet (one machine, the press, in
3D with baked light) before rebuilding the whole desk.
