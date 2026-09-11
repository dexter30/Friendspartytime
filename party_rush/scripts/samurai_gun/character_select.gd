extends Control

const PREVIEW_SCRIPT := preload("res://scripts/samurai_gun/fighter_visual.gd")

@onready var _title: Label = $Layout/Title
@onready var _p1_panel: PanelContainer = $Layout/SelectRow/P1Panel
@onready var _p2_panel: PanelContainer = $Layout/SelectRow/P2Panel
@onready var _p1_preview: Control = $Layout/SelectRow/P1Panel/VBox/Preview
@onready var _p2_preview: Control = $Layout/SelectRow/P2Panel/VBox/Preview
@onready var _p1_name: Label = $Layout/SelectRow/P1Panel/VBox/NameLabel
@onready var _p2_name: Label = $Layout/SelectRow/P2Panel/VBox/NameLabel
@onready var _p1_tag: Label = $Layout/SelectRow/P1Panel/VBox/TagLabel
@onready var _p2_tag: Label = $Layout/SelectRow/P2Panel/VBox/TagLabel
@onready var _grid: GridContainer = $Layout/RosterGrid
@onready var _hint: Label = $Layout/HintLabel
@onready var _fight_button: Button = $Layout/FightButton

var _p1_selection := 0
var _p2_selection := 1
var _active_player := 0
var _preview_nodes: Array[Node2D] = []


func _ready() -> void:
	SamuraiGunState.reset_selections()
	_build_roster_grid()
	_refresh_previews()
	_fight_button.pressed.connect(_on_fight_pressed)
	_hint.text = "P1: A/D pick • Enter confirm  |  P2: ←/→ pick • Numpad Enter confirm  |  Fight when both ready"


func _build_roster_grid() -> void:
	for i in range(FighterData.roster_size()):
		var data := FighterData.get_fighter(i)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 44)
		btn.text = data["name"]
		btn.pressed.connect(_on_roster_pressed.bind(i))
		_grid.add_child(btn)


func _refresh_previews() -> void:
	for node in _preview_nodes:
		node.queue_free()
	_preview_nodes.clear()

	var p1_data := FighterData.get_fighter(_p1_selection)
	var p2_data := FighterData.get_fighter(_p2_selection)
	_p1_name.text = p1_data["name"]
	_p2_name.text = p2_data["name"]
	_p1_tag.text = p1_data["tagline"]
	_p2_tag.text = p2_data["tagline"]

	_add_preview(_p1_preview, p1_data)
	_add_preview(_p2_preview, p2_data)

	_p1_panel.modulate = Color(1.2, 1.2, 1.2) if _active_player == 0 else Color(0.85, 0.85, 0.85)
	_p2_panel.modulate = Color(1.2, 1.2, 1.2) if _active_player == 1 else Color(0.85, 0.85, 0.85)


func _add_preview(host: Control, data: Dictionary) -> void:
	var holder := Node2D.new()
	holder.position = Vector2(110, 60)
	host.add_child(holder)
	var visual: Node2D = PREVIEW_SCRIPT.new()
	visual.setup_from_data(data)
	holder.add_child(visual)
	_preview_nodes.append(holder)


func _on_roster_pressed(index: int) -> void:
	if _active_player == 0:
		_p1_selection = index
	else:
		_p2_selection = index
	_refresh_previews()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	if event.is_action_pressed("p1_light") or event.is_action_pressed("p1_heavy"):
		_active_player = 0
		_refresh_previews()
	elif event.is_action_pressed("p2_light") or event.is_action_pressed("p2_heavy"):
		_active_player = 1
		_refresh_previews()

	if _active_player == 0:
		if event.is_action_pressed("p1_left"):
			_p1_selection = (_p1_selection - 1 + FighterData.roster_size()) % FighterData.roster_size()
			_refresh_previews()
		elif event.is_action_pressed("p1_right"):
			_p1_selection = (_p1_selection + 1) % FighterData.roster_size()
			_refresh_previews()
	elif _active_player == 1:
		if event.is_action_pressed("p2_left"):
			_p2_selection = (_p2_selection - 1 + FighterData.roster_size()) % FighterData.roster_size()
			_refresh_previews()
		elif event.is_action_pressed("p2_right"):
			_p2_selection = (_p2_selection + 1) % FighterData.roster_size()
			_refresh_previews()

	if event.is_action_pressed("ui_accept"):
		SamuraiGunState.p1_fighter_id = _p1_selection
		SamuraiGunState.p2_fighter_id = _p2_selection
		get_tree().change_scene_to_file("res://scenes/samurai_gun/arena.tscn")


func _on_fight_pressed() -> void:
	SamuraiGunState.p1_fighter_id = _p1_selection
	SamuraiGunState.p2_fighter_id = _p2_selection
	get_tree().change_scene_to_file("res://scenes/samurai_gun/arena.tscn")
