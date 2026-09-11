extends Node2D

## Samurai Gun match manager: spawns the chosen fighters, runs the countdown, watches
## the blast zones, handles KOs / respawns / stocks, and shows results.

const RESPAWN_DELAY := 1.7
const COUNTDOWN_TIME := 3.4
const RESULTS_DELAY := 1.4

@onready var _stage: DojoStage = $Stage
@onready var _fighters_node: Node2D = $Fighters
@onready var _effects: Node2D = $Effects
@onready var _camera: FightCamera = $Camera
@onready var _hud: FightHud = $HUD

var _fighter_scene: PackedScene = preload("res://scenes/samurai_gun/fighter.tscn")
var _fighters: Array[Fighter] = []
var _phase := "countdown"
var _countdown := COUNTDOWN_TIME
var _last_countdown_text := ""
var _results_ready := false


func _ready() -> void:
	Engine.time_scale = 1.0
	var selections := SamuraiGunState.selections
	if selections.size() < 2:
		# Launched straight into the arena (e.g. from the editor): P1 vs a CPU.
		selections = [
			{"player_index": 0, "fighter_index": 0, "is_cpu": false},
			{"player_index": 1, "fighter_index": FighterRoster.random_index(), "is_cpu": true},
		]
	for i in range(selections.size()):
		_spawn_fighter(selections[i], i)

	_camera.bounds = DojoStage.CAMERA_BOUNDS
	for fighter in _fighters:
		_camera.targets.append(fighter)
	_camera.snap()
	_hud.setup(_fighters)
	_hud.set_hint("Light: katana (tap up/down for variants, 3-hit combo)   Heavy: gun (hold to charge, down-air for a recoil jump)   Esc: menu")
	_hud.show_banner("READY?", Color(1.0, 0.95, 0.8), 1.4)


func _spawn_fighter(selection: Dictionary, slot: int) -> void:
	var fighter := _fighter_scene.instantiate() as Fighter
	var data := FighterRoster.get_fighter(int(selection.get("fighter_index", 0)))
	fighter.setup(selection, data)
	fighter.world_node = _effects
	fighter.controls_enabled = false
	_fighters_node.add_child(fighter)
	fighter.global_position = _stage.spawn_point(slot, fighter.size_scale)
	fighter.facing = -1 if fighter.global_position.x > 0.0 else 1
	fighter.damaged.connect(_on_fighter_damaged)
	fighter.knocked_out.connect(_on_fighter_knocked_out)
	if fighter.brain:
		fighter.brain.stage_half_width = _stage.stage_half_width()
		fighter.brain.floor_y = DojoStage.FLOOR_Y
		fighter.brain.revival_y = DojoStage.REVIVAL_POINT.y
	_fighters.append(fighter)


func _process(delta: float) -> void:
	_stage.update_parallax(_camera.global_position)
	match _phase:
		"countdown":
			_countdown -= delta
			_update_countdown()
		"finished":
			if _results_ready:
				_poll_results_input()
	if Input.is_action_just_pressed("ui_cancel"):
		_go_to_menu()


func _update_countdown() -> void:
	if _countdown > COUNTDOWN_TIME - 0.6:
		return
	var remaining := _countdown
	var text := ""
	if remaining > 0.0:
		text = str(int(ceil(remaining)))
	else:
		text = "GO!"
	if text != _last_countdown_text:
		_last_countdown_text = text
		if text == "GO!":
			_hud.show_banner("GO!", Color(1.0, 0.92, 0.35), 2.0)
			_hud.flash_screen(Color(1.0, 1.0, 1.0, 0.35), 0.25)
			_camera.add_trauma(0.25)
			_start_fight()
		else:
			_hud.show_banner(text, Color(1.0, 0.95, 0.8), 1.6)


func _start_fight() -> void:
	_phase = "fighting"
	for fighter in _fighters:
		fighter.controls_enabled = true
	_hud.set_hint("")
	get_tree().create_timer(0.8).timeout.connect(_hud.hide_banner)


func _physics_process(_delta: float) -> void:
	if _phase == "finished":
		return
	for fighter in _fighters:
		if fighter.state == Fighter.State.KO or not fighter.visible:
			continue
		if not DojoStage.BLAST_RECT.has_point(fighter.global_position):
			_blast_ko(fighter)


