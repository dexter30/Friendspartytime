class_name CpuBrain
extends RefCounted

## Lightweight opponent AI for Samurai Gun. Chases the nearest fighter, swings when in
## range, mixes in gun shots at high percents, and recovers back to the stage when
## knocked off. Decisions are re-rolled on a short timer so it feels a bit human.

var fighter: Fighter
## Stage geometry supplied by the arena.
var stage_half_width: float = 480.0
var floor_y: float = 200.0
var revival_y: float = -260.0

var _decision_timer := 0.0
var _move_x := 0.0
var _attack_cooldown := 0.0
var _hold_heavy_timer := 0.0
var _gun_jump_cooldown := 0.0
var _aggression := 0.5


func _init(owner: Fighter) -> void:
	fighter = owner
	_aggression = randf_range(0.4, 0.75)


func think(delta: float) -> void:
	_decision_timer -= delta
	_attack_cooldown -= delta
	_hold_heavy_timer -= delta
	_gun_jump_cooldown -= delta

	var target := _nearest_opponent()
	var pos := fighter.global_position
	var on_floor := fighter.is_on_floor()

	if fighter.state == Fighter.State.REVIVAL:
		if fighter._revival_timer < 1.6:
			fighter.input_move.x = -signf(pos.x) if absf(pos.x) > 1.0 else 1.0
		return

	var off_stage := absf(pos.x) > stage_half_width - 20.0 or pos.y > floor_y + 40.0
	if off_stage:
		_recover(pos, on_floor)
		return

	if target == null:
		fighter.input_move.x = 0.0
		return

	var to_target := target.global_position - pos
	var dx := to_target.x
	var dy := to_target.y
	var reach := 78.0 * fighter.size_scale

	if _decision_timer <= 0.0:
		_decision_timer = randf_range(0.12, 0.3)
		var preferred_gap := reach * 0.75
		if fighter.percent > 90.0 and randf() < 0.3:
			preferred_gap = 220.0
		if absf(dx) > preferred_gap:
			_move_x = signf(dx)
		elif absf(dx) < preferred_gap * 0.6 and randf() < 0.35:
			_move_x = -signf(dx) * 0.7
		else:
			_move_x = 0.0
		if randf() < 0.08:
			_move_x = 0.0

	fighter.input_move.x = _move_x
	if _hold_heavy_timer > 0.0:
		fighter.input_heavy_held = true

	# Don't run off the stage while chasing.
	var next_x := pos.x + _move_x * 60.0
	if absf(next_x) > stage_half_width - 40.0 and not (on_floor and pos.y < floor_y - 60.0):
		fighter.input_move.x = 0.0

	var in_horizontal_range := absf(dx) < reach + 20.0
	var target_above := dy < -70.0
	var target_below := dy > 70.0

	if on_floor and target_above and absf(dx) < 200.0 and randf() < 0.05:
		fighter.input_jump_pressed = true
	elif not on_floor and target_above and dy < -140.0 and fighter._jumps_left > 0 and randf() < 0.04:
		fighter.input_jump_pressed = true
	if not on_floor and target_below and randf() < 0.06:
		fighter.input_move.y = 1.0
	if on_floor and dy > 110.0 and randf() < 0.04:
		# Standing on a platform above the target: drop through it (or walk off the edge).
		fighter.input_down_pressed = true
		fighter.input_move.y = 1.0
		if absf(dx) < 30.0:
			_move_x = 1.0 if randf() < 0.5 else -1.0

	if fighter.state != Fighter.State.FREE or _attack_cooldown > 0.0:
		return

	if in_horizontal_range and absf(dy) < 60.0:
		if randf() < _aggression:
			_attack_cooldown = randf_range(0.1, 0.35)
			if target.percent > 70.0 and randf() < 0.45:
				_press_heavy(0.0, randf_range(0.0, 0.45))
			elif randf() < 0.12:
				_press_heavy(0.0, 0.0)
			else:
				fighter.input_light_pressed = true
				fighter.facing = 1 if dx > 0.0 else -1
	elif in_horizontal_range and target_above and dy > -150.0:
		if randf() < _aggression * 0.8:
			_attack_cooldown = randf_range(0.15, 0.4)
			fighter.input_move.y = -1.0
			if target.percent > 80.0 and randf() < 0.35:
				_press_heavy(-1.0, 0.0)
			else:
				fighter.input_light_pressed = true
	elif not on_floor and target_below and absf(dx) < 60.0 and dy < 200.0:
		if randf() < _aggression * 0.6:
			_attack_cooldown = randf_range(0.2, 0.5)
			fighter.input_move.y = 1.0
			if randf() < 0.4 and target.percent > 60.0:
				fighter.input_heavy_pressed = true
			else:
				fighter.input_light_pressed = true
	elif absf(dx) < 300.0 and absf(dy) < 40.0 and randf() < 0.012 and target.percent > 50.0:
		# Take a pot shot from mid range.
		_attack_cooldown = randf_range(0.4, 0.8)
		fighter.facing = 1 if dx > 0.0 else -1
		_press_heavy(0.0, randf_range(0.1, 0.5))


func _press_heavy(vertical: float, hold: float) -> void:
	fighter.input_move.y = vertical
	fighter.input_heavy_pressed = true
	fighter.input_heavy_held = true
	_hold_heavy_timer = hold


func _recover(pos: Vector2, on_floor: bool) -> void:
	var toward_center := -signf(pos.x) if absf(pos.x) > 1.0 else 0.0
	fighter.input_move.x = toward_center
	if on_floor:
		return
	var falling := fighter.velocity.y > 60.0
	var below_stage := pos.y > floor_y - 20.0
	if fighter.state != Fighter.State.FREE:
		return
	if falling and fighter._jumps_left > 0 and (below_stage or absf(pos.x) > stage_half_width + 60.0):
		fighter.input_jump_pressed = true
	elif falling and fighter._jumps_left <= 0 and below_stage and _gun_jump_cooldown <= 0.0:
		# Out of jumps: fire the gun downward for a recoil boost.
		_gun_jump_cooldown = 0.9
		fighter.input_move.y = 1.0
		fighter.input_heavy_pressed = true


func _nearest_opponent() -> Fighter:
	var best: Fighter = null
	var best_distance := INF
	for node in fighter.get_tree().get_nodes_in_group("fighters"):
		var other := node as Fighter
		if other == null or other == fighter or not other.is_alive() or not other.visible:
			continue
		if other.state == Fighter.State.REVIVAL:
			continue
		var d := fighter.global_position.distance_squared_to(other.global_position)
		if d < best_distance:
			best_distance = d
			best = other
	return best
