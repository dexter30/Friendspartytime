extends Node

## Carries Samurai Gun match setup (who picked which fighter) from the character
## select screen into the arena, plus the result of the last match.

const STOCKS_PER_FIGHTER := 5
const MAX_PLAYERS := 3

## Each entry: { "player_index": int (0..2, controls prefix), "fighter_index": int, "is_cpu": bool }
var selections: Array[Dictionary] = []
var last_winner: Dictionary = {}


func set_selections(new_selections: Array[Dictionary]) -> void:
	selections = new_selections.duplicate(true)
	last_winner = {}


func has_valid_match() -> bool:
	return selections.size() >= 2


func clear() -> void:
	selections.clear()
	last_winner = {}


## Display colour for a participant: humans reuse the Party Rush player colours,
## CPUs get a neutral grey so their tag reads as "not a person".
func participant_color(selection: Dictionary) -> Color:
	if selection.get("is_cpu", false):
		return Color(0.75, 0.75, 0.8)
	return GameState.PLAYER_COLORS[int(selection.get("player_index", 0)) % GameState.PLAYER_COLORS.size()]


func participant_tag(selection: Dictionary) -> String:
	if selection.get("is_cpu", false):
		return "CPU"
	return "P%d" % (int(selection.get("player_index", 0)) + 1)
