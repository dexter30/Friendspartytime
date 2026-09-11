class_name SamuraiFighter
extends CharacterBody2D

signal stocks_changed(stocks_left: int)
signal damage_changed(percent: float)
signal fighter_koed()
signal respawned()
signal attack_landed(is_heavy: bool)

const GRAVITY := 1900.0
const MOVE_SPEED := 340.0
const AIR_CONTROL := 0.82
const JUMP_VELOCITY := -560.0
const MAX_FALL := 980.0
const STOCK_COUNT := 5
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12

const LIGHT_DAMAGE := 4.0
const LIGHT_KB := 220.0
const LIGHT_KB_SCALE := 2.8
const HEAVY_DAMAGE := 9.0
const HEAVY_KB := 380.0
const HEAVY_KB_SCALE := 3.6

enum State { IDLE, MOVE, AIR, LIGHT, HEAVY, HITSTUN, RESPAWN, DEAD }

@onready var _visual: Node2D = $Visual
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _light_hitbox: AttackHitbox = $LightHitbox
@onready var _heavy_hitbox: AttackHitbox = $HeavyHitbox
@onready var _hurtbox: Area2D = $Hurtbox

var player_slot := 0
var fighter_id := 0
var facing := 1
var damage_percent := 0.0
var stocks := STOCK_COUNT
var can_act := false
var state := State.IDLE

var _state_timer := 0.0
var _hitstun_timer := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _was_on_floor := false
var _spawn_position := Vector2.ZERO
var _respawn_timer := 0.0
var _invuln_timer := 0.0
var _squash_tween: Tween


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_light_hitbox.owner_fighter = self
	_heavy_hitbox.owner_fighter = self
	_light_hitbox.damage = LIGHT_DAMAGE
	_light_hitbox.knockback_base = LIGHT_KB
	_light_hitbox.knockback_scaling = LIGHT_KB_SCALE
	_heavy_hitbox.damage = HEAVY_DAMAGE
	_heavy_hitbox.knockback_base = HEAVY_KB
	_heavy_hitbox.knockback_scaling = HEAVY_KB_SCALE
	_light_hitbox.hit_landed.connect(_on_own_hit_landed)
	_heavy_hitbox.hit_landed.connect(_on_own_hit_landed)
	modulate.a = 1.0


func _on_own_hit_landed(_target: Node, _damage: float, _knockback: Vector2, is_heavy: bool) -> void:
	attack_landed.emit(is_heavy)


func setup(slot: int, fighter_data_id: int, spawn_pos: Vector2) -> void:
	player_slot = slot
	fighter_id = fighter_data_id
	_spawn_position = spawn_pos
	global_position = spawn_pos
	damage_percent = 0.0
	stocks = STOCK_COUNT
	facing = 1 if slot == 0 else -1
	state = State.IDLE
	can_act = false
	_invuln_timer = 0.0
	velocity = Vector2.ZERO
	_apply_fighter_data()
	stocks_changed.emit(stocks)
	damage_changed.emit(damage_percent)


func _apply_fighter_data() -> void:
	var data := FighterData.get_fighter(fighter_id)
	if _visual.has_method("setup_from_data"):
		_visual.setup_from_data(data)


func set_can_act(value: bool) -> void:
	can_act = value
	if not value:
		_light_hitbox.deactivate()
		_heavy_hitbox.deactivate()


func get_input_prefix() -> String:
	return "p1" if player_slot == 0 else "p2"


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if state == State.RESPAWN:
		_process_respawn(delta)
		return

	_state_timer = maxf(_state_timer - delta, 0.0)
	if _invuln_timer > 0.0:
		_invuln_timer = maxf(_invuln_timer - delta, 0.0)
		modulate.a = 0.45 if int(_invuln_timer * 12.0) % 2 == 0 else 1.0
	else:
		modulate.a = 1.0

	if state == State.HITSTUN:
		_process_hitstun(delta)
		return

	if can_act:
		_read_input(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * delta * 6.0)

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	else:
		if not _was_on_floor and velocity.y > 80.0:
			_land_squash()
		_coyote = COYOTE_TIME

	_was_on_floor = is_on_floor()
	move_and_slide()

	if _visual.has_method("set_facing"):
		_visual.set_facing(facing)

	_update_hitbox_positions()


func _update_hitbox_positions() -> void:
	var light_x := 34.0
	var heavy_x := 40.0
	_light_hitbox.position.x = light_x * facing
	_heavy_hitbox.position.x = heavy_x * facing


