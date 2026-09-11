class_name TagFrenzy
extends MinigameBase

## One player is "it" and moves slightly faster. Touch another player to pass the role.
## Most tags when time runs out wins. The arena is fenced so nobody falls off.

const TAG_COOLDOWN := 1.0

var tag_counts: Array[int] = [0, 0, 0]
var _it_player: PlayerController = null
var _tag_cooldown: float = 0.0


func _ready() -> void:
	super()
	round_duration = 45.0


func _physics_process(delta: float) -> void:
	super(delta)
	if _tag_cooldown > 0.0:
		_tag_cooldown -= delta


func setup_round(spawned_players: Array[PlayerController]) -> void:
	tag_counts = [0, 0, 0]
	_tag_cooldown = 0.0
	_it_player = null
	super.setup_round(spawned_players)


func start_round() -> void:
	super.start_round()
	_set_it_player(players[randi() % players.size()])


func _connect_player(player: PlayerController) -> void:
	player.player_tagged.connect(_on_player_collision.bind(player))


func _on_player_collision(player: PlayerController, other: PlayerController) -> void:
	if not is_running or _tag_cooldown > 0.0 or _it_player == null:
		return

	var tagger: PlayerController
	var tagged: PlayerController
	if player == _it_player and other != _it_player:
		tagger = player
		tagged = other
	elif other == _it_player and player != _it_player:
		tagger = other
		tagged = player
	else:
		return

	tag_counts[tagger.player_index] += 1
	_tag_cooldown = TAG_COOLDOWN
	_set_it_player(tagged)


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
