extends MinigameBase

## Race across a platforming obstacle course. First to the finish line wins.

@onready var _finish_area: Area3D = $FinishLine/Area3D

var _finish_order: Array[int] = []


func _ready() -> void:
	super()
	round_duration = 120.0
	_finish_area.body_entered.connect(_on_finish_entered)


func setup_round(spawned_players: Array[PlayerController]) -> void:
	_finish_order.clear()
	super.setup_round(spawned_players)


func _connect_player(player: PlayerController) -> void:
	player.reached_goal.connect(_on_player_finished.bind(player))


func _on_finish_entered(body: Node3D) -> void:
	if not is_running:
		return
	if body is PlayerController:
		_register_finish(body as PlayerController)


func _on_player_finished(player: PlayerController) -> void:
	_register_finish(player)


func _register_finish(player: PlayerController) -> void:
	if player.goal_reached:
		return
	if player.player_index in _finish_order:
		return

	_finish_order.append(player.player_index)
	player.mark_goal_reached()

	if _finish_order.size() == 1:
		end_round(
			player.player_index,
			"%s crossed the finish line first!" % GameState.PLAYER_NAMES[player.player_index]
		)
