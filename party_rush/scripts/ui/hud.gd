extends CanvasLayer

@onready var _score_labels: Array[Label] = [
	$ScorePanel/HBox/Score1,
	$ScorePanel/HBox/Score2,
	$ScorePanel/HBox/Score3,
]


func _ready() -> void:
	GameState.scores_changed.connect(_update_scores)
	_update_scores()
	_style_score_labels()


func _style_score_labels() -> void:
	for i in range(_score_labels.size()):
		_score_labels[i].add_theme_color_override("font_color", GameState.PLAYER_COLORS[i])


func _update_scores() -> void:
	for i in range(_score_labels.size()):
		_score_labels[i].text = "%s: %d" % [GameState.PLAYER_NAMES[i], GameState.scores[i]]
