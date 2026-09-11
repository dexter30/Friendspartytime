class_name FighterVisual
extends Node2D

## Procedurally draws a Samurai Gun fighter: a coloured shape body, an expressive
## pair (or single) of eyes that track a look target, a samurai headband with
## trailing tails, and a sheathed katana. Shared by the arena, HUD and select screen.

@export var radius: float = 30.0
## 1 = facing right, -1 = facing left.
@export var facing: int = 1
## 0..1 white flash overlay (hit feedback).
var flash: float = 0.0
## Unit vector the pupils drift toward.
var look_direction: Vector2 = Vector2.ZERO
var show_weapon: bool = true
## 0..1 how charged the heavy attack is (draws a glow ring).
var charge: float = 0.0
## Squints while attacking / in hitstun.
var expression: String = "normal"

var _fighter: Dictionary = {}
var _shape_points: PackedVector2Array = PackedVector2Array()
var _blink_timer: float = 0.0
var _blink_amount: float = 0.0
var _time: float = 0.0
var _tail_phase: float = 0.0


func _ready() -> void:
	_blink_timer = randf_range(1.5, 4.0)
	if _fighter.is_empty():
		set_fighter(FighterRoster.get_fighter(0))


func set_fighter(fighter: Dictionary) -> void:
	_fighter = fighter
	_shape_points = FighterRoster.shape_points(_fighter["shape"], 1.0)
	queue_redraw()


func get_fighter() -> Dictionary:
	return _fighter


func body_color() -> Color:
	return _fighter.get("color", Color.WHITE)


func _process(delta: float) -> void:
	_time += delta
	_tail_phase += delta * 9.0
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_amount = 1.0
		_blink_timer = randf_range(1.8, 4.5)
	elif _blink_amount > 0.0:
		_blink_amount = maxf(_blink_amount - delta * 9.0, 0.0)
	if flash > 0.0:
		flash = maxf(flash - delta * 6.0, 0.0)
	queue_redraw()


func _draw() -> void:
	if _fighter.is_empty():
		return
	var r := radius
	var color: Color = _fighter["color"]
	var outline := color.darkened(0.45)
	var pts := PackedVector2Array()
	for p in _shape_points:
		pts.append(p * r)

	if charge > 0.0:
		var glow := Color(1.0, 0.9, 0.5, 0.25 + charge * 0.4)
		draw_circle(Vector2.ZERO, r * (1.25 + charge * 0.35 + sin(_time * 40.0) * 0.04 * charge), glow)

	_draw_tails(r)
	if show_weapon:
		_draw_katana(r, outline)

	draw_colored_polygon(pts, color)
	# Soft top-left highlight for a little volume.
	var highlight := PackedVector2Array()
	for p in _shape_points:
		highlight.append(p * r * 0.62 + Vector2(-r * 0.12, -r * 0.18))
	draw_colored_polygon(highlight, Color(1.0, 1.0, 1.0, 0.13))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, outline, maxf(2.0, r * 0.09), true)

	_draw_headband(r)
	_draw_eyes(r, color)

	if flash > 0.0:
		draw_colored_polygon(pts, Color(1.0, 1.0, 1.0, flash * 0.9))


func _draw_headband(r: float) -> void:
	var band_color: Color = _fighter.get("headband", Color.BLACK)
	var y := -r * 0.5
	var span := _half_width_at(y)
	if span <= 0.0:
		y = -r * 0.3
		span = _half_width_at(y)
	if span <= 0.0:
		return
	draw_line(Vector2(-span - 1.0, y), Vector2(span + 1.0, y), band_color, r * 0.16)
	# Knot on the back of the head.
	draw_circle(Vector2(-facing * span, y), r * 0.11, band_color)


func _draw_tails(r: float) -> void:
	var band_color: Color = _fighter.get("headband", Color.BLACK)
	var y := -r * 0.5
	var span := _half_width_at(y)
	if span <= 0.0:
		return
	var origin := Vector2(-facing * span, y)
	for t in range(2):
		var points := PackedVector2Array()
		var spread := (t - 0.5) * 0.35
		for i in range(5):
			var f := i / 4.0
			var wave := sin(_tail_phase - i * 0.9 + t * 1.3) * r * 0.16 * f
			points.append(origin + Vector2(-facing * f * r * 0.95, f * r * (0.35 + spread) + wave))
		draw_polyline(points, band_color, maxf(2.0, r * 0.12 * (1.0 - t * 0.2)), true)


