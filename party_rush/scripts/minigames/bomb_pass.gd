class_name BombPass
extends MinigameBase

## Hot potato — pass the bomb by bumping into another player before the timer hits zero.
## Last player holding the bomb when it explodes loses; everyone else scores.

@export var bomb_timer_start: float = 12.0

var _bomb_time: float = 0.0
var _bomb_holder: PlayerController = null
var _exploded: bool = false

@onready var _bomb_visual: MeshInstance3D = $BombVisual


func _ready() -> void:
	round_duration = 60.0
	_bomb_visual.visible = false


func setup_round(spawned_players: Array[PlayerController]) -> void:
	_exploded = false
	_bomb_time = bomb_timer_start
	super.setup_round(spawned_players)


func start_round() -> void:
	super.start_round()
	_give_bomb_to(players[randi() % players.size()])


func _physics_process(delta: float) -> void:
	if not is_running or is_finished or _bomb_holder == null:
		return

	_bomb_time -= delta
	_update_bomb_visual()

	if _bomb_time <= 0.0:
		_explode_bomb()


func _connect_player(player: PlayerController) -> void:
	player.player_tagged.connect(_on_player_collision.bind(player))


func _on_player_collision(player: PlayerController, other: PlayerController) -> void:
	if not is_running or _exploded:
		return
	if player.has_bomb and other != player:
		_pass_bomb(other)
	elif other.has_bomb and other != player:
		_pass_bomb(player)


func _give_bomb_to(player: PlayerController) -> void:
	if _bomb_holder:
		_bomb_holder.set_has_bomb(false)
	_bomb_holder = player
	_bomb_holder.set_has_bomb(true)
	_bomb_time = bomb_timer_start
	_update_bomb_visual()


func _pass_bomb(to_player: PlayerController) -> void:
	_bomb_time = minf(_bomb_time + 2.0, bomb_timer_start)
	_give_bomb_to(to_player)


func _update_bomb_visual() -> void:
	if _bomb_holder == null:
		_bomb_visual.visible = false
		return
	_bomb_visual.visible = true
	_bomb_visual.global_position = _bomb_holder.global_position + Vector3(0.0, 2.2, 0.0)
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.15
	_bomb_visual.scale = Vector3.ONE * pulse


func _explode_bomb() -> void:
	if _exploded:
		return
	_exploded = true
	var loser := _bomb_holder.player_index if _bomb_holder else -1
	if _bomb_holder:
		_bomb_holder.set_has_bomb(false)
		_bomb_holder.apply_bump(global_position)
	_bomb_visual.visible = false

	# Pick a winner among survivors (first non-loser)
	var winner := 0
	for i in range(players.size()):
		if i != loser:
			winner = i
			break

	var message := "%s was caught with the bomb!" % GameState.PLAYER_NAMES[loser]
	end_round(winner, message)


func get_bomb_time() -> float:
	return _bomb_time


func explode_if_time_up() -> void:
	_explode_bomb()
