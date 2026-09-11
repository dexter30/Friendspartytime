extends Node2D

@export var body_color: Color = Color.WHITE
@export var accent_color: Color = Color.BLACK
@export var shape_type: FighterData.Shape = FighterData.Shape.CIRCLE
@export var eye_style: FighterData.EyeStyle = FighterData.EyeStyle.CALM

var _flash: float = 0.0
var _squash := Vector2.ONE
var _attack_glow: float = 0.0
var _facing := 1


func setup_from_data(data: Dictionary) -> void:
	body_color = data["color"]
	accent_color = data["accent"]
	shape_type = data["shape"]
	eye_style = data["eyes"]
	queue_redraw()


func set_facing(dir: int) -> void:
	if dir != 0 and _facing != signi(dir):
		_facing = signi(dir)
		queue_redraw()


func flash_hit(strength: float = 1.0) -> void:
	_flash = strength


func set_squash(scale_vec: Vector2) -> void:
	_squash = scale_vec
	queue_redraw()


func set_attack_glow(amount: float) -> void:
	_attack_glow = amount
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.0, 0.0)
		queue_redraw()
	if _attack_glow > 0.0:
		_attack_glow = maxf(_attack_glow - delta * 3.0, 0.0)
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing, 1.0) * _squash)
	var draw_color := body_color.lerp(Color.WHITE, _flash * 0.75)
	if _attack_glow > 0.0:
		draw_color = draw_color.lerp(accent_color, _attack_glow * 0.6)

	match shape_type:
		FighterData.Shape.CIRCLE:
			draw_circle(Vector2.ZERO, 28.0, draw_color)
			draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 32, accent_color, 2.5, true)
		FighterData.Shape.SQUARE:
			draw_colored_polygon(_square_points(26.0), draw_color)
			_draw_poly_outline(_square_points(26.0), accent_color, 2.5)
		FighterData.Shape.TRIANGLE:
			draw_colored_polygon(_triangle_points(30.0), draw_color)
			_draw_poly_outline(_triangle_points(30.0), accent_color, 2.5)
		FighterData.Shape.PENTAGON:
			draw_colored_polygon(_regular_polygon(5, 28.0, -PI * 0.5), draw_color)
			_draw_poly_outline(_regular_polygon(5, 28.0, -PI * 0.5), accent_color, 2.5)
		FighterData.Shape.STAR:
			draw_colored_polygon(_star_points(14.0, 30.0), draw_color)
			_draw_poly_outline(_star_points(14.0, 30.0), accent_color, 2.0)
		FighterData.Shape.DIAMOND:
			draw_colored_polygon(_diamond_points(22.0, 34.0), draw_color)
			_draw_poly_outline(_diamond_points(22.0, 34.0), accent_color, 2.5)

	_draw_eyes()
	_draw_samurai_headband()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_eyes() -> void:
	var eye_y := -4.0
	var eye_spacing := 10.0
	match eye_style:
		FighterData.EyeStyle.CALM:
			draw_circle(Vector2(-eye_spacing, eye_y), 4.0, Color(0.08, 0.08, 0.12))
			draw_circle(Vector2(eye_spacing, eye_y), 4.0, Color(0.08, 0.08, 0.12))
			draw_circle(Vector2(-eye_spacing + 1.5, eye_y - 1.0), 1.5, Color.WHITE)
			draw_circle(Vector2(eye_spacing + 1.5, eye_y - 1.0), 1.5, Color.WHITE)
		FighterData.EyeStyle.FIERCE:
			draw_line(Vector2(-eye_spacing - 5, eye_y - 5), Vector2(-eye_spacing + 5, eye_y + 2), Color(0.08, 0.08, 0.12), 3.0, true)
			draw_line(Vector2(eye_spacing + 5, eye_y - 5), Vector2(eye_spacing - 5, eye_y + 2), Color(0.08, 0.08, 0.12), 3.0, true)
		FighterData.EyeStyle.WINK:
			draw_circle(Vector2(-eye_spacing, eye_y), 4.0, Color(0.08, 0.08, 0.12))
			draw_arc(Vector2(eye_spacing, eye_y), 4.0, 0.0, PI, 8, Color(0.08, 0.08, 0.12), 2.5, true)
		FighterData.EyeStyle.DOT:
			draw_circle(Vector2(-eye_spacing, eye_y), 5.0, accent_color)
			draw_circle(Vector2(eye_spacing, eye_y), 5.0, accent_color)
			draw_circle(Vector2(-eye_spacing, eye_y), 2.0, Color(0.08, 0.08, 0.12))
			draw_circle(Vector2(eye_spacing, eye_y), 2.0, Color(0.08, 0.08, 0.12))
		FighterData.EyeStyle.STAR:
			_draw_mini_star(Vector2(-eye_spacing, eye_y), 5.0, accent_color)
			_draw_mini_star(Vector2(eye_spacing, eye_y), 5.0, accent_color)
		FighterData.EyeStyle.SLIT:
			draw_line(Vector2(-eye_spacing - 4, eye_y), Vector2(-eye_spacing + 4, eye_y), Color(0.08, 0.08, 0.12), 3.0, true)
			draw_line(Vector2(eye_spacing - 4, eye_y), Vector2(eye_spacing + 4, eye_y), Color(0.08, 0.08, 0.12), 3.0, true)


func _draw_samurai_headband() -> void:
	draw_line(Vector2(-24, -18), Vector2(24, -18), accent_color, 4.0, true)
	draw_line(Vector2(22, -18), Vector2(34, -10), accent_color.lightened(0.2), 3.0, true)
	draw_line(Vector2(22, -18), Vector2(32, -24), accent_color.lightened(0.15), 2.5, true)


func _draw_poly_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		draw_line(a, b, color, width, true)


func _square_points(half: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])


func _triangle_points(size: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -size), Vector2(size * 0.95, size * 0.8), Vector2(-size * 0.95, size * 0.8),
	])


func _diamond_points(hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0),
	])


func _regular_polygon(sides: int, radius: float, rotation: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in range(sides):
		var angle := rotation + TAU * float(i) / float(sides)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts


func _star_points(inner: float, outer: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in range(10):
		var angle := -PI * 0.5 + TAU * float(i) / 10.0
		var radius := outer if i % 2 == 0 else inner
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts


func _draw_mini_star(center: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = []
	for i in range(10):
		var angle := -PI * 0.5 + TAU * float(i) / 10.0
		var r := radius if i % 2 == 0 else radius * 0.45
		pts.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(pts, color)