func _draw_katana(r: float, outline: Color) -> void:
	var hilt := Vector2(-facing * r * 0.55, r * 0.15)
	var tip := hilt + Vector2(-facing * r * 0.85, -r * 0.95)
	draw_line(hilt, tip, Color(0.92, 0.94, 1.0), maxf(2.0, r * 0.08))
	draw_line(hilt, tip, outline, 1.0)
	var grip := hilt + Vector2(facing * r * 0.18, r * 0.25)
	draw_line(hilt, grip, Color(0.15, 0.12, 0.12), maxf(2.0, r * 0.1))
	draw_circle(hilt, r * 0.09, Color(0.85, 0.7, 0.25))


func _draw_eyes(r: float, body: Color) -> void:
	var eyes: int = _fighter.get("eyes", FighterRoster.Eyes.ROUND)
	var eye_y := -r * 0.12
	var look := look_direction.limit_length(1.0) * r * 0.07
	var squint := 0.0
	match expression:
		"attack":
			squint = 0.35
		"hurt":
			squint = 0.6
	var lid := maxf(_blink_amount, squint)

	match eyes:
		FighterRoster.Eyes.CYCLOPS:
			var center := Vector2(facing * r * 0.22, eye_y)
			var size := r * 0.36
			draw_circle(center, size, Color(0.98, 0.98, 1.0))
			draw_circle(center + look * 1.6, size * 0.6, Color(0.2, 0.85, 0.95))
			draw_circle(center + look * 1.6, size * 0.34, Color(0.05, 0.05, 0.1))
			draw_circle(center + look * 1.6 + Vector2(-size * 0.2, -size * 0.22), size * 0.12, Color.WHITE)
			_draw_lid(center, size, lid, body)
		FighterRoster.Eyes.DOT:
			for side: float in [0.5, 0.1]:
				var center := Vector2(facing * r * side, eye_y) + look
				draw_circle(center, r * 0.065, Color(0.08, 0.06, 0.08))
				var brow_y := eye_y - r * 0.22
				var brow_x := facing * r * side
				draw_line(Vector2(brow_x - facing * r * 0.1, brow_y + r * 0.04),
					Vector2(brow_x + facing * r * 0.1, brow_y - r * 0.02), Color(0.08, 0.06, 0.08), r * 0.05)
				if lid > 0.0:
					draw_circle(center, r * 0.09, body)
					draw_line(center - Vector2(r * 0.08, 0.0), center + Vector2(r * 0.08, 0.0), Color(0.08, 0.06, 0.08), r * 0.04)
			# A monocle for the aristocrat.
			var mono := Vector2(facing * r * 0.5, eye_y)
			draw_arc(mono, r * 0.17, 0.0, TAU, 20, Color(0.9, 0.75, 0.25), r * 0.035)
			draw_line(mono + Vector2(0.0, r * 0.17), mono + Vector2(-facing * r * 0.1, r * 0.45), Color(0.9, 0.75, 0.25), r * 0.025)
		_:
			var eye_size := r * 0.2
			var pupil_size := r * 0.09
			var pupil_color := Color(0.06, 0.05, 0.08)
			if eyes == FighterRoster.Eyes.WIDE:
				eye_size = r * 0.25
				pupil_size = r * 0.08
			elif eyes == FighterRoster.Eyes.SPARKLE:
				eye_size = r * 0.26
				pupil_size = r * 0.17
				pupil_color = Color(0.55, 0.12, 0.3)
			elif eyes == FighterRoster.Eyes.STAR:
				eye_size = r * 0.22
			for side: float in [0.46, 0.04]:
				var center := Vector2(facing * r * side, eye_y)
				draw_circle(center, eye_size, Color(0.98, 0.98, 1.0))
				var pupil_pos := center + look
				match eyes:
					FighterRoster.Eyes.STAR:
						var star := FighterRoster.shape_points(FighterRoster.Shape.STAR, pupil_size * 1.35)
						for i in range(star.size()):
							star[i] += pupil_pos
						draw_colored_polygon(star, Color(0.95, 0.45, 0.1))
					_:
						draw_circle(pupil_pos, pupil_size, pupil_color)
						if eyes == FighterRoster.Eyes.SPARKLE:
							draw_circle(pupil_pos + Vector2(-pupil_size * 0.35, -pupil_size * 0.4), pupil_size * 0.38, Color.WHITE)
							draw_circle(pupil_pos + Vector2(pupil_size * 0.35, pupil_size * 0.35), pupil_size * 0.18, Color.WHITE)
						elif eyes == FighterRoster.Eyes.WIDE:
							draw_circle(pupil_pos + Vector2(-pupil_size * 0.3, -pupil_size * 0.3), pupil_size * 0.3, Color.WHITE)
				var total_lid := lid
				match eyes:
					FighterRoster.Eyes.SLEEPY:
						total_lid = maxf(total_lid, 0.55)
					FighterRoster.Eyes.ANGRY:
						total_lid = maxf(total_lid, 0.15)
				_draw_lid(center, eye_size, total_lid, body)
				if eyes == FighterRoster.Eyes.ANGRY:
					# Slanted brow: high on the inside, low toward the front.
					var inner := center + Vector2(-facing * eye_size, -eye_size * 0.9)
					var outer := center + Vector2(facing * eye_size, -eye_size * 0.3)
					var brow := PackedVector2Array([inner, outer, outer + Vector2(0.0, eye_size * 0.55), inner + Vector2(0.0, eye_size * 0.2)])
					draw_colored_polygon(brow, body)
					draw_line(inner + Vector2(0.0, eye_size * 0.2), outer + Vector2(0.0, eye_size * 0.55), body.darkened(0.5), r * 0.05)
				elif eyes == FighterRoster.Eyes.SPARKLE:
					for i in range(3):
						var a := -PI * 0.5 - facing * (0.25 - i * 0.28)
						var base := center + Vector2(cos(a), sin(a)) * eye_size
						draw_line(base, base + Vector2(cos(a), sin(a)) * r * 0.12, Color(0.1, 0.05, 0.1), r * 0.035)
				elif eyes == FighterRoster.Eyes.SLEEPY:
					draw_line(center + Vector2(-eye_size * 0.9, -eye_size * 0.05), center + Vector2(eye_size * 0.9, -eye_size * 0.05), body.darkened(0.5), r * 0.045)


