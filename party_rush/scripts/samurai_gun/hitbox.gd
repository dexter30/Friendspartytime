class_name Hitbox
extends Area2D

## A damaging volume spawned by a Fighter. Melee hitboxes ride along as children of the
## attacker; gun shots are placed in world space and travel with `velocity` until they
## run out of range. Each fighter can only be hit once per hitbox.

var owner_fighter: Fighter
var damage: float = 5.0
var base_knockback: float = 250.0
var knockback_growth: float = 6.0
## Launch angle in degrees, relative to `facing`: 0 = straight ahead, 90 = straight up, 270 = spike.
var angle: float = 40.0
var hitstop: float = 0.05
var facing: int = 1
var lifetime: float = 0.1
var velocity: Vector2 = Vector2.ZERO
var max_distance: float = 0.0
var is_bullet: bool = false
var color: Color = Color.WHITE

var _travelled: float = 0.0
var _hit: Array[Fighter] = []
var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 4
	monitorable = false
	monitoring = true


func configure(fighter: Fighter, data: Dictionary, size: Vector2, facing_dir: int) -> void:
	owner_fighter = fighter
	facing = facing_dir
	damage = data.get("damage", 5.0)
	base_knockback = data.get("base_kb", 250.0)
	knockback_growth = data.get("kb_growth", 6.0)
	angle = data.get("angle", 40.0)
	hitstop = data.get("hitstop", 0.05)
	lifetime = data.get("active", 0.1)
	color = fighter.fighter_color()
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)


func make_bullet(direction: Vector2, speed: float, travel: float) -> void:
	is_bullet = true
	velocity = direction.normalized() * speed
	max_distance = travel
	lifetime = travel / maxf(speed, 1.0) + 0.05
	rotation = velocity.angle()


func launch_direction() -> Vector2:
	if is_bullet and velocity.length_squared() > 0.0:
		var dir := velocity.normalized()
		# Vertical shots keep their spike/launch angle; horizontal shots launch forward-and-up.
		if absf(dir.y) > 0.7:
			return Vector2(facing * 0.15, signf(dir.y)).normalized()
		return Vector2(cos(deg_to_rad(angle)) * signf(dir.x), -sin(deg_to_rad(angle)))
	return Vector2(cos(deg_to_rad(angle)) * facing, -sin(deg_to_rad(angle)))


func _physics_process(delta: float) -> void:
	if velocity.length_squared() > 0.0:
		var step := velocity * delta
		global_position += step
		_travelled += step.length()
		if max_distance > 0.0 and _travelled >= max_distance:
			_expire()
			return
	if is_bullet:
		queue_redraw()

	for area in get_overlapping_areas():
		var victim := area.get_parent() as Fighter
		if victim == null or victim == owner_fighter or _hit.has(victim):
			continue
		if not victim.can_be_hit():
			continue
		_hit.append(victim)
		victim.take_hit(self, owner_fighter)
		if is_bullet:
			_expire()
			return

	lifetime -= delta
	if lifetime <= 0.0:
		_expire()


func _expire() -> void:
	if is_bullet and is_inside_tree():
		FightFx.spawn(get_parent(), FightFx.Kind.RING, global_position, color, 14.0, 0.15)
	queue_free()


func _draw() -> void:
	if not is_bullet:
		return
	var glow := Color(color.r, color.g, color.b, 0.35)
	draw_line(Vector2(-42.0, 0.0), Vector2(6.0, 0.0), glow, 10.0)
	draw_line(Vector2(-34.0, 0.0), Vector2(8.0, 0.0), Color(1.0, 0.98, 0.85), 4.0)
	draw_circle(Vector2(8.0, 0.0), 6.0, Color(1.0, 1.0, 1.0))
