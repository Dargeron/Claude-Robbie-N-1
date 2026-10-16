class_name Body
extends RefCounted
## Anything that moves in the simulation: Robbie or a creature. Integers only.

enum Kind { ROBBIE, JELLYFISH, LURKER }

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
var rng: Rng = null


func kind_name() -> String:
	match kind:
		Kind.ROBBIE:
			return "robbie"
		Kind.JELLYFISH:
			return "jellyfish"
		Kind.LURKER:
			return "lurker"
	return "?"
