class_name AttackHitbox
extends Area2D

signal hit_landed(target: Node, damage: float, knockback: Vector2, is_heavy: bool)

@export var owner_fighter: Node2D

var active := false
var damage := 0.0
var knockback_base := 0.0
var knockback_scaling := 0.0
var is_heavy := false
var _already_hit: Array[int] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func activate(heavy: bool) -> void:
	active = true
	is_heavy = heavy
	_already_hit.clear()
	monitoring = true


func deactivate() -> void:
	active = false
	monitoring = false
	_already_hit.clear()


func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	if area.get_parent():
		_try_hit(area.get_parent())


func _try_hit(target: Node) -> void:
	if not active or target == owner_fighter:
		return
	if not target.has_method("take_hit"):
		return
	var id := target.get_instance_id()
	if id in _already_hit:
		return
	_already_hit.append(id)

	var dir := signf(target.global_position.x - owner_fighter.global_position.x)
	if dir == 0.0:
		dir = 1.0
	var victim_damage := 0.0
	if "damage_percent" in target:
		victim_damage = target.damage_percent

	var knockback_strength := knockback_base + victim_damage * knockback_scaling
	var knockback := Vector2(dir * knockback_strength, -knockback_strength * 0.55)
	if is_heavy:
		knockback.y *= 1.15

	hit_landed.emit(target, damage, knockback, is_heavy)
	target.take_hit(damage, knockback, is_heavy, owner_fighter)
