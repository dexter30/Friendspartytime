class_name PlayerController
extends CharacterBody3D

signal player_tagged(other: PlayerController)
signal reached_goal
signal dashed
signal landed(impact_speed: float)

const MOVE_SPEED := 7.0
const GROUND_ACCELERATION := 42.0
const GROUND_DECELERATION := 34.0
const AIR_CONTROL := 0.6
const ROTATION_SPEED := 14.0

const JUMP_VELOCITY := 9.5
## Releasing jump early multiplies upward velocity by this — enables short hops.
const JUMP_CUT_MULTIPLIER := 0.4
const GRAVITY := 22.0
const FALL_GRAVITY_MULTIPLIER := 1.4
const MAX_FALL_SPEED := 32.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12

const DASH_SPEED := 20.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 0.65
const DASH_GHOST_INTERVAL := 0.035

const BUMP_FORCE := 4.0
const STUN_DURATION := 0.6

## Speed bonus for the player who is "it" in tag.
const IT_SPEED_MULTIPLIER := 1.15

const LEAN_ANGLE := 0.2
const RUN_BOB_SPEED := 15.0
const RUN_BOB_HEIGHT := 0.07
const IDLE_BREATH_AMOUNT := 0.02
const LAND_DUST_MIN_SPEED := 5.0

@export var player_index: int = 0

var is_active := true
var is_it := false
var has_bomb := false
var is_stunned := false
var can_move := true
var goal_reached := false
var is_dashing := false
var speed_multiplier := 1.0

var _stun_timer := 0.0
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _ghost_timer := 0.0
var _dash_direction := Vector3.FORWARD
var _air_dash_available := true
var _jump_held_since_takeoff := false
var _run_phase := 0.0
var _idle_time := 0.0

var _squash_tween: Tween
var _flash_tween: Tween
var _body_material: StandardMaterial3D
var _dash_smoke: CPUParticles3D
var _land_dust: CPUParticles3D
var _run_dust: CPUParticles3D

@onready var _visuals: Node3D = $Visuals
@onready var _body: MeshInstance3D = $Visuals/Body
@onready var _label: Label3D = $NameLabel
@onready var _indicator: MeshInstance3D = $Indicator


func _ready() -> void:
	add_to_group("players")
	collision_layer = 2
	collision_mask = 1 | 2
	_apply_color()
	_update_label()
	_create_particles()
	_update_indicator()


func setup(index: int, spawn_position: Vector3) -> void:
	player_index = index
	global_position = spawn_position
	_apply_color()
	_update_label()
	reset_state()


func reset_state() -> void:
	is_active = true
	is_it = false
	has_bomb = false
	is_stunned = false
	can_move = true
	goal_reached = false
	is_dashing = false
	speed_multiplier = 1.0
	_stun_timer = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_dash_timer = 0.0
	_dash_cooldown_timer = 0.0
	_air_dash_available = true
	_jump_held_since_takeoff = false
	velocity = Vector3.ZERO
	if _squash_tween:
		_squash_tween.kill()
	if _flash_tween:
		_flash_tween.kill()
	if _visuals:
		_visuals.scale = Vector3.ONE
		_visuals.position = Vector3.ZERO
		_visuals.rotation = Vector3.ZERO
		_set_visual_transparency(0.0)
	if _dash_smoke:
		_dash_smoke.emitting = false
	if _run_dust:
		_run_dust.emitting = false
	_update_indicator()


func set_can_move(value: bool) -> void:
	can_move = value
	if not can_move:
		velocity.x = 0.0
		velocity.z = 0.0
		if is_dashing:
			_end_dash()
		if _run_dust:
			_run_dust.emitting = false


