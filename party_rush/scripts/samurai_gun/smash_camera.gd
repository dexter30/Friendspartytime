class_name SmashCamera2D
extends Camera2D

@export var min_zoom := Vector2(0.55, 0.55)
@export var max_zoom := Vector2(1.15, 1.15)
@export var padding := Vector2(280, 200)
@export var follow_smoothing := 4.5
@export var zoom_smoothing := 3.5

var fighters: Array[Node2D] = []
var _trauma := 0.0
var _shake_offset := Vector2.ZERO


func set_fighters(fighter_nodes: Array) -> void:
	fighters.clear()
	for node in fighter_nodes:
		if node is Node2D:
			fighters.append(node)


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if fighters.is_empty():
		return

	var alive: Array[Node2D] = []
	for f in fighters:
		if is_instance_valid(f) and f.visible:
			alive.append(f)

	if alive.is_empty():
		return

	var min_pos := alive[0].global_position
	var max_pos := alive[0].global_position
	for f in alive:
		min_pos = min_pos.min(f.global_position)
		max_pos = max_pos.max(f.global_position)

	var center := (min_pos + max_pos) * 0.5
	var viewport_size := get_viewport_rect().size
	var span := max_pos - min_pos + padding
	var zoom_x := viewport_size.x / span.x
	var zoom_y := viewport_size.y / span.y
	var target_zoom_value := clampf(minf(zoom_x, zoom_y), min_zoom.x, max_zoom.x)
	var target_zoom := Vector2.ONE * target_zoom_value

	global_position = global_position.lerp(center, 1.0 - exp(-follow_smoothing * delta))
	zoom = zoom.lerp(target_zoom, 1.0 - exp(-zoom_smoothing * delta))

	if _trauma > 0.0:
		_trauma = maxf(_trauma - delta * 1.8, 0.0)
		var shake_amount := _trauma * _trauma * 18.0
		_shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
	else:
		_shake_offset = Vector2.ZERO

	offset = _shake_offset
