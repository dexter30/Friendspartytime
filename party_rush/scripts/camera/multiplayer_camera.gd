class_name MultiplayerCamera
extends Camera3D

## Lego-style third-person camera: follows the midpoint of all players,
## pulls back when they spread apart, and orbits slightly behind their average heading.

@export var base_distance: float = 14.0
@export var min_distance: float = 10.0
@export var max_distance: float = 26.0
@export var base_height: float = 7.0
@export var look_ahead: float = 3.0
@export var follow_speed: float = 5.0
@export var rotation_speed: float = 3.0
@export var spread_multiplier: float = 0.85

var _target_players: Array[Node3D] = []
var _smoothed_center: Vector3 = Vector3.ZERO
var _smoothed_distance: float = base_distance
var _current_yaw: float = 0.0


func _ready() -> void:
	fov = 65.0
	current = true


func set_targets(players: Array) -> void:
	_target_players.clear()
	for p in players:
		if p is Node3D:
			_target_players.append(p)


func _physics_process(delta: float) -> void:
	var active_players: Array[Node3D] = []
	for p in _target_players:
		if is_instance_valid(p) and p.visible:
			active_players.append(p)

	if active_players.is_empty():
		return

	var center := Vector3.ZERO
	var avg_forward := Vector3.ZERO
	for p in active_players:
		center += p.global_position
		var forward := -p.global_transform.basis.z
		forward.y = 0.0
		if forward.length() > 0.01:
			avg_forward += forward.normalized()

	center /= float(active_players.size())

	if avg_forward.length() < 0.01:
		avg_forward = Vector3(0.0, 0.0, -1.0)
	else:
		avg_forward = avg_forward.normalized()

	var max_spread := 0.0
	for p in active_players:
		var dist := p.global_position.distance_to(center)
		max_spread = maxf(max_spread, dist)

	var target_distance := clampf(
		base_distance + max_spread * spread_multiplier,
		min_distance,
		max_distance
	)

	var target_yaw := atan2(avg_forward.x, avg_forward.z)

	if _smoothed_center == Vector3.ZERO:
		_smoothed_center = center
		_smoothed_distance = target_distance
		_current_yaw = target_yaw
	else:
		_smoothed_center = _smoothed_center.lerp(center, follow_speed * delta)
		_smoothed_distance = lerpf(_smoothed_distance, target_distance, follow_speed * delta)
		_current_yaw = lerp_angle(_current_yaw, target_yaw, rotation_speed * delta)

	var offset := Vector3(
		sin(_current_yaw) * _smoothed_distance,
		base_height,
		cos(_current_yaw) * _smoothed_distance
	)

	var look_target := _smoothed_center + avg_forward * look_ahead
	look_target.y += 1.5

	global_position = _smoothed_center + offset
	look_at(look_target, Vector3.UP)
