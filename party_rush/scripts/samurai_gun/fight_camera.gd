class_name FightCamera
extends Camera2D

## Smash-style side-view camera: keeps every living fighter in frame by panning to
## their midpoint and zooming to fit their spread, clamped so the blast zones never
## show. Smoothed with exponential easing and supports trauma-based shake.

## Most zoomed-out the camera may go (smaller = wider view).
@export var min_zoom: float = 0.62
## Most zoomed-in the camera may go.
@export var max_zoom: float = 1.35
## Padding around the fighters' bounding box, in world pixels.
@export var margin: Vector2 = Vector2(300.0, 240.0)
## The framed box never shrinks below this size so a lone fighter isn't giant.
@export var min_frame_size: Vector2 = Vector2(760.0, 460.0)
@export var position_smoothing: float = 6.0
@export var zoom_smoothing: float = 4.0
@export var shake_strength: float = 26.0

var bounds: Rect2 = Rect2(-1000.0, -800.0, 2000.0, 1400.0)
var targets: Array[Node2D] = []

var _trauma := 0.0
var _target_position := Vector2.ZERO
var _target_zoom := 1.0


func _ready() -> void:
	make_current()
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Jump straight to the ideal framing (used at match start).
func snap() -> void:
	_compute_target()
	global_position = _target_position
	zoom = Vector2.ONE * _target_zoom


func _physics_process(delta: float) -> void:
	_compute_target()
	var t := 1.0 - exp(-position_smoothing * delta)
	global_position = global_position.lerp(_target_position, t)
	var z := 1.0 - exp(-zoom_smoothing * delta)
	var new_zoom := lerpf(zoom.x, _target_zoom, z)
	zoom = Vector2.ONE * new_zoom

	if _trauma > 0.0:
		_trauma = maxf(_trauma - delta * 2.2, 0.0)
		var shake := _trauma * _trauma * shake_strength / new_zoom
		var time := Time.get_ticks_msec() * 0.001
		offset = Vector2(sin(time * 61.0) * shake, cos(time * 73.0) * shake)
	else:
		offset = Vector2.ZERO


func _compute_target() -> void:
	var viewport_size := get_viewport_rect().size
	var rect := Rect2()
	var found := false
	for target in targets:
		if target == null or not is_instance_valid(target) or not target.visible:
			continue
		var fighter := target as Fighter
		if fighter and (fighter.state == Fighter.State.KO):
			continue
		var p := target.global_position
		p.x = clampf(p.x, bounds.position.x, bounds.end.x)
		p.y = clampf(p.y, bounds.position.y, bounds.end.y)
		if not found:
			rect = Rect2(p, Vector2.ZERO)
			found = true
		else:
			rect = rect.expand(p)
	if not found:
		rect = Rect2(bounds.get_center() - Vector2(0.0, 80.0), Vector2.ZERO)

	rect = rect.grow_individual(margin.x, margin.y, margin.x, margin.y * 0.8)
	if rect.size.x < min_frame_size.x:
		var grow := (min_frame_size.x - rect.size.x) * 0.5
		rect = rect.grow_individual(grow, 0.0, grow, 0.0)
	if rect.size.y < min_frame_size.y:
		var grow := (min_frame_size.y - rect.size.y) * 0.5
		rect = rect.grow_individual(0.0, grow, 0.0, grow)

	var fit_zoom := minf(viewport_size.x / rect.size.x, viewport_size.y / rect.size.y)
	_target_zoom = clampf(fit_zoom, min_zoom, max_zoom)

	var half_view := viewport_size / _target_zoom * 0.5
	var center := rect.get_center()
	if bounds.size.x <= half_view.x * 2.0:
		center.x = bounds.get_center().x
	else:
		center.x = clampf(center.x, bounds.position.x + half_view.x, bounds.end.x - half_view.x)
	if bounds.size.y <= half_view.y * 2.0:
		center.y = bounds.get_center().y
	else:
		center.y = clampf(center.y, bounds.position.y + half_view.y, bounds.end.y - half_view.y)
	_target_position = center
