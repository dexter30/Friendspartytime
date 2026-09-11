class_name MinigameBase
extends Node3D

signal minigame_finished(winner_index: int, message: String)

@export var countdown_seconds: float = 3.0
@export var round_duration: float = 60.0

var players: Array[PlayerController] = []
var is_running: bool = false
var is_finished: bool = false

@onready var _spawn_points: Node3D = $SpawnPoints
@onready var _hud_message: String = ""


func _ready() -> void:
	add_to_group("minigame")


func setup_round(spawned_players: Array[PlayerController]) -> void:
	players = spawned_players
	is_running = false
	is_finished = false
	for i in range(players.size()):
		var spawn := _get_spawn_position(i)
		players[i].setup(i, spawn)
		players[i].reset_state()
		_connect_player(players[i])


func start_round() -> void:
	is_running = true


func end_round(winner_index: int, message: String) -> void:
	if is_finished:
		return
	is_finished = true
	is_running = false
	for player in players:
		player.set_can_move(false)
	minigame_finished.emit(winner_index, message)


func _get_spawn_position(index: int) -> Vector3:
	if _spawn_points == null:
		return Vector3(index * 3.0, 1.0, 0.0)
	var child_count := _spawn_points.get_child_count()
	if index < child_count:
		return _spawn_points.get_child(index).global_position
	return _spawn_points.global_position + Vector3(index * 3.0, 1.0, 0.0)


func _connect_player(_player: PlayerController) -> void:
	pass


func respawn_player(player: PlayerController) -> void:
	if is_finished:
		return
	player.global_position = _get_spawn_position(player.player_index)
	player.velocity = Vector3.ZERO
	player.reset_state()


func get_camera_targets() -> Array:
	return players