func _read_input(delta: float) -> void:
	var prefix := get_input_prefix()
	var axis := Input.get_axis(prefix + "_left", prefix + "_right")

	if state in [State.LIGHT, State.HEAVY]:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * 0.35 * delta * 8.0)
		if _state_timer <= 0.0:
			_end_attack()
		return

	if axis != 0.0:
		facing = signi(axis)
		var speed := MOVE_SPEED if is_on_floor() else MOVE_SPEED * AIR_CONTROL
		velocity.x = axis * speed
		state = State.MOVE
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * delta * 8.0)
		if is_on_floor() and state != State.LIGHT and state != State.HEAVY:
			state = State.IDLE

	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(_coyote - delta, 0.0)

	if Input.is_action_just_pressed(prefix + "_jump"):
		_jump_buffer = JUMP_BUFFER
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)

	if _jump_buffer > 0.0 and (_coyote > 0.0 or is_on_floor()):
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		state = State.AIR
		_jump_squash()

	if Input.is_action_just_pressed(prefix + "_light") and _can_start_attack():
		_start_light_attack()
	elif Input.is_action_just_pressed(prefix + "_heavy") and _can_start_attack():
		_start_heavy_attack()


func _can_start_attack() -> bool:
	return state not in [State.LIGHT, State.HEAVY, State.HITSTUN, State.RESPAWN]


func _start_light_attack() -> void:
	state = State.LIGHT
	_state_timer = 0.34
	velocity.x *= 0.35
	if _visual.has_method("set_attack_glow"):
		_visual.set_attack_glow(0.8)
	_light_hitbox.deactivate()
	_heavy_hitbox.deactivate()
	await get_tree().create_timer(0.06).timeout
	if state == State.LIGHT:
		_light_hitbox.activate(false)
	await get_tree().create_timer(0.14).timeout
	if state == State.LIGHT:
		_light_hitbox.deactivate()


func _start_heavy_attack() -> void:
	state = State.HEAVY
	_state_timer = 0.62
	velocity.x *= 0.15
	if _visual.has_method("set_attack_glow"):
		_visual.set_attack_glow(1.0)
	_light_hitbox.deactivate()
	_heavy_hitbox.deactivate()
	await get_tree().create_timer(0.18).timeout
	if state == State.HEAVY:
		_heavy_hitbox.activate(true)
	await get_tree().create_timer(0.16).timeout
	if state == State.HEAVY:
		_heavy_hitbox.deactivate()


func _end_attack() -> void:
	_light_hitbox.deactivate()
	_heavy_hitbox.deactivate()
	state = State.AIR if not is_on_floor() else State.IDLE


func take_hit(damage: float, knockback: Vector2, is_heavy: bool, _attacker: Node2D) -> void:
	if _invuln_timer > 0.0 or state == State.RESPAWN or state == State.DEAD:
		return

	damage_percent += damage
	damage_changed.emit(damage_percent)
	state = State.HITSTUN
	_hitstun_timer = 0.28 if is_heavy else 0.16
	velocity = knockback
	_light_hitbox.deactivate()
	_heavy_hitbox.deactivate()

	if _visual.has_method("flash_hit"):
		_visual.flash_hit(1.0 if is_heavy else 0.6)

	_squash_on_hit(is_heavy)


func _process_hitstun(delta: float) -> void:
	_hitstun_timer -= delta
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	move_and_slide()
	if _hitstun_timer <= 0.0:
		state = State.AIR if not is_on_floor() else State.IDLE


func _process_respawn(delta: float) -> void:
	_respawn_timer -= delta
	global_position = _spawn_position + Vector2(0, -120)
	velocity = Vector2.ZERO
	modulate.a = 0.35 if int(_respawn_timer * 10.0) % 2 == 0 else 0.7
	if _respawn_timer <= 0.0:
		global_position = _spawn_position
		damage_percent = 0.0
		damage_changed.emit(damage_percent)
		state = State.IDLE
		_invuln_timer = 2.0
		modulate.a = 1.0
		respawned.emit()


func lose_stock() -> void:
	if state == State.DEAD:
		return
	stocks -= 1
	stocks_changed.emit(stocks)
	_light_hitbox.deactivate()
	_heavy_hitbox.deactivate()
	damage_percent = 0.0
	damage_changed.emit(damage_percent)

	if stocks <= 0:
		state = State.DEAD
		visible = false
		set_collision_layer_value(2, false)
		fighter_koed.emit()
	else:
		state = State.RESPAWN
		_respawn_timer = 1.4
		fighter_koed.emit()


func _land_squash() -> void:
	if _visual.has_method("set_squash"):
		_visual.set_squash(Vector2(1.15, 0.82))
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_method(_tween_squash, Vector2(1.15, 0.82), Vector2.ONE, 0.14)


func _jump_squash() -> void:
	if _visual.has_method("set_squash"):
		_visual.set_squash(Vector2(0.88, 1.12))
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_method(_tween_squash, Vector2(0.88, 1.12), Vector2.ONE, 0.12)


func _squash_on_hit(heavy: bool) -> void:
	var amount := Vector2(1.2, 0.78) if heavy else Vector2(1.1, 0.88)
	if _visual.has_method("set_squash"):
		_visual.set_squash(amount)
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_method(_tween_squash, amount, Vector2.ONE, 0.1)


func _tween_squash(value: Vector2) -> void:
	if _visual.has_method("set_squash"):
		_visual.set_squash(value)
