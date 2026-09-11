class_name Fighter
extends CharacterBody2D

## A Samurai Gun combatant. Movement is platform-fighter style (run, double jump,
## short hops, fast fall, drop-through platforms). Attacks are just Light (katana)
## and Heavy (gun) with up/down variants; damage is a rising percent and knockback
## scales with it until a fighter flies past the blast zone and loses a stock.

signal damaged(victim: Fighter, attacker: Fighter, amount: float, at: Vector2, knockback: float)
signal knocked_out(fighter: Fighter)
signal attack_started(fighter: Fighter, move_name: String)

enum State { FREE, ATTACK, HITSTUN, KO, REVIVAL }

const GRAVITY := 2100.0
const FALL_GRAVITY_MULTIPLIER := 1.2
const MAX_FALL_SPEED := 950.0
const FAST_FALL_SPEED := 1250.0
const AIR_SPEED_FACTOR := 0.9
const GROUND_ACCEL := 3600.0
const AIR_ACCEL := 1700.0
const GROUND_FRICTION := 2800.0
const AIR_FRICTION := 260.0
const AIR_JUMP_FACTOR := 0.94
const JUMP_CUT_MULTIPLIER := 0.45
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.1
const DROP_THROUGH_TIME := 0.28
const HITSTUN_PER_KNOCKBACK := 0.00062
const MIN_HITSTUN := 0.16
const MAX_HITSTUN := 1.5
const LAUNCH_TRAIL_SPEED := 720.0
const COMBO_WINDOW := 0.4
const CHARGE_MAX := 0.6
const CHARGE_BONUS := 0.55
const LANDING_LAG := 0.1
const REVIVAL_HOVER_TIME := 2.5
const POST_REVIVAL_INTANGIBLE := 1.6
const BASE_RADIUS := 30.0
const SOFT_PLATFORM_LAYER := 16

## Every attack the fighters share. Offsets/sizes are in pixels for a size-1.0 fighter and
## are expressed in facing space (positive x = forward). Angles: 0 = forward, 90 = up, 270 = spike.
const MOVES: Dictionary = {
	"light_1": {
		"startup": 0.05, "active": 0.09, "endlag": 0.13,
		"damage": 4.0, "base_kb": 190.0, "kb_growth": 3.2, "angle": 42.0, "hitstop": 0.045,
		"offset": Vector2(40.0, -4.0), "size": Vector2(72.0, 50.0),
		"slash": [80.0, -35.0], "slash_radius": 66.0, "lunge": 110.0,
	},
	"light_2": {
		"startup": 0.05, "active": 0.09, "endlag": 0.14,
		"damage": 4.0, "base_kb": 200.0, "kb_growth": 3.2, "angle": 50.0, "hitstop": 0.045,
		"offset": Vector2(42.0, -6.0), "size": Vector2(74.0, 52.0),
		"slash": [-55.0, 60.0], "slash_radius": 68.0, "lunge": 110.0,
	},
	"light_3": {
		"startup": 0.08, "active": 0.1, "endlag": 0.24,
		"damage": 7.0, "base_kb": 330.0, "kb_growth": 7.6, "angle": 38.0, "hitstop": 0.075,
		"offset": Vector2(48.0, -4.0), "size": Vector2(88.0, 56.0),
		"slash": [120.0, -40.0], "slash_radius": 80.0, "lunge": 190.0,
	},
	"light_up": {
		"startup": 0.06, "active": 0.1, "endlag": 0.17,
		"damage": 6.0, "base_kb": 270.0, "kb_growth": 6.8, "angle": 84.0, "hitstop": 0.05,
		"offset": Vector2(8.0, -48.0), "size": Vector2(84.0, 58.0),
		"slash": [-20.0, 175.0], "slash_radius": 70.0, "drift": 0.6,
	},
	"light_down": {
		"startup": 0.07, "active": 0.1, "endlag": 0.19,
		"damage": 5.0, "base_kb": 240.0, "kb_growth": 6.0, "angle": 26.0, "hitstop": 0.05,
		"offset": Vector2(36.0, 22.0), "size": Vector2(86.0, 32.0),
		"slash": [-75.0, 15.0], "slash_radius": 64.0, "lunge": 60.0,
	},
	"light_air": {
		"startup": 0.06, "active": 0.12, "endlag": 0.14,
		"damage": 6.0, "base_kb": 260.0, "kb_growth": 6.6, "angle": 45.0, "hitstop": 0.05,
		"offset": Vector2(30.0, 0.0), "size": Vector2(86.0, 74.0),
		"slash": [130.0, -70.0], "slash_radius": 72.0, "drift": 0.75,
	},
	"light_air_down": {
		"startup": 0.09, "active": 0.12, "endlag": 0.2,
		"damage": 7.0, "base_kb": 250.0, "kb_growth": 6.2, "angle": 270.0, "hitstop": 0.07,
		"offset": Vector2(6.0, 46.0), "size": Vector2(64.0, 62.0),
		"slash": [-150.0, -30.0], "slash_radius": 68.0, "drift": 0.5, "self_velocity": Vector2(0.0, 220.0),
	},
	"heavy": {
		"startup": 0.2, "active": 0.05, "endlag": 0.32,
		"damage": 13.0, "base_kb": 430.0, "kb_growth": 13.5, "angle": 35.0, "hitstop": 0.11,
		"offset": Vector2(44.0, -8.0), "size": Vector2(38.0, 28.0),
		"bullet": Vector2(1.0, 0.0), "bullet_speed": 1500.0, "bullet_range": 300.0,
		"recoil": Vector2(-280.0, 0.0), "chargeable": true, "drift": 0.35,
	},
	"heavy_up": {
		"startup": 0.2, "active": 0.05, "endlag": 0.32,
		"damage": 12.0, "base_kb": 410.0, "kb_growth": 13.0, "angle": 88.0, "hitstop": 0.1,
		"offset": Vector2(8.0, -46.0), "size": Vector2(30.0, 38.0),
		"bullet": Vector2(0.0, -1.0), "bullet_speed": 1500.0, "bullet_range": 280.0,
		"recoil": Vector2(0.0, 200.0), "recoil_air_only": true, "chargeable": true, "drift": 0.35,
	},
	"heavy_air_down": {
		"startup": 0.17, "active": 0.05, "endlag": 0.26,
		"damage": 12.0, "base_kb": 380.0, "kb_growth": 12.0, "angle": 270.0, "hitstop": 0.1,
		"offset": Vector2(4.0, 46.0), "size": Vector2(30.0, 38.0),
		"bullet": Vector2(0.0, 1.0), "bullet_speed": 1500.0, "bullet_range": 260.0,
		"recoil": Vector2(0.0, -560.0), "chargeable": false, "drift": 0.5,
	},
	"heavy_down": {
		"startup": 0.22, "active": 0.08, "endlag": 0.34,
		"damage": 12.0, "base_kb": 390.0, "kb_growth": 11.5, "angle": 72.0, "hitstop": 0.1,
		"offset": Vector2(0.0, 22.0), "size": Vector2(170.0, 54.0),
		"shockwave": true, "chargeable": true,
	},
}

