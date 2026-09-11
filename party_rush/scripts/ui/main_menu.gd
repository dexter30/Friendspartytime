extends Control

@onready var _title: Label = $VBox/Title
@onready var _start_button: Button = $VBox/StartButton
@onready var _samurai_button: Button = $VBox/SamuraiGunButton
@onready var _controls_label: Label = $VBox/ControlsLabel
@onready var _minigames_label: Label = $VBox/MinigamesLabel


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_samurai_button.pressed.connect(_on_samurai_pressed)
	_controls_label.text = """Controls (Move / Jump / Dash):
  Red    — WASD / Space / Shift
  Blue   — Arrows / Enter / Slash
  Yellow — IJKL / U / O
  Gamepad — Stick / A / B or X (up to 3 pads)
  Tap jump for a short hop, hold for full height"""

	var minigame_list := ""
	for i in range(GameState.MINIGAME_NAMES.size()):
		minigame_list += "  • %s\n" % GameState.MINIGAME_NAMES[i]
	_minigames_label.text = "Mini-Games:\n" + minigame_list


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_samurai_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/samurai_gun/character_select.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_start_pressed()
