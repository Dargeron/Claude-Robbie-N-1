class_name DiveText
extends RefCounted
## Turns a dive's think trace into plain words: the seed of the Why? panel.
## Distances are shown in metres; one tile is one metre.


static func tenths(sub_px: int) -> String:
	var t := sub_px * 10 / Fx.TILE
	return "%d.%d m" % [t / 10, t % 10]


static func time_of(tick: int) -> String:
	return "%d.%ds" % [tick / World.TICKS_PER_SECOND, (tick % World.TICKS_PER_SECOND) * 10 / World.TICKS_PER_SECOND]


## One line per rule for one think: what Robbie checked and why it chose what it did.
static func explain(program: Program, entry: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for c in entry["checks"]:
		var i: int = c[0]
		var code: String = c[1]
		var value: int = c[2]
		var rule: Dictionary = program.rules[i]
		var label := program.rule_label(rule)
		match code:
			"chosen":
				out.append("Rule %d chosen: %s" % [i + 1, label])
			"instant":
				out.append("Rule %d applied (setting): %s" % [i + 1, label])
			"cond_false":
				out.append("Rule %d skipped: %s" % [i + 1, _why_cond(rule, value)])
			"not_applicable":
				out.append("Rule %d skipped: %s" % [i + 1, _why_action(rule, value)])
	if entry["rule"] == -1:
		out.append("No rule applied, so Robbie drifted.")
	return out


static func _why_cond(rule: Dictionary, value: int) -> String:
	var neg: bool = rule["negate"]
	var cdef: Dictionary = Catalogue.CONDITIONS[rule["cond"]]
	var label: String = cdef["label"]
	var truth := "true" if neg else "false"
	match rule["cond"]:
		"hostile_near":
			if value < 0:
				return "%s = %s (no hostile sensed)" % [label, truth]
			return "%s = %s (nearest hostile at %s, range %s m)" % [label, truth, tenths(value), rule["cond_param"]]
		"energy_below":
			return "%s %s%% = %s (energy at %d%%)" % [label, rule["cond_param"], truth, value]
		"executing":
			if value <= 0:
				return "%s %s = %s (no rule was running)" % [label, rule["cond_param"], truth]
			return "%s %s = %s (rule %d was running)" % [label, rule["cond_param"], truth, value]
	return "%s = %s" % [label, truth]


static func _why_action(rule: Dictionary, value: int) -> String:
	match rule["action"]:
		"keep_distance":
			if value < 0:
				return "no hostile sensed to keep away from"
			return "nearest hostile at %s, outside %s m" % [tenths(value), rule["param"]]
		"move_towards":
			if rule["param"] == "light":
				return "no light in sight"
		"shoot":
			return "nothing to shoot (no target in range, laser cooling down, or low energy)"
	return "could not be carried out"


## What Robbie's sensors read at one think, in the words the conditions use.
## Returns [label, value, notable] triples; notable = the reading would make its condition true.
static func senses(room: Room, entry: Dictionary) -> Array:
	var out: Array = []
	var s: PackedInt32Array = entry.get("senses", PackedInt32Array())
	if s.size() < 5:
		return out
	out.append(["wall ahead", "yes" if s[0] == 1 else "no", s[0] == 1])
	if not room.jelly_spawns.is_empty() or not room.lurker_spawns.is_empty() or room.variation("jelly_scatter", 0) > 0:
		if s[1] < 0:
			out.append(["nearest hostile", "none sensed", false])
		else:
			var kind := "jellyfish" if s[2] == Body.Kind.JELLYFISH else ("lurker" if s[2] == Body.Kind.LURKER else "hostile")
			var where := "touching Robbie" if s[1] <= 0 else "at " + tenths(s[1])
			out.append(["nearest hostile", "%s %s" % [kind, where], s[1] <= 6 * Fx.TILE])
	if not room.gate_tiles.is_empty():
		var v: String = ["not sensed", "open", "shut"][clampi(s[3], 0, 2)]
		out.append(["valve ahead", v, s[3] != 0])
	out.append(["energy", "%d%%" % s[4], s[4] < 25])
	return out


## Compact trace: one line per think where the chosen rule changed.
static func trace_text(dive: Dive) -> String:
	var lines := PackedStringArray()
	var last := -2
	for entry in dive.vm.trace:
		if entry["rule"] == last:
			continue
		last = entry["rule"]
		lines.append("[%s] %s" % [time_of(entry["t"]), " | ".join(explain(dive.program, entry))])
	for e in dive.world.events:
		lines.append("[%s] event: %s" % [time_of(e["t"]), JSON.stringify(e)])
	return "\n".join(lines)
