class_name Body
extends RefCounted
## Anything that moves in the simulation: Robbie or a creature. Integers only.

enum Kind { ROBBIE, JELLYFISH, LURKER, EEL, SHELLBACK }

var index := 0
var kind := Kind.JELLYFISH
var x := 0
var y := 0
var angle := 0
var radius := 0
var hp := 1
var alive := true
var state := 0
var timer := 0
var timer2 := 0
var windup := 12
var glow := 0          ## glow radius in sub-pixels; 0 = dark
var home_x := 0        ## eels: the x of the shaft they patrol; shellbacks: where they graze
var home_y := 0
var rng: Rng = null


func kind_name() -> String:
	match kind:
		Kind.ROBBIE:
			return "robbie"
		Kind.JELLYFISH:
			return "jellyfish"
		Kind.LURKER:
			return "lurker"
		Kind.EEL:
			return "eel"
		Kind.SHELLBACK:
			return "shellback"
	return "?"
