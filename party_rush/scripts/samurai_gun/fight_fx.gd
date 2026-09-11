class_name FightFx
extends Node2D

## One-shot drawn effects for Samurai Gun (slash arcs, hit rings, muzzle flashes,
## KO bursts) plus helpers for particles and damage numbers. Everything is spawned
## through the static factories and cleans itself up.

enum Kind { RING, SLASH, SPARK_LINES, MUZZLE, KO_BURST, SHOCKWAVE }

var kind: Kind = Kind.RING
var color: Color = Color.WHITE
var size: float = 40.0
var duration: float = 0.25
## Slash arc bounds in radians (local space).
var arc_from: float = 0.0
var arc_to: float = PI * 0.5
var progress: float = 0.0

var _rays: Array[float] = []


static func spawn(parent: Node, fx_kind: Kind, at: Vector2, fx_color: Color, fx_size: float, fx_duration: float) -> FightFx:
	var fx := FightFx.new()
	fx.kind = fx_kind
	fx.color = fx_color
	fx.size = fx_size
	fx.duration = fx_duration
	fx.z_index = 20
	parent.add_child(fx)
	fx.global_position = at
	fx._start()
	return fx


## Sweeping slash arc. `from_deg`/`to_deg` are in the attacker's facing space (0 = forward, 90 = up).
static func spawn_slash(parent: Node, at: Vector2, fx_color: Color, radius: float, from_deg: float, to_deg: float, facing: int, fx_duration: float = 0.18) -> FightFx:
	var fx := FightFx.new()
	fx.kind = Kind.SLASH
	fx.color = fx_color
	fx.size = radius
	fx.duration = fx_duration
	fx.z_index = 20
	fx.arc_from = deg_to_rad(from_deg)
	fx.arc_to = deg_to_rad(to_deg)
	fx.scale.x = facing
	parent.add_child(fx)
	fx.global_position = at
	fx._start()
	return fx


static func spawn_damage_number(parent: Node, at: Vector2, amount: float, fx_color: Color) -> void:
	var label := Label.new()
	label.text = "%d" % int(round(amount))
	label.add_theme_font_size_override("font_size", 26 if amount < 10.0 else 34)
	label.add_theme_color_override("font_color", fx_color.lightened(0.35))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.06))
	label.add_theme_constant_override("outline_size", 8)
	label.z_index = 30
	parent.add_child(label)
	label.global_position = at + Vector2(-20.0 + randf_range(-10.0, 10.0), -50.0)
	label.pivot_offset = Vector2(20.0, 16.0)
	label.scale = Vector2(0.4, 0.4)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2(1.25, 1.25), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(label, "global_position:y", label.global_position.y - 40.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(label.queue_free)


static func spawn_burst_particles(parent: Node, at: Vector2, fx_color: Color, amount: int, speed: float, life: float = 0.45, gravity_y: float = 600.0) -> void:
	var particles := CPUParticles2D.new()
	particles.amount = amount
	particles.lifetime = life
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 6.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector2(0.0, gravity_y)
	particles.damping_min = speed * 0.6
	particles.damping_max = speed * 1.2
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.color = fx_color
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	particles.color_ramp = fade
	particles.z_index = 15
	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	var timer := parent.get_tree().create_timer(life + 0.1)
	timer.timeout.connect(particles.queue_free)


func _start() -> void:
	if kind == Kind.KO_BURST or kind == Kind.SPARK_LINES:
		var count := 14 if kind == Kind.KO_BURST else 7
		for i in range(count):
			_rays.append(randf_range(0.0, TAU))
	var tween := create_tween()
	tween.tween_property(self, "progress", 1.0, duration)
	tween.tween_callback(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := clampf(progress, 0.0, 1.0)
	var fade := 1.0 - t
	match kind:
		Kind.RING:
			var radius := size * (0.3 + t * 1.2)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color.r, color.g, color.b, fade), maxf(1.5, size * 0.22 * fade))
		Kind.SHOCKWAVE:
			var radius := size * (0.2 + t * 1.5)
			var col := Color(color.r, color.g, color.b, fade * 0.9)
			draw_arc(Vector2.ZERO, radius, PI, TAU, 24, col, maxf(2.0, size * 0.18 * fade))
			draw_arc(Vector2.ZERO, radius * 0.7, PI, TAU, 24, Color(1.0, 1.0, 1.0, fade * 0.6), maxf(1.0, size * 0.08 * fade))
		Kind.SLASH:
			# Sweep the arc from `arc_from` toward `arc_to`, then fade the trailing edge.
			var sweep := clampf(t * 1.6, 0.0, 1.0)
			var trail := clampf((t - 0.35) / 0.65, 0.0, 1.0)
			var a0 := lerpf(arc_from, arc_to, trail)
			var a1 := lerpf(arc_from, arc_to, sweep)
			if absf(a1 - a0) < 0.01:
				return
			var points := PackedVector2Array([Vector2.ZERO])
			var steps := 14
			for i in range(steps + 1):
				var a := lerpf(a0, a1, i / float(steps))
				points.append(Vector2(cos(a), -sin(a)) * size)
			draw_colored_polygon(points, Color(1.0, 1.0, 1.0, 0.85 * fade))
			var inner := PackedVector2Array([Vector2.ZERO])
			for i in range(steps + 1):
				var a := lerpf(a0, a1, i / float(steps))
				inner.append(Vector2(cos(a), -sin(a)) * size * 0.72)
			draw_colored_polygon(inner, Color(color.r, color.g, color.b, 0.55 * fade))
			var edge := PackedVector2Array()
			for i in range(steps + 1):
				var a := lerpf(a0, a1, i / float(steps))
				edge.append(Vector2(cos(a), -sin(a)) * size)
			draw_polyline(edge, Color(1.0, 1.0, 1.0, fade), 3.0, true)
		Kind.MUZZLE:
			var radius := size * (1.0 - t * 0.5)
			var star := PackedVector2Array()
			for i in range(8):
				var a := i * TAU / 8.0
				var r := radius if i % 2 == 0 else radius * 0.45
				star.append(Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(star, Color(1.0, 0.95, 0.7, fade))
			draw_circle(Vector2.ZERO, radius * 0.4, Color(1.0, 1.0, 1.0, fade))
		Kind.SPARK_LINES, Kind.KO_BURST:
			var reach := size * (0.4 + t * 1.6)
			var thickness := maxf(1.5, size * 0.09 * fade)
			for a in _rays:
				var dir := Vector2(cos(a), sin(a))
				var start := dir * reach * 0.55
				var finish := dir * reach
				draw_line(start, finish, Color(color.r, color.g, color.b, fade), thickness)
				draw_line(start, finish, Color(1.0, 1.0, 1.0, fade * 0.7), thickness * 0.4)
			if kind == Kind.KO_BURST:
				draw_arc(Vector2.ZERO, reach * 0.9, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, fade * 0.8), maxf(2.0, size * 0.12 * fade))
				draw_circle(Vector2.ZERO, size * 0.5 * fade, Color(1.0, 1.0, 1.0, fade))