func _draw_lid(center: Vector2, eye_size: float, amount: float, body: Color) -> void:
	if amount <= 0.0:
		return
	var cover := eye_size * 2.0 * amount
	var rect := Rect2(center.x - eye_size - 1.0, center.y - eye_size - 1.0, eye_size * 2.0 + 2.0, cover)
	draw_rect(rect, body)
	if amount >= 0.98:
		draw_line(Vector2(center.x - eye_size, center.y), Vector2(center.x + eye_size, center.y), body.darkened(0.5), maxf(1.5, eye_size * 0.2))


## Horizontal half-extent of the body outline at height `y` (local, unscaled by radius).
func _half_width_at(y: float) -> float:
	var min_x := INF
	var max_x := -INF
	var count := _shape_points.size()
	for i in range(count):
		var a := _shape_points[i] * radius
		var b := _shape_points[(i + 1) % count] * radius
		if (a.y <= y and b.y >= y) or (b.y <= y and a.y >= y):
			if absf(b.y - a.y) < 0.0001:
				min_x = minf(min_x, minf(a.x, b.x))
				max_x = maxf(max_x, maxf(a.x, b.x))
			else:
				var t := (y - a.y) / (b.y - a.y)
				var x := lerpf(a.x, b.x, t)
				min_x = minf(min_x, x)
				max_x = maxf(max_x, x)
	if min_x == INF:
		return 0.0
	return (max_x - min_x) * 0.5