func _action(suffix: String) -> String:
	return "p%d_%s" % [player_index + 1, suffix]


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	_tick_timers(delta)

	if is_stunned or not can_move or goal_reached:
		_decelerate(delta, GROUND_DECELERATION)
		_apply_gravity(delta)
		_move()
		return

	if is_dashing:
		_process_dash(delta)
		_move()
		_check_player_collisions()
		return

	var move_input := Input.get_vector(
		_action("left"), _action("right"), _action("forward"), _action("back")
	)
	var direction := _camera_relative_direction(move_input)
	var has_input := direction.length_squared() > 0.01

	if has_input:
		var target_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, ROTATION_SPEED * delta)

	var control := 1.0 if is_on_floor() else AIR_CONTROL
	var target_velocity := direction * MOVE_SPEED * speed_multiplier
	var rate := (GROUND_ACCELERATION if has_input else GROUND_DECELERATION) * control
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)

	if is_on_floor():
		_coyote_timer = COYOTE_TIME
		_air_dash_available = true

	if Input.is_action_just_pressed(_action("jump")):
		_jump_buffer_timer = JUMP_BUFFER_TIME

	_apply_gravity(delta)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_jump()
	elif _jump_held_since_takeoff and velocity.y > 0.0 and not Input.is_action_pressed(_action("jump")):
		velocity.y *= JUMP_CUT_MULTIPLIER
		_jump_held_since_takeoff = false

	if Input.is_action_just_pressed(_action("dash")) and _dash_cooldown_timer <= 0.0:
		if is_on_floor() or _air_dash_available:
			var dash_dir := direction if has_input else -global_transform.basis.z
			_start_dash(dash_dir)

	_move()
	_check_player_collisions()


func _process(delta: float) -> void:
	if not is_active or _visuals == null:
		return
	_update_body_animation(delta)
	_update_indicator_animation(delta)


func _tick_timers(delta: float) -> void:
	_coyote_timer -= delta
	_jump_buffer_timer -= delta
	_dash_cooldown_timer -= delta
	if is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			is_stunned = false


func _move() -> void:
	var impact_speed := -velocity.y
	var was_on_floor := is_on_floor()
	move_and_slide()
	if is_on_floor() and not was_on_floor:
		_on_landed(impact_speed)


func _decelerate(delta: float, rate: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, rate * delta)
	velocity.z = move_toward(velocity.z, 0.0, rate * delta)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
		return
	var gravity := GRAVITY * (FALL_GRAVITY_MULTIPLIER if velocity.y < 0.0 else 1.0)
	velocity.y = maxf(velocity.y - gravity * delta, -MAX_FALL_SPEED)


func _camera_relative_direction(move_input: Vector2) -> Vector3:
	if move_input.length_squared() < 0.01:
		return Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(move_input.x, 0.0, move_input.y).normalized()
	var cam_basis := camera.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (right * move_input.x + forward * -move_input.y).normalized() * minf(move_input.length(), 1.0)


func _jump() -> void:
	velocity.y = JUMP_VELOCITY
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_jump_held_since_takeoff = true
	_play_squash(Vector3(0.78, 1.32, 0.78), 0.3)
	_land_dust.restart()


func _on_landed(impact_speed: float) -> void:
	_jump_held_since_takeoff = false
	var strength := clampf(impact_speed / 18.0, 0.15, 1.0)
	_play_squash(Vector3(1.0 + 0.32 * strength, 1.0 - 0.3 * strength, 1.0 + 0.32 * strength), 0.32)
	if impact_speed > LAND_DUST_MIN_SPEED:
		_land_dust.restart()
	landed.emit(impact_speed)


func _start_dash(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = Vector3.FORWARD
	_dash_direction = direction.normalized()
	is_dashing = true
	_dash_timer = DASH_DURATION
	_dash_cooldown_timer = DASH_COOLDOWN
	_ghost_timer = 0.0
	if not is_on_floor():
		_air_dash_available = false
	rotation.y = atan2(-_dash_direction.x, -_dash_direction.z)
	velocity = _dash_direction * DASH_SPEED
	_dash_smoke.emitting = true
	_run_dust.emitting = false
	_play_squash(Vector3(0.72, 0.72, 1.45), 0.24)
	dashed.emit()


func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	velocity.x = _dash_direction.x * DASH_SPEED
	velocity.z = _dash_direction.z * DASH_SPEED
	velocity.y = 0.0

	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_spawn_ghost()
		_ghost_timer = DASH_GHOST_INTERVAL

	if is_on_floor() and Input.is_action_just_pressed(_action("jump")):
		_end_dash()
		_jump()
		return

	if _dash_timer <= 0.0:
		_end_dash()


func _end_dash() -> void:
	if not is_dashing:
		return
	is_dashing = false
	_dash_smoke.emitting = false
	velocity.x = _dash_direction.x * MOVE_SPEED
	velocity.z = _dash_direction.z * MOVE_SPEED


func _spawn_ghost() -> void:
	var ghost := MeshInstance3D.new()
	ghost.mesh = _body.mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = GameState.PLAYER_COLORS[player_index].lightened(0.2)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.material_override = material
	ghost.transparency = 0.45
	get_parent().add_child(ghost)
	ghost.global_transform = _body.global_transform
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "transparency", 1.0, 0.25)
	tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.8, 0.25)
	tween.tween_callback(ghost.queue_free)