var player_index: int = 0
var is_cpu: bool = false
var fighter_data: Dictionary = {}
var selection: Dictionary = {}
var brain: CpuBrain = null
## Node that receives world-space spawns (bullets, effects). Set by the arena.
var world_node: Node = null

var state: State = State.FREE
var percent: float = 0.0
var stocks: int = SamuraiGunState.STOCKS_PER_FIGHTER
var facing: int = 1
var controls_enabled: bool = true
var weight: float = 100.0
var run_speed: float = 330.0
var jump_force: float = 850.0
var size_scale: float = 1.0
var body_half_width: float = 22.0

var input_move: Vector2 = Vector2.ZERO
var input_jump_pressed: bool = false
var input_jump_held: bool = false
var input_light_pressed: bool = false
var input_heavy_pressed: bool = false
var input_heavy_held: bool = false
var input_down_pressed: bool = false

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _jumps_left := 1
var _jump_cut_ready := false
var _fast_falling := false
var _drop_through_timer := 0.0
var _hitstop_timer := 0.0
var _hitstun_timer := 0.0
var _intangible_timer := 0.0
var _revival_timer := 0.0
var _combo_timer := 0.0
var _combo_step := -1
## Attack pressed during endlag is queued so mashing chains cleanly.
var _buffered_attack := ""
var _buffer_timer := 0.0

var _attack: Dictionary = {}
var _attack_name := ""
var _attack_time := 0.0
var _attack_aerial := false
var _attack_hit_spawned := false
var _attack_released := false
var _attack_landed := false
var _charge := 0.0

var _visuals: Node2D
var _visual: FighterVisual
var _tag: Node2D
var _tag_label: Label
var _revival_platform: Node2D
var _launch_trail: CPUParticles2D
var _squash_tween: Tween
var _tumble := 0.0
var _run_phase := 0.0

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _hurt_shape: CollisionShape2D = $Hurtbox/CollisionShape2D


