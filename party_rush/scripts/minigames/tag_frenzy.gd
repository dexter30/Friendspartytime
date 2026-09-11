class_name TagFrenzy
extends MinigameBase

## One player is "it". Tag others to pass the role. Most tags when time runs out wins.

var tag_counts: Array[int] = [0, 0, 0]
var _it_player: PlayerController = null


func _ready() -> void:
	round_duration = 45.0


func setup_round(spawned_players: Array[PlayerController]) -> void:
	tag_counts = [0, 0, 0]
	super.setup_round(spawned_players)


func start_round() -> void:
	super.start_round()
	_set_it_player(players[randi() % players.size()])


func _connect_player(player: PlayerController) -> void:
	player.player_tagged.connect(_on_player_collision.bind(player))


func _on_player_collision(player: PlayerController, other: PlayerController) -> void:
	if not is_running:
		return
	if player == _it_player and other != _it_player:
		tag_counts[player.player_index] += 1
		_set_it_player(other)
		player.apply_bump(other.global_position)
	elif other == _it_player and player != _it_player:
		tag_counts[other.player_index] += 1
		_set_it_player(player)
		other.apply_bump(player.global_position)


func _set_it_player(player: PlayerController) -> void:
	if _it_player:
		_it_player.set_is_it(false)
	_it_player = player
	_it_player.set_is_it(true)


func on_timer_expired() -> void:
	if is_finished:
		return
	var best_index := 0
	for i in range(1, tag_counts.size()):
		if tag_counts[i] > tag_counts[best_index]:
			best_index = i
	if _it_player:
		_it_player.set_is_it(false)
	end_round(best_index, "%s tagged the most players!" % GameState.PLAYER_NAMES[best_index])
