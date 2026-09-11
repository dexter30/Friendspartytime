extends Control

@onready var _start_button: Button = $VBox/Games/PartyCard/VBox/StartButton
@onready var _samurai_button: Button = $VBox/Games/SamuraiCard/VBox/SamuraiButton
@onready var _controls_label: Label = $VBox/ControlsLabel
@onready var _minigames_label: Label = $VBox/MinigamesLabel


func _ready() -> void:
	Engine.time_scale = 1.0
	_start_button.pressed.connect(_on_start_pressed)
	_samurai_button.pressed.connect(_on_samurai_pressed)
	_start_button.focus_neighbor_right = _samurai_button.get_path()
	_samurai_button.focus_neighbor_left = _start_button.get_path()
	_start_button.grab_focus()
	_controls_label.text = """Controls (Move / Jump / Dash · Light / Heavy in Samurai Gun):
  Red    — WASD / Space / Shift · F / G
  Blue   — Arrows / Enter / Slash · / / .
  Yellow — IJKL / U / O · O / P
  Gamepad — Stick / A / B or X · X / B (up to 3 pads)
  Menu — Arrow keys or stick to pick a game, Enter / A to confirm"""

	var minigame_list := ""
	for i in range(GameState.MINIGAME_NAMES.size()):
		minigame_list += "%s   " % GameState.MINIGAME_NAMES[i]
	_minigames_label.text = "Party Rush mini-games:  " + minigame_list.strip_edges()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_samurai_pressed() -> void:
	SamuraiGunState.clear()
	get_tree().change_scene_to_file("res://scenes/samurai_gun/character_select.tscn")


func _unhandled_input(event: InputEvent) -> void:
	# Keep the game buttons focused so gamepads and Enter always work.
	if event.is_action_pressed("ui_accept") and get_viewport().gui_get_focus_owner() == null:
		_start_button.grab_focus()
