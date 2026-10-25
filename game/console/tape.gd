class_name Tape
extends RefCounted
## What the teleprinter prints for a dive: one line per thing worth knowing, at the tick
## it happened. {t, text, kind, rule}; kinds: info, card, contact, hit, voice, end.
## Built from the recording and the sonar's record of what was sensed, so the tape,
## like the scope, only knows what Robbie knew.

const HOLD := 9   # a card or the lamp must hold this many ticks before the tape mentions it
const REPEAT := 150   # ...and the same card isn't mentioned again within five seconds


static func lines(dive: Dive, sonar: SonarView, serial: int, sector: String, captions: Array, last_words: String) -> Array:
	var out: Array = []
	var rec := dive.rec
	var n := rec.ticks
	var who := "ROBBIE %03d" % serial if serial > 0 else "TRIAL HULL"
	out.append({"t": 0, "text": "%s DISPATCHED  ·  %s" % [who, sector.to_upper()], "kind": "info", "rule": -1})
	# Card changes and lamp changes that held.
	# A card is mentioned when it takes over, but not again within REPEAT ticks: two cards
	# taking turns would otherwise fill the strip.
	var printed_rule := -2
	var printed_lamp := 1
	var said_at := {}
	for k in n:
		if k == 0 or rec.rrule[k] != rec.rrule[k - 1]:
			var r := rec.rrule[k]
			if r != printed_rule and _holds(rec.rrule, k, n) and k - int(said_at.get(r, -REPEAT)) >= REPEAT:
				printed_rule = r
				said_at[r] = k
				var txt := "NO CARD APPLIES  ·  DRIFTING" if r < 0 else "CARD %d  ·  %s  %s" % [r + 1, CardArt.lines(dive.program.rules[r])[0], _cond_tail(dive.program.rules[r])]
				out.append({"t": k, "text": txt.strip_edges(), "kind": "card", "rule": r})
		var lamp := rec.rflags[k] & 1
		if k > 0 and lamp != printed_lamp and _holds_flag(rec.rflags, k, n, lamp):
			printed_lamp = lamp
			out.append({"t": k, "text": "LAMP ON" if lamp == 1 else "LAMP OFF  ·  RUNNING DARK", "kind": "info", "rule": rec.rrule[k]})
	# Contacts, in the order Robbie found them.
	for i: int in sonar.contact_ids:
		var k: int = sonar.first_sensed[i]
		var dx := rec.bx[i][k] - rec.rx[k]
		var dy := rec.by[i][k] - rec.ry[k]
		var brg := int(roundf(rad_to_deg(atan2(float(dx), float(-dy)))))
		brg = (brg + 360) % 360
		var rng := int(roundf(sqrt(float(dx) * dx + float(dy) * dy) / float(Fx.TILE)))
		out.append({"t": k, "text": "CONTACT C-%d  ·  %s  ·  BRG %03d  ·  %d M" % [sonar.contact_ids[i], _kind(dive.world.bodies[i].kind), brg, rng],
			"kind": "contact", "rule": rec.rrule[k]})
	if sonar.exit_found < n:
		out.append({"t": sonar.exit_found, "text": "BEACON SIGHTED", "kind": "contact", "rule": rec.rrule[sonar.exit_found]})
	for p in dive.room.plants.size():
		if p < sonar.plant_found.size() and sonar.plant_found[p] < n:
			var k2: int = sonar.plant_found[p]
			out.append({"t": k2, "text": "GLOW ON THE BOTTOM  ·  ANEMONE", "kind": "contact", "rule": rec.rrule[k2]})
	# Events.
	var last_crash := -100
	var charge_marks := [50, 25, 10]
	for e in dive.world.events:
		var t: int = e["t"]
		match e["type"]:
			"damage":
				out.append({"t": t, "text": "HIT  ·  %s  ·  HULL %d" % [Voice.cause_label(e["cause"]).to_upper().trim_prefix("THE "), e["hp"]], "kind": "hit", "rule": rec.rrule[t]})
			"crash":
				if t - last_crash > 45:
					out.append({"t": t, "text": "SCRAPED ROCK", "kind": "hit", "rule": rec.rrule[t]})
				last_crash = t
			"laser":
				var target: int = e["target"]
				var c := "C-%d" % sonar.contact_ids.get(target, 0) if sonar.contact_ids.has(target) else "CONTACT"
				out.append({"t": t, "text": "LASER  ·  %s%s" % [c, "  ·  GLANCED OFF" if e.get("bounced", false) else ""], "kind": "info", "rule": rec.rrule[t]})
			"lurker_wakes":
				out.append({"t": t, "text": "SOMETHING IN THE ROCK IS AWAKE", "kind": "hit", "rule": rec.rrule[t]})
			"eel_hears":
				out.append({"t": t, "text": "AN EEL HAS HEARD HIM", "kind": "hit", "rule": rec.rrule[t]})
			"valve":
				out.append({"t": t, "text": "VALVE %s" % str(e["state"]).to_upper(), "kind": "info", "rule": rec.rrule[t]})
	for k in range(1, n):
		var pct := rec.ren[k] * 100 / maxi(dive.world.energy_max, 1)
		var prev := rec.ren[k - 1] * 100 / maxi(dive.world.energy_max, 1)
		for m: int in charge_marks:
			if prev >= m and pct < m:
				out.append({"t": k, "text": "CHARGE %d%%" % m, "kind": "hit" if m <= 10 else "info", "rule": rec.rrule[k]})
	# His voice.
	var said_last := false
	for c in captions:
		out.append({"t": int(c[0]), "text": "“%s”" % c[1], "kind": "voice", "rule": -1})
		if str(c[1]) == last_words:
			said_last = true
	# The end.
	var end := n - 1
	if dive.world.result == World.Result.EXIT:
		out.append({"t": end, "text": "BEACON REACHED  ·  HULL RECOVERABLE  ·  T+%s" % DiveText.time_of(end), "kind": "end", "rule": -1})
	else:
		out.append({"t": end, "text": "CARRIER LOST  ·  %s  ·  T+%s" % [Voice.cause_label(dive.world.cause).to_upper(), DiveText.time_of(end)], "kind": "end", "rule": -1})
		if last_words != "" and not said_last:
			out.append({"t": end, "text": "LAST: “%s”" % last_words, "kind": "voice", "rule": -1})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["t"]) < int(b["t"]))
	return out


static func _cond_tail(rule: Dictionary) -> String:
	return "" if rule["cond"] == "" else "(" + CardArt.lines(rule)[1] + ")"


static func _holds(arr: PackedInt32Array, k: int, n: int) -> bool:
	var v := arr[k]
	for j in range(k, mini(k + HOLD, n)):
		if arr[j] != v:
			return false
	return true


static func _holds_flag(arr: PackedInt32Array, k: int, n: int, v: int) -> bool:
	for j in range(k, mini(k + HOLD, n)):
		if (arr[j] & 1) != v:
			return false
	return true


static func _kind(kind: int) -> String:
	match kind:
		Body.Kind.JELLYFISH:
			return "JELLYFISH"
		Body.Kind.LURKER:
			return "LURKER"
		Body.Kind.EEL:
			return "EEL"
	return "UNKNOWN"
