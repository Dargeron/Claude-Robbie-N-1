class_name Recorder
extends RefCounted
## Per-tick snapshots of a dive in packed arrays, so the replay can jump to any
## tick instantly. About 60 bytes per body per second of dive.

var ticks := 0
# Robbie
var rx := PackedInt32Array()
var ry := PackedInt32Array()
var ra := PackedInt32Array()
var rhp := PackedInt32Array()
var ren := PackedInt32Array()
var rflags := PackedInt32Array()   # bit0 lamp, bit1 moving, bit2 committed, bit3 invulnerable
var rrule := PackedInt32Array()    # rule driving Robbie (-1 none)
# Creatures: one array per body
var bx: Array[PackedInt32Array] = []
var by: Array[PackedInt32Array] = []
var bstate: Array[PackedInt32Array] = []   # alive | state << 1 | (glow > 0) << 8
var gate := PackedByteArray()
var hashes := PackedInt64Array()


func _init(w: World) -> void:
	for _b in w.bodies:
		bx.append(PackedInt32Array())
		by.append(PackedInt32Array())
		bstate.append(PackedInt32Array())


func capture(w: World) -> void:
	ticks += 1
	rx.append(w.robbie.x)
	ry.append(w.robbie.y)
	ra.append(w.robbie.angle)
	rhp.append(w.robbie.hp)
	ren.append(w.energy)
	var f := (1 if w.lamp_on else 0) | ((1 if w.moving else 0) << 1) \
		| ((1 if w.commit > 0 else 0) << 2) | ((1 if w.invuln > 0 else 0) << 3)
	rflags.append(f)
	rrule.append(w.act_rule)
	for i in w.bodies.size():
		var b := w.bodies[i]
		bx[i].append(b.x)
		by[i].append(b.y)
		bstate[i].append((1 if b.alive else 0) | (b.state << 1) | ((1 if b.glow > 0 else 0) << 8))
	gate.append(w.gate_state)
	if w.tick % World.HASH_EVERY == 0:
		hashes.append(w.state_hash())