func _blast_ko(fighter: Fighter) -> void:
	var view_half := get_viewport_rect().size / _camera.zoom * 0.5
	var view := Rect2(_camera.global_position - view_half, view_half * 2.0).grow(-50.0)
	var at := fighter.global_position
	at.x = clampf(at.x, view.position.x, view.end.x)
	at.y = clampf(at.y, view.position.y, view.end.y)
	var color := fighter.fighter_color()
	FightFx.spawn(_effects, FightFx.Kind.KO_BURST, at, color, 110.0, 0.55)
	FightFx.spawn_burst_particles(_effects, at, color.lightened(0.2), 30, 700.0, 0.6, 400.0)
	FightFx.spawn_burst_particles(_effects, at, Color.WHITE, 12, 400.0, 0.4, 200.0)
	_camera.add_trauma(0.75)
	_hud.flash_screen(Color(color.r, color.g, color.b, 0.45), 0.35)
	fighter.knock_out()


func _on_fighter_damaged(victim: Fighter, attacker: Fighter, amount: float, at: Vector2, knockback: float) -> void:
	var color := attacker.fighter_color() if attacker else Color.WHITE
	var strength := clampf(amount / 14.0, 0.25, 1.4)
	FightFx.spawn(_effects, FightFx.Kind.SPARK_LINES, at, color, 20.0 + amount * 2.4, 0.2)
	FightFx.spawn(_effects, FightFx.Kind.RING, at, Color.WHITE, 16.0 + amount * 1.5, 0.18)
	FightFx.spawn_burst_particles(_effects, at, color.lightened(0.3), int(6 + amount), 260.0 + knockback * 0.25, 0.4, 500.0)
	FightFx.spawn_damage_number(_effects, victim.global_position, amount, color)
	_camera.add_trauma(clampf(amount / 45.0 + knockback / 5000.0, 0.12, 0.6))
	_hud.pulse_card(victim, strength)
	if knockback > 1500.0:
		_hud.flash_screen(Color(1.0, 1.0, 1.0, 0.18), 0.15)


func _on_fighter_knocked_out(fighter: Fighter) -> void:
	if _phase == "finished":
		return
	var alive := _alive_fighters()
	if alive.size() <= 1:
		_end_match(alive)
		return
	_hud.show_banner("KO!", fighter.fighter_color().lightened(0.3), 2.2)
	get_tree().create_timer(0.7).timeout.connect(_hud.hide_banner)
	if fighter.stocks > 0:
		var timer := get_tree().create_timer(RESPAWN_DELAY)
		timer.timeout.connect(_respawn.bind(fighter))


func _respawn(fighter: Fighter) -> void:
	if _phase == "finished" or not is_instance_valid(fighter):
		return
	fighter.begin_revival(DojoStage.REVIVAL_POINT)


func _alive_fighters() -> Array[Fighter]:
	var alive: Array[Fighter] = []
	for fighter in _fighters:
		if fighter.stocks > 0:
			alive.append(fighter)
	return alive


func _end_match(alive: Array[Fighter]) -> void:
	_phase = "finished"
	var winner: Fighter = null
	if alive.size() == 1:
		winner = alive[0]
	else:
		winner = _fighters[0]
		for fighter in _fighters:
			if fighter.stocks > winner.stocks or (fighter.stocks == winner.stocks and fighter.percent < winner.percent):
				winner = fighter
	for fighter in _fighters:
		fighter.controls_enabled = false
	SamuraiGunState.last_winner = winner.selection.duplicate()

	_hud.show_banner("GAME!", Color(1.0, 0.92, 0.35), 2.4)
	_hud.flash_screen(Color(1.0, 1.0, 1.0, 0.5), 0.4)
	_camera.add_trauma(0.5)
	Engine.time_scale = 0.2
	await get_tree().create_timer(0.7, true, false, true).timeout
	Engine.time_scale = 1.0
	await get_tree().create_timer(RESULTS_DELAY).timeout
	if not is_inside_tree():
		return
	_hud.hide_banner()
	_hud.show_results(winner)
	_results_ready = true


func _poll_results_input() -> void:
	for i in range(SamuraiGunState.MAX_PLAYERS):
		if Input.is_action_just_pressed("p%d_jump" % (i + 1)) or Input.is_action_just_pressed("ui_accept"):
			get_tree().change_scene_to_file("res://scenes/samurai_gun/arena.tscn")
			return
		if Input.is_action_just_pressed("p%d_heavy" % (i + 1)):
			get_tree().change_scene_to_file("res://scenes/samurai_gun/character_select.tscn")
			return


func _go_to_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _exit_tree() -> void:
	Engine.time_scale = 1.0
