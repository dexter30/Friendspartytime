class_name MovingPlatform
extends AnimatableBody3D

@export var move_offset: Vector3 = Vector3(6.0, 0.0, 0.0)
@export var duration: float = 3.0

var _start_position: Vector3


func _ready() -> void:
	_start_position = global_position
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", _start_position + move_offset, duration)
	tween.tween_property(self, "global_position", _start_position, duration)