func _check_player_collisions() -> void:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is PlayerController and collider != self:
			player_tagged.emit(collider)


func apply_bump(from: Vector3) -> void:
	if is_stunned:
		return
	if is_dashing:
		_end_dash()
	var push_dir := (global_position - from).normalized()
	push_dir.y = 0.2
	velocity += push_dir * BUMP_FORCE
	is_stunned = true
	_stun_timer = STUN_DURATION
	_play_squash(Vector3(1.25, 0.78, 1.25), 0.35)


func set_is_it(value: bool) -> void:
	is_it = value
	speed_multiplier = IT_SPEED_MULTIPLIER if value else 1.0
	_update_indicator()
	if value:
		_play_squash(Vector3(0.85, 1.2, 0.85), 0.3)


## Teleports the player (e.g. after falling off) and flashes them so the drop-in is readable.
func respawn_at(spawn_position: Vector3) -> void:
	if is_dashing:
		_end_dash()
	is_stunned = false
	_stun_timer = 0.0
	_jump_held_since_takeoff = false
	global_position = spawn_position
	velocity = Vector3.ZERO
	_play_squash(Vector3(0.7, 1.4, 0.7), 0.45)
	_flash()


func _flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_set_visual_transparency(0.0)
	_flash_tween = create_tween().set_loops(5)
	_flash_tween.tween_method(_set_visual_transparency, 0.0, 0.8, 0.1)
	_flash_tween.tween_method(_set_visual_transparency, 0.8, 0.0, 0.1)


func _set_visual_transparency(value: float) -> void:
	for child in _visuals.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).transparency = value


func set_has_bomb(value: bool) -> void:
	has_bomb = value
	_update_indicator()
	if value:
		_play_squash(Vector3(1.15, 0.85, 1.15), 0.3)


func mark_goal_reached() -> void:
	if goal_reached:
		return
	goal_reached = true
	can_move = false
	if is_dashing:
		_end_dash()
	_play_squash(Vector3(0.8, 1.35, 0.8), 0.5)
	reached_goal.emit()