func _ready() -> void:
	add_to_group("fighters")
	collision_layer = 2
	collision_mask = 1 | SOFT_PLATFORM_LAYER
	floor_snap_length = 8.0
	_build_visuals()
	if fighter_data.is_empty():
		setup({"player_index": 0, "fighter_index": 0, "is_cpu": false}, FighterRoster.get_fighter(0))
	_apply_data()


func setup(new_selection: Dictionary, data: Dictionary) -> void:
	selection = new_selection
	fighter_data = data
	player_index = int(new_selection.get("player_index", 0))
	is_cpu = bool(new_selection.get("is_cpu", false))
	weight = data.get("weight", 100.0)
	run_speed = data.get("run_speed", 330.0)
	jump_force = data.get("jump_force", 660.0)
	size_scale = data.get("size", 1.0)
	body_half_width = 22.0 * size_scale
	stocks = SamuraiGunState.STOCKS_PER_FIGHTER
	percent = 0.0
	if is_cpu:
		brain = CpuBrain.new(self)
	if is_node_ready():
		_apply_data()


func _apply_data() -> void:
	_visual.set_fighter(fighter_data)
	_visual.radius = BASE_RADIUS * size_scale
	_collision.shape = _collision.shape.duplicate()
	(_collision.shape as RectangleShape2D).size = Vector2(44.0, 58.0) * size_scale
	_hurt_shape.shape = _hurt_shape.shape.duplicate()
	(_hurt_shape.shape as RectangleShape2D).size = Vector2(54.0, 66.0) * size_scale
	_tag_label.text = SamuraiGunState.participant_tag(selection)
	var tag_color := SamuraiGunState.participant_color(selection)
	_tag_label.add_theme_color_override("font_color", tag_color)
	(_tag.get_node("Arrow") as Polygon2D).color = tag_color
	_launch_trail.color = fighter_color().lightened(0.3)


func _build_visuals() -> void:
	_visuals = Node2D.new()
	_visuals.name = "Visuals"
	add_child(_visuals)
	_visual = FighterVisual.new()
	_visual.name = "Body"
	_visuals.add_child(_visual)

	_tag = Node2D.new()
	_tag.name = "Tag"
	add_child(_tag)
	_tag_label = Label.new()
	_tag_label.name = "Label"
	_tag_label.add_theme_font_size_override("font_size", 16)
	_tag_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.06))
	_tag_label.add_theme_constant_override("outline_size", 6)
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_label.size = Vector2(60.0, 22.0)
	_tag_label.position = Vector2(-30.0, -22.0)
	_tag.add_child(_tag_label)
	var arrow := Polygon2D.new()
	arrow.name = "Arrow"
	arrow.polygon = PackedVector2Array([Vector2(-7.0, 0.0), Vector2(7.0, 0.0), Vector2(0.0, 8.0)])
	_tag.add_child(arrow)

	_revival_platform = Node2D.new()
	_revival_platform.name = "RevivalPlatform"
	_revival_platform.visible = false
	var disc := Polygon2D.new()
	var disc_points := PackedVector2Array()
	for i in range(24):
		var a := i * TAU / 24.0
		disc_points.append(Vector2(cos(a) * 62.0, 34.0 + sin(a) * 10.0))
	disc.polygon = disc_points
	disc.color = Color(0.85, 0.95, 1.0, 0.75)
	_revival_platform.add_child(disc)
	var disc_rim := Line2D.new()
	disc_rim.points = disc_points
	disc_rim.closed = true
	disc_rim.width = 3.0
	disc_rim.default_color = Color(0.4, 0.85, 1.0, 0.9)
	_revival_platform.add_child(disc_rim)
	add_child(_revival_platform)

	_launch_trail = CPUParticles2D.new()
	_launch_trail.emitting = false
	_launch_trail.amount = 26
	_launch_trail.lifetime = 0.4
	_launch_trail.local_coords = false
	_launch_trail.spread = 25.0
	_launch_trail.initial_velocity_min = 20.0
	_launch_trail.initial_velocity_max = 60.0
	_launch_trail.scale_amount_min = 4.0
	_launch_trail.scale_amount_max = 9.0
	_launch_trail.gravity = Vector2.ZERO
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 0.8))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	_launch_trail.color_ramp = fade
	_launch_trail.z_index = -1
	add_child(_launch_trail)


func fighter_color() -> Color:
	return fighter_data.get("color", Color.WHITE)


func fighter_name() -> String:
	return fighter_data.get("name", "Fighter")


func is_eliminated() -> bool:
	return stocks <= 0


func is_alive() -> bool:
	return state != State.KO and stocks > 0


func can_be_hit() -> bool:
	return state != State.KO and state != State.REVIVAL and _intangible_timer <= 0.0 and visible


func is_intangible() -> bool:
	return _intangible_timer > 0.0 or state == State.REVIVAL


