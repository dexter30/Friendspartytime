class_name PlayerController
extends CharacterBody3D

signal player_tagged(other: PlayerController)
signal reached_goal
signal bomb_passed(to_player: PlayerController)

const MOVE_SPEED := 7.0
const SPRINT_MULTIPLIER := 1.35
const JUMP_VELOCITY := 9.5
const GRAVITY := 22.0
const ROTATION_SPEED := 12.0
const BUMP_FORCE := 4.0
const STUN_DURATION := 0.6

@export var player_index: int = 0

var is_active: bool = true
var is_it: bool = false
var has_bomb: bool = false
var is_stunned: bool = false
var can_move: bool = true
var goal_reached: bool = false

var _stun_timer: float = 0.0
var _mesh: MeshInstance3D
var _label: Label3D
var _collision: CollisionShape3D
var _indicator: MeshInstance3D

static var _joy_deadzone := 0.25


func _ready() -> void:
	add_to_group("players")
	collision_layer = 2
	collision_mask = 1 | 2 | 3 | 4
	_mesh = $Body
	_label = $NameLabel
	_indicator = $Indicator
	_collision = $CollisionShape3D
	_apply_color()
	_update_label()


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
	_stun_timer = 0.0
	velocity = Vector3.ZERO
	_update_indicator()


func set_can_move(value: bool) -> void:
	can_move = value
	if not can_move:
		velocity.x = 0.0
		velocity.z = 0.0


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	if is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			is_stunned = false
		_apply_gravity(delta)
		move_and_slide()
		return

	if not can_move or goal_reached:
		_apply_gravity(delta)
		move_and_slide()
		return

	var input_dir := _get_move_input()
	var camera := get_viewport().get_camera_3d()
	var direction := Vector3.ZERO

	if camera:
		var cam_basis := camera.global_transform.basis
		var forward := -cam_basis.z
		var right := cam_basis.x
		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()
		direction = (right * input_dir.x + forward * -input_dir.y).normalized()
	else:
		direction = Vector3(input_dir.x, 0.0, -input_dir.y).normalized()

	var speed := MOVE_SPEED
	if input_dir.length() > 0.1:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		var target_rotation := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, ROTATION_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * 3.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED * 3.0 * delta)

	_apply_gravity(delta)

	if is_on_floor() and _is_jump_pressed():
		velocity.y = JUMP_VELOCITY

	move_and_slide()
	_check_player_collisions()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0


func _get_move_input() -> Vector2:
	var keyboard := _get_keyboard_input()
	if keyboard.length() > 0.1:
		return keyboard

	var joypads := Input.get_connected_joypads()
	if player_index < joypads.size():
		var device := joypads[player_index]
		var lx := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		var ly := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		var stick := Vector2(lx, ly)
		if stick.length() > _joy_deadzone:
			return stick.normalized() * minf(stick.length(), 1.0)

	return Vector2.ZERO


func _get_keyboard_input() -> Vector2:
	match player_index:
		0:
			return Input.get_vector("p1_left", "p1_right", "p1_forward", "p1_back")
		1:
			return Input.get_vector("p2_left", "p2_right", "p2_forward", "p2_back")
		2:
			return Input.get_vector("p3_left", "p3_right", "p3_forward", "p3_back")
	return Vector2.ZERO


func _is_jump_pressed() -> bool:
	match player_index:
		0:
			return Input.is_action_just_pressed("p1_jump")
		1:
			return Input.is_action_just_pressed("p2_jump")
		2:
			return Input.is_action_just_pressed("p3_jump")

	var joypads := Input.get_connected_joypads()
	if player_index < joypads.size():
		return Input.is_joy_button_pressed(joypads[player_index], JOY_BUTTON_A)

	return false


func _check_player_collisions() -> void:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is PlayerController and collider != self:
			player_tagged.emit(collider)


func apply_bump(from: Vector3) -> void:
	if is_stunned:
		return
	var push_dir := (global_position - from).normalized()
	push_dir.y = 0.2
	velocity += push_dir * BUMP_FORCE
	is_stunned = true
	_stun_timer = STUN_DURATION


func set_is_it(value: bool) -> void:
	is_it = value
	_update_indicator()


func set_has_bomb(value: bool) -> void:
	has_bomb = value
	_update_indicator()


func mark_goal_reached() -> void:
	if goal_reached:
		return
	goal_reached = true
	can_move = false
	reached_goal.emit()


func _apply_color() -> void:
	var color := GameState.PLAYER_COLORS[player_index]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.45
	material.metallic = 0.05
	_mesh.material_override = material


func _update_label() -> void:
	_label.text = GameState.PLAYER_NAMES[player_index]
	_label.modulate = GameState.PLAYER_COLORS[player_index].lightened(0.3)


func _update_indicator() -> void:
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
