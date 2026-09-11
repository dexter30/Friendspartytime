extends MinigameBase

## First to reach the flag wins. Platforming course with gaps and moving platforms.

@onready var _flag_area: Area3D = $Flag/Area3D
@onready var _flag_mesh: MeshInstance3D = $Flag/Mesh

var _winner_claimed: bool = false


func _ready() -> void:
	round_duration = 90.0
	_flag_area.body_entered.connect(_on_flag_entered)
	_animate_flag()


func _connect_player(player: PlayerController) -> void:
	player.reached_goal.connect(_on_player_reached_goal.bind(player))


func _on_flag_entered(body: Node3D) -> void:
	if not is_running or _winner_claimed:
		return
	if body is PlayerController:
		_claim_win(body as PlayerController)


func _on_player_reached_goal(player: PlayerController) -> void:
	if not is_running or _winner_claimed:
		return
	_claim_win(player)


func _claim_win(player: PlayerController) -> void:
	_winner_claimed = true
	player.mark_goal_reached()
	end_round(player.player_index, "%s reached the flag first!" % GameState.PLAYER_NAMES[player.player_index])


func _animate_flag() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_flag_mesh, "rotation_degrees:y", 360.0, 4.0)