func attack_progress() -> Dictionary:
	return {"name": _attack_name, "time": _attack_time, "charge": _charge / CHARGE_MAX}


func _action(suffix: String) -> String:
	return "p%d_%s" % [player_index + 1, suffix]


func _physics_process(delta: float) -> void:
	if state == State.KO:
		return
	_gather_input(delta)
	_tick_timers(delta)

	if _hitstop_timer > 0.0:
		_hitstop_timer -= delta
		return

	match state:
		State.REVIVAL:
			_process_revival()
		State.HITSTUN:
			_process_hitstun(delta)
		State.ATTACK:
			_process_attack(delta)
		State.FREE:
			_process_free(delta)

	_separate_from_others(delta)
	var was_on_floor := is_on_floor()
	var fall_speed := velocity.y
	move_and_slide()
	if is_on_floor() and not was_on_floor:
		_on_landed(fall_speed)


func _gather_input(delta: float) -> void:
	input_move = Vector2.ZERO
	input_jump_pressed = false
	input_jump_held = false
	input_light_pressed = false
	input_heavy_pressed = false
	input_heavy_held = false
	input_down_pressed = false
	if not controls_enabled:
		return
	if is_cpu:
		if brain:
			brain.think(delta)
		return
	input_move = Input.get_vector(_action("left"), _action("right"), _action("forward"), _action("back"))
	input_jump_pressed = Input.is_action_just_pressed(_action("jump"))
	input_jump_held = Input.is_action_pressed(_action("jump"))
	input_light_pressed = Input.is_action_just_pressed(_action("light"))
	input_heavy_pressed = Input.is_action_just_pressed(_action("heavy"))
	input_heavy_held = Input.is_action_pressed(_action("heavy"))
	input_down_pressed = Input.is_action_just_pressed(_action("back"))


func _tick_timers(delta: float) -> void:
	_coyote_timer -= delta
	_jump_buffer_timer -= delta
	_combo_timer -= delta
	_buffer_timer -= delta
	if _buffer_timer <= 0.0:
		_buffered_attack = ""
	if _intangible_timer > 0.0 and state != State.REVIVAL:
		_intangible_timer -= delta
	if _drop_through_timer > 0.0:
		_drop_through_timer -= delta
		if _drop_through_timer <= 0.0:
			collision_mask |= SOFT_PLATFORM_LAYER


# --- Free movement -----------------------------------------------------------------

