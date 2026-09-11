class_name ArenaCamera
extends Camera3D

## Fixed isometric-style camera. Frames the whole minigame map from a constant
## pitch/yaw so every player is always on screen; recomputes on viewport resize.

@export var pitch_degrees: float = 52.0
@export var yaw_degrees: float = 45.0
## Extra room around the map bounds (1.0 = exact fit).
@export var margin: float = 1.08
@export var use_orthographic: bool = false
@export var transition_time: float = 0.7
@export var shake_strength: float = 0.35

var _bounds: AABB = AABB()
var _has_bounds: bool = false
var _trauma: float = 0.0
var _transition: Tween


func _ready() -> void:
	current = true
	fov = 45.0
	get_viewport().size_changed.connect(_reframe.bind(false))


## Position the camera so the given world-space bounds fill the view.
func frame_bounds(bounds: AABB, animate: bool = true) -> void:
	_bounds = bounds
	_has_bounds = true
	_reframe(animate)


## Adds screen shake; stacks up to 1.0 and decays over time.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _reframe(animate: bool) -> void:
	if not _has_bounds:
		return

	var basis := Basis.from_euler(Vector3(deg_to_rad(-pitch_degrees), deg_to_rad(yaw_degrees), 0.0))
	var inverse := basis.inverse()
	var center := _bounds.get_center()

	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var half_v := deg_to_rad(fov) * 0.5
	var half_h := atan(tan(half_v) * aspect)

	var max_x := 0.0
	var max_y := 0.0
	var max_z := -INF
	var required_distance := 0.0
	for i in range(8):
		var local := inverse * (_bounds.get_endpoint(i) - center)
		max_x = maxf(max_x, absf(local.x))
		max_y = maxf(max_y, absf(local.y))
		max_z = maxf(max_z, local.z)
		# Distance along the view axis needed for this corner to sit inside both frustum planes.
		required_distance = maxf(required_distance, local.z + absf(local.x) / tan(half_h))
		required_distance = maxf(required_distance, local.z + absf(local.y) / tan(half_v))

	var distance: float
	if use_orthographic:
		projection = PROJECTION_ORTHOGONAL
		size = maxf(max_y * 2.0, max_x * 2.0 / aspect) * margin
		distance = max_z + 40.0
	else:
		projection = PROJECTION_PERSPECTIVE
		distance = required_distance * margin

	var target := Transform3D(basis, center + basis.z * distance)

	if _transition:
		_transition.kill()
	if animate and is_inside_tree():
		var from := global_transform
		_transition = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_transition.tween_method(
			func(t: float) -> void: global_transform = from.interpolate_with(target, t),
			0.0, 1.0, transition_time
		)
	else:
		global_transform = target


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		h_offset = 0.0
		v_offset = 0.0
		return
	_trauma = maxf(_trauma - delta * 1.8, 0.0)
	var shake := _trauma * _trauma * shake_strength
	var t := Time.get_ticks_msec() * 0.001
	h_offset = sin(t * 47.0) * shake
	v_offset = cos(t * 53.0) * shake
