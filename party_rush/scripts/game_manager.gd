extends Node3D

@onready var _player_scene: PackedScene = preload("res://scenes/player/player.tscn")
@onready var _camera: MultiplayerCamera = $MultiplayerCamera
@onready var _hud: CanvasLayer = $HUD
@onready var _minigame_container: Node3D = $MinigameContainer
@onready var _countdown_label: Label = $HUD/CountdownLabel
@onready var _status_label: Label = $HUD/StatusLabel
@onready var _timer_label: Label = $HUD/TimerLabel

var _players: Array[PlayerController] = []
var _current_minigame: MinigameBase = null
var _round_timer: float = 0.0
var _countdown: float = 0.0
var _state: String = "countdown"


func _ready() -> void:
	GameState.reset_match()
	GameState.is_playing = true
	_spawn_players_offscreen()
	_load_next_minigame()


func _spawn_players_offscreen() -> void:
	for i in range(3):
		var player := _player_scene.instantiate() as PlayerController
		player.player_index = i
		add_child(player)
		player.global_position = Vector3(i * 2.0, -50.0, 0.0)
		_players.append(player)


func _load_next_minigame() -> void:
	if _current_minigame:
		_current_minigame.queue_free()
		_current_minigame = null

	var scene_path := GameState.next_minigame_scene()
	var scene := load(scene_path) as PackedScene
	_current_minigame = scene.instantiate() as MinigameBase
	_minigame_container.add_child(_current_minigame)
	_current_minigame.minigame_finished.connect(_on_minigame_finished)

	_current_minigame.setup_round(_players)
	_camera.set_targets(_current_minigame.get_camera_targets())

	var minigame_name := GameState.MINIGAME_NAMES[(GameState.current_minigame_index - 1 + GameState.MINIGAME_NAMES.size()) % GameState.MINIGAME_NAMES.size()]
	_status_label.text = minigame_name
	GameState.minigame_started.emit(minigame_name)

	_countdown = _current_minigame.countdown_seconds
	_state = "countdown"
	_countdown_label.visible = true
	_update_countdown_display()


func _process(delta: float) -> void:
	match _state:
		"countdown":
			_countdown -= delta
			_update_countdown_display()
			if _countdown <= 0.0:
				_countdown_label.visible = false
				_state = "playing"
				_current_minigame.start_round()
				_round_timer = _current_minigame.round_duration
		"playing":
			_round_timer -= delta
			_update_timer_display()
			if _round_timer <= 0.0:
				_handle_time_up()
		"results":
			pass


func _update_countdown_display() -> void:
	var num := int(ceil(_countdown))
	if num > 0:
		_countdown_label.text = str(num)
	else:
		_countdown_label.text = "GO!"


func _update_timer_display() -> void:
	var seconds := int(ceil(_round_timer))
	var minutes := seconds / 60
	seconds %= 60
	_timer_label.text = "%d:%02d" % [minutes, seconds]

	if _current_minigame is BombPass:
		var bomb_time := (_current_minigame as BombPass).get_bomb_time()
		_timer_label.text += "  BOMB: %.1f" % bomb_time


func _handle_time_up() -> void:
	if _current_minigame is TagFrenzy:
		(_current_minigame as TagFrenzy).on_timer_expired()
	elif _current_minigame is BombPass:
		(_current_minigame as BombPass).explode_if_time_up()
	else:
		# No one finished — award to leader by position (closest to goal) or random
		var winner := randi() % 3
		_current_minigame.end_round(winner, "Time's up! %s takes the round." % GameState.PLAYER_NAMES[winner])


func _on_minigame_finished(winner_index: int, message: String) -> void:
	_state = "results"
	_status_label.text = message
	GameState.add_score(winner_index)
	GameState.minigame_ended.emit(winner_index, message)
	GameState.rounds_played += 1

	await get_tree().create_timer(3.0).timeout

	if GameState.has_match_winner():
		_show_match_results()
	else:
		_load_next_minigame()


func _show_match_results() -> void:
	var winner := GameState.get_match_winner_index()
	_status_label.text = "%s wins the match!" % GameState.PLAYER_NAMES[winner]
	GameState.match_ended.emit(winner)
	GameState.is_playing = false
	await get_tree().create_timer(4.0).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