func _process_free(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote_timer = COYOTE_TIME
		_jumps_left = 1
		_fast_falling = false

	if absf(input_move.x) > 0.2:
		facing = 1 if input_move.x > 0.0 else -1

	_apply_horizontal(delta, input_move.x, 1.0)

	if input_jump_pressed:
		_jump_buffer_timer = JUMP_BUFFER_TIME
	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0:
			_jump(false)
		elif _jumps_left > 0:
			_jump(true)
	elif _jump_cut_ready and velocity.y < 0.0 and not input_jump_held:
		velocity.y *= JUMP_CUT_MULTIPLIER
		_jump_cut_ready = false

	if on_floor and input_down_pressed and _standing_on_soft_platform():
		_drop_through()
	elif not on_floor and input_move.y > 0.5 and velocity.y > -60.0 and not _fast_falling:
		_fast_falling = true
		velocity.y = maxf(velocity.y, FAST_FALL_SPEED * 0.75)
		_play_squash(Vector2(0.8, 1.25), 0.2)

	_apply_gravity(delta)

	if input_light_pressed:
		_start_attack(_pick_light_move())
	elif input_heavy_pressed:
		_start_attack(_pick_heavy_move())


func _apply_horizontal(delta: float, input_x: float, control: float) -> void:
	var on_floor := is_on_floor()
	var max_speed := run_speed if on_floor else run_speed * AIR_SPEED_FACTOR
	var friction := GROUND_FRICTION if on_floor else AIR_FRICTION
	if absf(input_x) > 0.1 and control > 0.0:
		var target := input_x * max_speed * control
		var same_direction := signf(target) == signf(velocity.x)
		if same_direction and absf(velocity.x) > absf(target):
			# Already moving faster than run speed (launch/recoil): bleed it off gently.
			velocity.x = move_toward(velocity.x, target, friction * 0.5 * delta)
		else:
			var accel := (GROUND_ACCEL if on_floor else AIR_ACCEL) * control
			velocity.x = move_toward(velocity.x, target, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var gravity := GRAVITY * (FALL_GRAVITY_MULTIPLIER if velocity.y > 0.0 else 1.0)
	var max_fall := FAST_FALL_SPEED if _fast_falling else MAX_FALL_SPEED
	velocity.y = minf(velocity.y + gravity * delta, max_fall)


func _jump(is_air_jump: bool) -> void:
	velocity.y = -jump_force * (AIR_JUMP_FACTOR if is_air_jump else 1.0)
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_jump_cut_ready = true
	_fast_falling = false
	if is_air_jump:
		_jumps_left -= 1
		# Air jumps can reverse momentum so recovery feels responsive.
		if absf(input_move.x) > 0.2 and signf(input_move.x) != signf(velocity.x):
			velocity.x *= 0.25
		FightFx.spawn(_fx_parent(), FightFx.Kind.RING, global_position + Vector2(0.0, 26.0 * size_scale), fighter_color().lightened(0.4), 26.0, 0.22)
	else:
		FightFx.spawn_burst_particles(_fx_parent(), global_position + Vector2(0.0, 28.0 * size_scale), Color(0.9, 0.9, 0.95), 6, 120.0, 0.35, 300.0)
	_play_squash(Vector2(0.74, 1.32), 0.3)


func _on_landed(fall_speed: float) -> void:
	_jump_cut_ready = false
	_fast_falling = false
	var strength := clampf(fall_speed / 1100.0, 0.15, 1.0)
	if state == State.HITSTUN:
		if fall_speed > 520.0:
			# Slammed into the floor: bounce back up and keep tumbling.
			velocity.y = -fall_speed * 0.5
			FightFx.spawn_burst_particles(_fx_parent(), global_position + Vector2(0.0, 28.0 * size_scale), Color(0.9, 0.9, 0.95), 14, 260.0, 0.4, 500.0)
			_play_squash(Vector2(1.4, 0.6), 0.35)
			return
		_hitstun_timer = minf(_hitstun_timer, 0.18)
	elif state == State.ATTACK and _attack_aerial and not _attack_landed:
		_attack_landed = true
		_clear_hitboxes()
		var total: float = _attack["startup"] + _attack["active"] + _attack["endlag"]
		_attack_time = maxf(_attack_time, total - LANDING_LAG)
		_attack_released = true
	_play_squash(Vector2(1.0 + 0.34 * strength, 1.0 - 0.3 * strength), 0.3)
	if fall_speed > 380.0:
		FightFx.spawn_burst_particles(_fx_parent(), global_position + Vector2(0.0, 28.0 * size_scale), Color(0.9, 0.9, 0.95), 8, 150.0 * strength + 60.0, 0.35, 400.0)


func _standing_on_soft_platform() -> bool:
	for i in range(get_slide_collision_count()):
		var collider := get_slide_collision(i).get_collider()
		if collider is Node and (collider as Node).is_in_group("soft_platform"):
			return true
	return false


func _drop_through() -> void:
	collision_mask &= ~SOFT_PLATFORM_LAYER
	_drop_through_timer = DROP_THROUGH_TIME
	velocity.y = maxf(velocity.y, 120.0)
	_coyote_timer = 0.0
	_play_squash(Vector2(0.86, 1.14), 0.2)


# --- Attacks ------------------------------------------------------------------------

func _pick_light_move() -> String:
	var on_floor := is_on_floor()
	if input_move.y < -0.5:
		return "light_up"
	if input_move.y > 0.5:
		return "light_down" if on_floor else "light_air_down"
	if not on_floor:
		return "light_air"
	var step := 0
	if _combo_timer > 0.0 and _combo_step >= 0:
		step = (_combo_step + 1) % 3
	_combo_step = step
	return "light_%d" % (step + 1)


func _pick_heavy_move() -> String:
	if input_move.y < -0.5:
		return "heavy_up"
	if input_move.y > 0.5:
		return "heavy_down" if is_on_floor() else "heavy_air_down"
	return "heavy"


func _start_attack(move_name: String) -> void:
	_attack = MOVES[move_name]
	_attack_name = move_name
	_attack_time = 0.0
	_attack_aerial = not is_on_floor()
	_attack_hit_spawned = false
	_attack_released = false
	_attack_landed = false
	_charge = 0.0
	state = State.ATTACK
	if absf(input_move.x) > 0.2:
		facing = 1 if input_move.x > 0.0 else -1
	_visual.expression = "attack"
	if _attack.has("bullet") or _attack.has("shockwave"):
		# Wind-up: crouch back before the shot.
		_play_squash(Vector2(1.14, 0.86), 0.25)
	else:
		_play_squash(Vector2(0.9, 1.1), 0.12)
	if not move_name in ["light_1", "light_2", "light_3"]:
		_combo_step = -1
	attack_started.emit(self, move_name)


func _process_attack(delta: float) -> void:
	var on_floor := is_on_floor()
	var drift: float = _attack.get("drift", 0.0)
	if on_floor:
		velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)
	else:
		_apply_horizontal(delta, input_move.x, drift)
	_apply_gravity(delta)

	var startup: float = _attack["startup"]
	var active: float = _attack["active"]
	var endlag: float = _attack["endlag"]

	if _attack.get("chargeable", false) and not _attack_released and _attack_time >= startup:
		if input_heavy_held and _charge < CHARGE_MAX:
			_charge = minf(_charge + delta, CHARGE_MAX)
			_visual.charge = _charge / CHARGE_MAX
			return
		_attack_released = true

	_attack_time += delta
	if not _attack_hit_spawned and _attack_time >= startup:
		_attack_hit_spawned = true
		_spawn_attack_hitbox()
	if _attack_time >= startup + active:
		if input_light_pressed:
			_buffered_attack = "light"
			_buffer_timer = 0.25
		elif input_heavy_pressed:
			_buffered_attack = "heavy"
			_buffer_timer = 0.25
	if _attack_time >= startup + active + endlag:
		_end_attack()


func _spawn_attack_hitbox() -> void:
	var data := _attack.duplicate()
	var charge_ratio := _charge / CHARGE_MAX
	var multiplier := 1.0 + charge_ratio * CHARGE_BONUS
	data["damage"] = float(data["damage"]) * multiplier
	data["base_kb"] = float(data["base_kb"]) * multiplier
	data["hitstop"] = float(data["hitstop"]) * (1.0 + charge_ratio * 0.4)
	var offset: Vector2 = data["offset"] * size_scale
	offset.x *= facing
	var size: Vector2 = data["size"] * size_scale
	_visual.charge = 0.0
	var color := fighter_color()

	if data.has("bullet"):
		var direction: Vector2 = data["bullet"]
		direction.x *= facing
		var hitbox := Hitbox.new()
		hitbox.configure(self, data, size, facing)
		hitbox.make_bullet(direction, data["bullet_speed"], float(data["bullet_range"]) * (1.0 + charge_ratio * 0.35))
		_fx_parent().add_child(hitbox)
		hitbox.global_position = global_position + offset
		var muzzle := FightFx.spawn(_fx_parent(), FightFx.Kind.MUZZLE, global_position + offset, color, 26.0 + charge_ratio * 14.0, 0.12)
		muzzle.rotation = direction.angle()
		FightFx.spawn_burst_particles(_fx_parent(), global_position + offset, Color(1.0, 0.85, 0.5), 8, 240.0, 0.25, 0.0)
		var recoil: Vector2 = data.get("recoil", Vector2.ZERO)
		if not (data.get("recoil_air_only", false) and is_on_floor()):
			recoil.x *= facing
			if recoil.y < 0.0:
				velocity.y = recoil.y
				_fast_falling = false
			else:
				velocity.y += recoil.y
			velocity.x += recoil.x
		_play_squash(Vector2(1.3 if direction.x != 0.0 else 0.8, 0.78 if direction.x != 0.0 else 1.3), 0.3)
		return

	var hitbox := Hitbox.new()
	hitbox.configure(self, data, size, facing)
	add_child(hitbox)
	hitbox.position = offset

	if data.has("shockwave"):
		var feet := global_position + Vector2(0.0, 26.0 * size_scale)
		FightFx.spawn(_fx_parent(), FightFx.Kind.MUZZLE, feet, color, 22.0, 0.1)
		var wave := FightFx.spawn(_fx_parent(), FightFx.Kind.SHOCKWAVE, feet, color, 60.0 * size_scale + charge_ratio * 30.0, 0.3)
		wave.scale = Vector2(1.6, 1.0)
		FightFx.spawn_burst_particles(_fx_parent(), feet, Color(0.85, 0.85, 0.9), 18, 320.0, 0.45, 700.0)
		_play_squash(Vector2(1.35, 0.7), 0.35)
		return

	if data.has("slash"):
		var arc: Array = data["slash"]
		var pivot := global_position + Vector2(offset.x * 0.25, offset.y * 0.35)
		FightFx.spawn_slash(_fx_parent(), pivot, color, float(data["slash_radius"]) * size_scale, arc[0], arc[1], facing)
	if data.has("lunge") and is_on_floor():
		velocity.x += float(data["lunge"]) * facing
	if data.has("self_velocity"):
		velocity += data["self_velocity"]
	_play_squash(Vector2(1.18, 0.9), 0.18)


func _end_attack() -> void:
	if _attack_name in ["light_1", "light_2"]:
		_combo_timer = COMBO_WINDOW
	else:
		_combo_timer = 0.0
		_combo_step = -1
	_attack = {}
	_attack_name = ""
	_charge = 0.0
	_visual.charge = 0.0
	_visual.expression = "normal"
	state = State.FREE
	if _buffered_attack != "":
		var queued := _buffered_attack
		_buffered_attack = ""
		if absf(input_move.x) > 0.2:
			facing = 1 if input_move.x > 0.0 else -1
		_start_attack(_pick_light_move() if queued == "light" else _pick_heavy_move())


func _cancel_attack() -> void:
	_clear_hitboxes()
	_attack = {}
	_attack_name = ""
	_charge = 0.0
	_visual.charge = 0.0
	_combo_timer = 0.0
	_combo_step = -1
	_buffered_attack = ""


func _clear_hitboxes() -> void:
	for child in get_children():
		if child is Hitbox:
			child.queue_free()


# --- Getting hit --------------------------------------------------------------------

func take_hit(hitbox: Hitbox, attacker: Fighter) -> void:
	if not can_be_hit():
		return
	if state == State.ATTACK:
		_cancel_attack()

	percent += hitbox.damage
	var knockback := (hitbox.base_knockback + percent * hitbox.knockback_growth) * (100.0 / weight)
	var direction := hitbox.launch_direction()
	velocity = direction * knockback
	if is_on_floor() and velocity.y > 0.0:
		# Spiked while standing on the ground: bounce up instead of clipping into the floor.
		velocity.y = -absf(velocity.y) * 0.85
	if velocity.y > -140.0 and knockback > 260.0:
		velocity.y = minf(velocity.y, -140.0)

	_hitstun_timer = clampf(knockback * HITSTUN_PER_KNOCKBACK, MIN_HITSTUN, MAX_HITSTUN)
	_hitstop_timer = hitbox.hitstop
	if attacker:
		attacker.apply_hitstop(hitbox.hitstop * 0.85)
	state = State.HITSTUN
	_fast_falling = false
	_jumps_left = 1
	if absf(direction.x) > 0.05:
		facing = -1 if direction.x > 0.0 else 1

	_visual.flash = 1.0
	_visual.expression = "hurt"
	_launch_trail.emitting = knockback > LAUNCH_TRAIL_SPEED
	_play_squash(Vector2(1.35, 0.68), 0.4)

	var hit_at := (global_position + hitbox.global_position) * 0.5
	damaged.emit(self, attacker, hitbox.damage, hit_at, knockback)


func apply_hitstop(duration: float) -> void:
	_hitstop_timer = maxf(_hitstop_timer, duration)


func _process_hitstun(delta: float) -> void:
	_hitstun_timer -= delta
	var friction := GROUND_FRICTION * 0.9 if is_on_floor() else AIR_FRICTION * 0.6
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	_apply_gravity(delta)
	if velocity.length() < LAUNCH_TRAIL_SPEED:
		_launch_trail.emitting = false
	if _hitstun_timer <= 0.0:
		state = State.FREE
		_visual.expression = "normal"
		_launch_trail.emitting = false


# --- Stocks / KO / revival ----------------------------------------------------------

func knock_out() -> void:
	if state == State.KO:
		return
	_cancel_attack()
	state = State.KO
	stocks -= 1
	velocity = Vector2.ZERO
	_hitstop_timer = 0.0
	_hitstun_timer = 0.0
	_launch_trail.emitting = false
	visible = false
	knocked_out.emit(self)


func begin_revival(at: Vector2) -> void:
	state = State.REVIVAL
	global_position = at
	velocity = Vector2.ZERO
	percent = 0.0
	visible = true
	modulate.a = 1.0
	_revival_timer = REVIVAL_HOVER_TIME
	_intangible_timer = POST_REVIVAL_INTANGIBLE
	_jumps_left = 1
	_fast_falling = false
	_visuals.rotation = 0.0
	_visuals.scale = Vector2.ONE
	_visual.expression = "normal"
	_revival_platform.visible = true
	_revival_platform.modulate.a = 1.0
	FightFx.spawn(_fx_parent(), FightFx.Kind.RING, at, Color(0.6, 0.9, 1.0), 50.0, 0.4)


func _process_revival() -> void:
	_revival_timer -= get_physics_process_delta_time()
	velocity = Vector2.ZERO
	var wants_out := absf(input_move.x) > 0.3 or input_move.y > 0.5 or input_jump_pressed or input_light_pressed or input_heavy_pressed
	if wants_out or _revival_timer <= 0.0:
		_leave_revival()


func _leave_revival() -> void:
	state = State.FREE
	_intangible_timer = POST_REVIVAL_INTANGIBLE
	var platform := _revival_platform
	var tween := platform.create_tween()
	tween.tween_property(platform, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void: platform.visible = false)


# --- Presentation -------------------------------------------------------------------

func _process(delta: float) -> void:
	if _visual == null:
		return
	_update_look_target()
	_visual.facing = facing
	_update_body_animation(delta)
	_update_tag(delta)
	if is_intangible():
		var pulse := 0.5 + 0.5 * absf(sin(Time.get_ticks_msec() * 0.02))
		modulate.a = 0.45 + 0.5 * pulse
	else:
		modulate.a = 1.0


func _update_look_target() -> void:
	var nearest: Fighter = null
	var best := INF
	for node in get_tree().get_nodes_in_group("fighters"):
		var other := node as Fighter
		if other == null or other == self or not other.visible or other.state == State.KO:
			continue
		var d := global_position.distance_squared_to(other.global_position)
		if d < best:
			best = d
			nearest = other
	if nearest:
		_visual.look_direction = (nearest.global_position - global_position).normalized()
	else:
		_visual.look_direction = Vector2(facing, 0.0)


func _update_body_animation(delta: float) -> void:
	if state == State.HITSTUN and velocity.length() > 380.0:
		_tumble += delta * velocity.length() * 0.012 * -facing
		_visuals.rotation = _tumble
	else:
		_tumble = 0.0
		_visuals.rotation = lerp_angle(_visuals.rotation, 0.0, 14.0 * delta)

	var speed_ratio := clampf(absf(velocity.x) / maxf(run_speed, 1.0), 0.0, 1.4)
	var grounded_running := is_on_floor() and speed_ratio > 0.2 and state == State.FREE
	var target_skew := 0.0
	if grounded_running:
		_run_phase += delta * 18.0 * maxf(speed_ratio, 0.5)
		_visuals.position.y = -absf(sin(_run_phase)) * 4.0 * speed_ratio
		target_skew = -signf(velocity.x) * 0.14 * speed_ratio
	else:
		_visuals.position.y = lerpf(_visuals.position.y, 0.0, 12.0 * delta)
	if state == State.ATTACK and _attack.has("bullet"):
		target_skew = -facing * 0.08
	_visuals.skew = lerpf(_visuals.skew, target_skew, 10.0 * delta)

	if _hitstop_timer > 0.0 and state == State.HITSTUN:
		_visuals.position.x = randf_range(-3.0, 3.0)
	elif state == State.ATTACK and _charge > 0.0:
		_visuals.position.x = randf_range(-1.5, 1.5) * (_charge / CHARGE_MAX)
	else:
		_visuals.position.x = 0.0

	var squash_active := _squash_tween != null and _squash_tween.is_running()
	if not squash_active:
		var target_scale := Vector2.ONE
		if not is_on_floor() and state == State.FREE:
			var vertical := clampf(absf(velocity.y) / jump_force, 0.0, 1.0)
			target_scale = Vector2(1.0 - vertical * 0.1, 1.0 + vertical * 0.16)
		_visuals.scale = _visuals.scale.lerp(target_scale, 9.0 * delta)


func _update_tag(delta: float) -> void:
	var bob := sin(Time.get_ticks_msec() * 0.006) * 3.0
	_tag.position = Vector2(0.0, -BASE_RADIUS * size_scale - 34.0 + bob)
	_tag.visible = state != State.KO
	_tag.rotation = 0.0
	_tag.modulate.a = lerpf(_tag.modulate.a, 1.0, 5.0 * delta)


func _play_squash(target: Vector2, duration: float) -> void:
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(_visuals, "scale", target, 0.05).set_trans(Tween.TRANS_SINE)
	_squash_tween.tween_property(_visuals, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _separate_from_others(delta: float) -> void:
	if not is_on_floor() or state == State.HITSTUN or state == State.REVIVAL:
		return
	for node in get_tree().get_nodes_in_group("fighters"):
		var other := node as Fighter
		if other == null or other == self or not other.visible or not other.is_on_floor():
			continue
		if other.state == State.KO or other.state == State.REVIVAL:
			continue
		if absf(global_position.y - other.global_position.y) > 40.0:
			continue
		var dx := global_position.x - other.global_position.x
		var overlap := (body_half_width + other.body_half_width) - absf(dx)
		if overlap > 0.0:
			var push := 1.0 if dx >= 0.0 else -1.0
			if dx == 0.0:
				push = 1.0 if player_index % 2 == 0 else -1.0
			global_position.x += push * minf(overlap, 160.0 * delta)


func _fx_parent() -> Node:
	if world_node and is_instance_valid(world_node):
		return world_node
	return get_parent()
