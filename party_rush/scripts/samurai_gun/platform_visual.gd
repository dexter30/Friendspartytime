extends StaticBody2D

@export var size := Vector2(520, 36)
@export var body_color := Color(0.28, 0.3, 0.38)
@export var trim_color := Color(0.85, 0.55, 0.2)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var half := size * 0.5
	draw_rect(Rect2(-half.x, -half.y, size.x, size.y), body_color)
	draw_rect(Rect2(-half.x, -half.y - 4.0, size.x, 4.0), trim_color)
