extends Node

## Carries character select choices into the arena scene.

var p1_fighter_id: int = 0
var p2_fighter_id: int = 1


func reset_selections() -> void:
	p1_fighter_id = 0
	p2_fighter_id = 1
