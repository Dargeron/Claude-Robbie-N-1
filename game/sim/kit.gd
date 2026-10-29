class_name Kit
extends RefCounted
## What a hull carries out of the hangar: the parts in Bathy's six sockets, turned into the
## numbers the sim uses. Integers only. A Kit with no parts is the stock hull, the one every
## room was tuned for and the golden replays were dived with (docs/design/lab-parts-and-pay.md).
## The Lab's names, prices and words for the parts are content (content/lab/parts.json);
## only what a part does lives here.

## Every part the sim knows, and the socket it goes in (one part per socket).
const SOCKET := {
	"spotlight": "lamp", "floodlight": "lamp", "red_lamp": "lamp",
	"twin_screws": "drive", "silent_fins": "drive",
	"battery_bank": "belly", "reserve_cell": "belly",
	"plating": "hull", "insulated": "hull",
	"flares": "tool",
	"hydrophone": "hatch",
}

const FLARE_COUNT := 3

var parts: Array[String] = []    # fitted parts, sorted, without the stock ones
var lamp_range := 96 * Fx.ONE    # how far the lamp reaches
var lamp_half := 398             # half the lamp's cone (Fx angle units; 398 is about 35 degrees)
var lamp_halo := 48 * Fx.ONE     # a lit lamp glows this far all round
var red_lamp := false            # jellyfish don't see a red lamp
var speed := 256                 # swimming, sub-pixels per tick
var reverse := 192               # backing away
var drain_move := 1              # extra charge per tick while moving
var hp := 3
var energy_pct := 100            # charge, as a share of the room's
var eel_hear := 48 * Fx.ONE      # how far eels hear him swim
var reserve := false             # a second wind when the charge runs out
var insulated := false           # the shut valve doesn't sting
var flares := 0
var laser := true                # the stock tool; the flare launcher takes its socket
var hydrophone := false


static func stock() -> Kit:
	return Kit.new()


static func from_parts(ids: Array) -> Kit:
	var k := Kit.new()
	var fitted: Array[String] = []
	var used := {}
	for id: Variant in ids:
		var s := str(id)
		if not SOCKET.has(s) or used.has(SOCKET[s]):
			continue   # unknown, or a second part for a socket already taken: the first one wins
		used[SOCKET[s]] = true
		fitted.append(s)
	fitted.sort()
	k.parts = fitted
	for s in fitted:
		match s:
			"spotlight":
				k.lamp_range = 160 * Fx.ONE
				k.lamp_half = 199
			"floodlight":
				k.lamp_range = 56 * Fx.ONE
				k.lamp_half = 1365
			"red_lamp":
				k.red_lamp = true
			"twin_screws":
				k.speed = 384
				k.reverse = 288
				k.drain_move = 2
				k.eel_hear = 96 * Fx.ONE
			"silent_fins":
				k.speed = 179
				k.reverse = 134
				k.eel_hear = 0
			"battery_bank":
				k.energy_pct = 140
			"reserve_cell":
				k.reserve = true
			"plating":
				k.hp = 5
			"insulated":
				k.insulated = true
			"flares":
				k.flares = FLARE_COUNT
				k.laser = false
			"hydrophone":
				k.hydrophone = true
	if fitted.has("plating"):   # the armour's weight, after whatever drives him
		k.speed = k.speed * 9 / 10
		k.reverse = k.reverse * 9 / 10
	return k


func is_stock() -> bool:
	return parts.is_empty()


## The parts as one short line, for a dive's entry in the save and the tape.
func to_text() -> String:
	return ",".join(parts)


static func from_text(text: String) -> Kit:
	return Kit.from_parts(Array(text.split(",", false)))
