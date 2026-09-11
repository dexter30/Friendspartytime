class_name MinigameBase
extends Node3D

signal minigame_finished(winner_index: int, message: String)

@export var countdown_seconds: float = 3.0
@export var round_duration: float = 60.0
## Players below this height are considered fallen and get respawned.
@export var fall_y: float = -6.0
## How high above the spawn point a fallen player is dropped back in.
@export var respawn_drop_height: float = 5.0
## Optional explicit camera bounds; when empty, bounds are computed from level meshes.
@export var bounds_override: AABB = AABB()

var players: Array[PlayerController] = []
var is_running: bool = false
var is_finished: bool = false

@onready var _spawn_points: Node3D = $SpawnPoints


func _ready() -> void:
	add_to_group("minigame")


func _physics_process(_delta: float) -> void:
	if is_finished:
		return
	for player in players:
		if player.global_position.y < fall_y:
			respawn_player(player)


func setup_round(spawned_players: Array[PlayerController]) -> void:
	players = spawned_players
	is_running = false
	is_finished = false
	for i in range(players.size()):
		var spawn := _get_spawn_position(i)
		players[i].setup(i, spawn)
		players[i].reset_state()
		players[i].set_can_move(false)
		_connect_player(players[i])


func start_round() -> void:
	is_running = true
	for player in players:
		player.set_can_move(true)


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


## Drops the player back in above their spawn point with a flashing effect.
func respawn_player(player: PlayerController) -> void:
	if is_finished:
		return
	var spawn := _get_spawn_position(player.player_index) + Vector3(0.0, respawn_drop_height, 0.0)
	player.respawn_at(spawn)


## World-space box enclosing every visible mesh in the level (plus moving-platform travel),
## padded so jumping players stay in frame.
func get_map_bounds() -> AABB:
	if bounds_override.size.length_squared() > 0.0:
		return bounds_override

	var result := AABB()
	var found := false
	for node in find_children("*", "VisualInstance3D", true, false):
		var visual := node as VisualInstance3D
		if not visual.is_visible_in_tree():
			continue
		var world_aabb: AABB = visual.global_transform * visual.get_aabb()
		result = world_aabb if not found else result.merge(world_aabb)
		found = true
		var mover := visual.get_parent() as MovingPlatform
		if mover:
			var travelled := world_aabb
			travelled.position += mover.move_offset
			result = result.merge(travelled)

	if not found:
		result = AABB(Vector3(-15.0, -1.0, -15.0), Vector3(30.0, 8.0, 30.0))

	result = result.grow(1.5)
	result.size.y += 3.0
	return result