func _play_squash(target: Vector3, duration: float) -> void:
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(_visuals, "scale", target, 0.06).set_trans(Tween.TRANS_SINE)
	_squash_tween.tween_property(_visuals, "scale", Vector3.ONE, duration) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _update_body_animation(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var speed_ratio := clampf(horizontal_speed / (MOVE_SPEED * speed_multiplier), 0.0, 1.5)

	var target_lean := -LEAN_ANGLE * speed_ratio
	if is_dashing:
		target_lean = -LEAN_ANGLE * 2.2
	_visuals.rotation.x = lerpf(_visuals.rotation.x, target_lean, 10.0 * delta)

	var grounded_running := is_on_floor() and speed_ratio > 0.2 and not is_dashing and can_move and not is_stunned
	if grounded_running:
		_run_phase += delta * RUN_BOB_SPEED * maxf(speed_ratio, 0.5)
		_visuals.position.y = absf(sin(_run_phase)) * RUN_BOB_HEIGHT * speed_ratio
		_visuals.rotation.z = sin(_run_phase) * 0.05 * speed_ratio
	else:
		_visuals.position.y = lerpf(_visuals.position.y, 0.0, 12.0 * delta)
		_visuals.rotation.z = lerpf(_visuals.rotation.z, 0.0, 12.0 * delta)
	_run_dust.emitting = grounded_running and speed_ratio > 0.5

	var squash_active := _squash_tween != null and _squash_tween.is_running()
	if not squash_active:
		var target_scale := Vector3.ONE
		if is_on_floor():
			_idle_time += delta
			var breath := sin(_idle_time * 3.0) * IDLE_BREATH_AMOUNT * (1.0 - minf(speed_ratio, 1.0))
			target_scale = Vector3(1.0 - breath, 1.0 + breath, 1.0 - breath)
		else:
			var vertical := clampf(absf(velocity.y) / JUMP_VELOCITY, 0.0, 1.0)
			target_scale = Vector3(1.0 - vertical * 0.12, 1.0 + vertical * 0.18, 1.0 - vertical * 0.12)
		_visuals.scale = _visuals.scale.lerp(target_scale, 8.0 * delta)


func _update_indicator_animation(delta: float) -> void:
	if not _indicator.visible:
		return
	_indicator.position.y = 2.5 + sin(Time.get_ticks_msec() * 0.005) * 0.12
	_indicator.rotation.y += delta * 2.0


func _create_particles() -> void:
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = 0.16
	puff_mesh.height = 0.32
	puff_mesh.radial_segments = 8
	puff_mesh.rings = 4
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.vertex_color_use_as_albedo = true
	puff_material.albedo_color = Color(0.92, 0.92, 0.95)
	puff_mesh.material = puff_material

	_dash_smoke = _make_emitter(puff_mesh, 28, 0.5, false)
	_dash_smoke.direction = Vector3(0.0, 0.35, 1.0)
	_dash_smoke.spread = 22.0
	_dash_smoke.initial_velocity_min = 2.5
	_dash_smoke.initial_velocity_max = 4.5
	_dash_smoke.gravity = Vector3(0.0, 1.2, 0.0)
	_dash_smoke.scale_amount_min = 0.7
	_dash_smoke.scale_amount_max = 1.4
	_dash_smoke.position = Vector3(0.0, 0.35, 0.3)

	_land_dust = _make_emitter(puff_mesh, 18, 0.45, true)
	_land_dust.direction = Vector3.UP
	_land_dust.spread = 75.0
	_land_dust.initial_velocity_min = 2.0
	_land_dust.initial_velocity_max = 4.0
	_land_dust.gravity = Vector3(0.0, -3.0, 0.0)
	_land_dust.scale_amount_min = 0.5
	_land_dust.scale_amount_max = 1.1
	_land_dust.position = Vector3(0.0, 0.1, 0.0)

	_run_dust = _make_emitter(puff_mesh, 10, 0.35, false)
	_run_dust.direction = Vector3(0.0, 0.6, 1.0)
	_run_dust.spread = 30.0
	_run_dust.initial_velocity_min = 0.8
	_run_dust.initial_velocity_max = 1.6
	_run_dust.gravity = Vector3(0.0, 0.5, 0.0)
	_run_dust.scale_amount_min = 0.25
	_run_dust.scale_amount_max = 0.5
	_run_dust.position = Vector3(0.0, 0.1, 0.25)


func _make_emitter(mesh: Mesh, amount: int, lifetime: float, one_shot: bool) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.mesh = mesh
	emitter.amount = amount
	emitter.lifetime = lifetime
	emitter.one_shot = one_shot
	emitter.explosiveness = 1.0 if one_shot else 0.05
	emitter.emitting = false
	emitter.local_coords = false
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.25
	emitter.damping_min = 2.0
	emitter.damping_max = 4.0
	emitter.angular_velocity_min = -90.0
	emitter.angular_velocity_max = 90.0

	var size_curve := Curve.new()
	size_curve.add_point(Vector2(0.0, 0.55))
	size_curve.add_point(Vector2(0.25, 1.0))
	size_curve.add_point(Vector2(1.0, 0.0))
	emitter.scale_amount_curve = size_curve

	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.85))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	emitter.color_ramp = fade

	add_child(emitter)
	return emitter


func _apply_color() -> void:
	if _body == null:
		return
	if _body_material == null:
		_body_material = StandardMaterial3D.new()
		_body_material.roughness = 0.45
		_body_material.metallic = 0.05
		_body.material_override = _body_material
	_body_material.albedo_color = GameState.PLAYER_COLORS[player_index]


func _update_label() -> void:
	if _label == null:
		return
	_label.text = GameState.PLAYER_NAMES[player_index]
	_label.modulate = GameState.PLAYER_COLORS[player_index].lightened(0.3)


func _update_indicator() -> void:
	if _indicator == null:
		return
	if has_bomb:
		_indicator.visible = true
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.2, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.3, 0.1)
		mat.emission_energy_multiplier = 2.0
		_indicator.material_override = mat
	elif is_it:
		_indicator.visible = true
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 1.0, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 1.0, 0.4)
		mat.emission_energy_multiplier = 1.5
		_indicator.material_override = mat
	else:
		_indicator.visible = false
