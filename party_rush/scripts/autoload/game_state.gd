extends Node

## Global game state for Party Rush — scores, player colors, and round flow.

const PLAYER_COLORS: Array[Color] = [
	Color(0.95, 0.25, 0.25),  # Red
	Color(0.25, 0.55, 1.0),   # Blue
	Color(1.0, 0.85, 0.2),    # Yellow
]

const PLAYER_NAMES: PackedStringArray = ["Red", "Blue", "Yellow"]

const MINIGAME_SCENES: PackedStringArray = [
	"res://scenes/minigames/flag_rush.tscn",
	"res://scenes/minigames/tag_frenzy.tscn",
	"res://scenes/minigames/bomb_pass.tscn",
	"res://scenes/minigames/platform_race.tscn",
]

const MINIGAME_NAMES: PackedStringArray = [
	"Flag Rush",
	"Tag Frenzy",
	"Bomb Pass",
	"Platform Race",
]

const WINS_TO_VICTORY := 3

var scores: Array[int] = [0, 0, 0]
var current_minigame_index: int = 0
var rounds_played: int = 0
var is_playing: bool = false

signal scores_changed
signal minigame_started(name: String)
signal minigame_ended(winner_index: int, message: String)
signal match_ended(winner_index: int)


func reset_match() -> void:
	scores = [0, 0, 0]
	current_minigame_index = 0
	rounds_played = 0
	is_playing = false
	scores_changed.emit()


func add_score(player_index: int, amount: int = 1) -> void:
	if player_index < 0 or player_index >= scores.size():
		return
	scores[player_index] += amount
	scores_changed.emit()


func get_leader_index() -> int:
	var best := 0
	for i in range(1, scores.size()):
		if scores[i] > scores[best]:
			best = i
	return best


func has_match_winner() -> bool:
	for score in scores:
		if score >= WINS_TO_VICTORY:
			return true
	return false


func get_match_winner_index() -> int:
	return get_leader_index()


func next_minigame_scene() -> String:
	var scene := MINIGAME_SCENES[current_minigame_index]
	current_minigame_index = (current_minigame_index + 1) % MINIGAME_SCENES.size()
	return scene


func get_minigame_name(index: int) -> String:
	return MINIGAME_NAMES[index % MINIGAME_NAMES.size()]
