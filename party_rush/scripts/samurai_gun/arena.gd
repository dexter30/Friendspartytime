extends Node2D

const FIGHTER_SCENE := preload("res://scenes/samurai_gun/fighter.tscn")
const BLAST_MARGIN := Vector2(120, 160)

@onready var _camera: SmashCamera2D = $SmashCamera
@onready var _spawn_left: Marker2D = $SpawnPoints/Left
@onready var _spawn_right: Marker2D = $SpawnPoints/Right
@onready var _fighters_root: Node2D = $Fighters
@onready var _countdown_label: Label = $UI/CountdownLabel
@onready var _message_label: Label = $UI/MessageLabel
@onready var _p1_name: Label = $UI/P1Panel/VBox/NameLabel
@onready var _p2_name: Label = $UI/P2Panel/VBox/NameLabel
@onready var _p1_damage: Label = $UI/P1Panel/VBox/DamageLabel
@onready var _p2_damage: Label = $UI/P2Panel/VBox/DamageLabel
@onready var _p1_stocks: HBoxContainer = $UI/P1Panel/VBox/Stocks
@onready var _p2_stocks: HBoxContainer = $UI/P2Panel/VBox/Stocks

var _fighters: Array[SamuraiFighter] = []
var _match_running := false
var _match_over := false
var _stage_bounds := Rect2()


func _ready() -> void:
	_stage_bounds = Rect2(Vector2(-520, -320), Vector2(1040, 640))
	_message_label.text = ""
	_spawn_fighters()
	_build_stock_icons()
	_update_hud()
	await get_tree().create_timer(0.5).timeout
	await _run_countdown()
	_start_match()


func _spawn_fighters() -> void:
	var p1_data := FighterData.get_fighter(SamuraiGunState.p1_fighter_id)
	var p2_data := FighterData.get_fighter(SamuraiGunState.p2_fighter_id)
	_p1_name.text = p1_data["name"]
	_p2_name.text = p2_data["name"]

	var p1 := FIGHTER_SCENE.instantiate() as SamuraiFighter
	var p2 := FIGHTER_SCENE.instantiate() as SamuraiFighter
	_fighters_root.add_child(p1)
	_fighters_root.add_child(p2)
	p1.setup(0, SamuraiGunState.p1_fighter_id, _spawn_left.global_position)
	p2.setup(1, SamuraiGunState.p2_fighter_id, _spawn_right.global_position)
	p2.facing = -1

	p1.stocks_changed.connect(_on_p1_stocks)
	p1.damage_changed.connect(_on_p1_damage)
	p2.stocks_changed.connect(_on_p2_stocks)
	p2.damage_changed.connect(_on_p2_damage)
	p1.fighter_koed.connect(_check_match_end)
	p2.fighter_koed.connect(_check_match_end)
	p1.attack_landed.connect(_on_attack_landed)
	p2.attack_landed.connect(_on_attack_landed)

	_fighters = [p1, p2]
	_camera.set_fighters(_fighters)


func _on_attack_landed(is_heavy: bool) -> void:
	_camera.add_trauma(0.35 if is_heavy else 0.18)


func _build_stock_icons() -> void:
	_clear_stocks(_p1_stocks)
	_clear_stocks(_p2_stocks)
	for i in SamuraiFighter.STOCK_COUNT:
		_p1_stocks.add_child(_make_stock_icon(FighterData.get_fighter(SamuraiGunState.p1_fighter_id)["color"]))
		_p2_stocks.add_child(_make_stock_icon(FighterData.get_fighter(SamuraiGunState.p2_fighter_id)["color"]))


func _make_stock_icon(color: Color) -> ColorRect:
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(18, 18)
	icon.color = color
	return icon


func _clear_stocks(container: HBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _run_countdown() -> void:
	var words := ["3", "2", "1", "DUEL!"]
	for word in words:
		_countdown_label.text = word
		_countdown_label.modulate.a = 1.0
		_countdown_label.scale = Vector2(1.3, 1.3)
		var tween := create_tween()
		tween.parallel().tween_property(_countdown_label, "scale", Vector2.ONE, 0.35)
		tween.parallel().tween_property(_countdown_label, "modulate:a", 0.0, 0.35).set_delay(0.45)
		await get_tree().create_timer(0.85).timeout
	_countdown_label.text = ""


func _start_match() -> void:
	_match_running = true
	for fighter in _fighters:
		fighter.set_can_act(true)


func _physics_process(_delta: float) -> void:
	if not _match_running or _match_over:
		return
	for fighter in _fighters:
		if not is_instance_valid(fighter) or fighter.state == SamuraiFighter.State.DEAD:
			continue
		if fighter.state in [SamuraiFighter.State.RESPAWN, SamuraiFighter.State.HITSTUN]:
			continue
		var pos := fighter.global_position
		if pos.x < _stage_bounds.position.x - BLAST_MARGIN.x \
				or pos.x > _stage_bounds.end.x + BLAST_MARGIN.x \
				or pos.y < _stage_bounds.position.y - BLAST_MARGIN.y \
				or pos.y > _stage_bounds.end.y + BLAST_MARGIN.y:
			_ko_fighter(fighter)


func _ko_fighter(fighter: SamuraiFighter) -> void:
	if fighter.state in [SamuraiFighter.State.RESPAWN, SamuraiFighter.State.DEAD]:
		return
	_camera.add_trauma(0.65)
	fighter.global_position = _spawn_left.global_position if fighter.player_slot == 0 else _spawn_right.global_position
	fighter.velocity = Vector2.ZERO
	fighter.lose_stock()
	_update_stock_icons()


func _on_p1_stocks(_stocks: int) -> void:
	_update_stock_icons()


func _on_p2_stocks(_stocks: int) -> void:
	_update_stock_icons()


func _on_p1_damage(percent: float) -> void:
	_p1_damage.text = "%d%%" % int(percent)


func _on_p2_damage(percent: float) -> void:
	_p2_damage.text = "%d%%" % int(percent)


func _update_stock_icons() -> void:
	_update_stock_row(_p1_stocks, _fighters[0].stocks)
	_update_stock_row(_p2_stocks, _fighters[1].stocks)


func _update_stock_row(container: HBoxContainer, stocks_left: int) -> void:
	var icons := container.get_children()
	for i in range(icons.size()):
		icons[i].modulate.a = 1.0 if i < stocks_left else 0.15


func _update_hud() -> void:
	_p1_damage.text = "0%"
	_p2_damage.text = "0%"


func _check_match_end() -> void:
	if _match_over:
		return
	await get_tree().process_frame
	var alive := 0
	var winner: SamuraiFighter = null
	for fighter in _fighters:
		if fighter.stocks > 0:
			alive += 1
			winner = fighter
	if alive <= 1:
		_end_match(winner)


func _end_match(winner: SamuraiFighter) -> void:
	_match_over = true
	_match_running = false
	for fighter in _fighters:
		fighter.set_can_act(false)

	var winner_data := FighterData.get_fighter(winner.fighter_id)
	_message_label.text = "%s wins!" % winner_data["name"]
	_message_label.modulate.a = 1.0

	await get_tree().create_timer(3.5).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
