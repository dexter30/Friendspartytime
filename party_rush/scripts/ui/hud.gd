extends CanvasLayer

@onready var _score_labels: Array[Label] = [
	$ScorePanel/HBox/Score1,
	$ScorePanel/HBox/Score2,
	$ScorePanel/HBox/Score3,
]

var _last_scores: Array[int] = [0, 0, 0]


func _ready() -> void:
	GameState.scores_changed.connect(_update_scores)
	_style_score_labels()
	_update_scores()
	_center_pivots.call_deferred()


func _style_score_labels() -> void:
	for i in range(_score_labels.size()):
		_score_labels[i].add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])


func _center_pivots() -> void:
	for label in _score_labels:
		label.pivot_offset = label.size / 2.0


func _update_scores() -> void:
	for i in range(_score_labels.size()):
		_score_labels[i].text = "%s: %d" % [GameState.PLAYER_NAMES[i], GameState.scores[i]]
		if GameState.scores[i] != _last_scores[i]:
			_pulse_label(_score_labels[i])
		_last_scores[i] = GameState.scores[i]


func _pulse_label(label: Label) -> void:
	label.pivot_offset = label.size / 2.0
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2(1.45, 1.45), 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
