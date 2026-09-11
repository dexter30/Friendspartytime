class_name DojoStage
extends Node2D

## "Moonlit Dojo": a Battlefield-style floating stage with one main deck and three
## soft platforms, under a big moon with drifting cherry blossoms. Geometry and
## visuals are built in code; the arena reads spawn points, blast zones and bounds.

const FLOOR_Y := 200.0
const MAIN_HALF_WIDTH := 490.0
const MAIN_THICKNESS := 52.0
const SIDE_PLATFORM_Y := 50.0
const SIDE_PLATFORM_X := 300.0
const SIDE_PLATFORM_HALF_WIDTH := 112.0
const TOP_PLATFORM_Y := -110.0
const TOP_PLATFORM_HALF_WIDTH := 100.0
const PLATFORM_THICKNESS := 14.0

const BLAST_RECT := Rect2(-1250.0, -950.0, 2500.0, 1760.0)
const CAMERA_BOUNDS := Rect2(-1060.0, -830.0, 2120.0, 1440.0)
const REVIVAL_POINT := Vector2(0.0, -330.0)
const SPAWN_XS: Array[float] = [-330.0, 330.0, 0.0]

var _far: Node2D
var _far_drawer: Node2D
var _mid: Node2D
var _time := 0.0
var _stars: Array[Vector3] = []
var _petals: CPUParticles2D


func _ready() -> void:
	z_index = -10
	_build_background()
	_build_geometry()
	_build_petals()
	_stars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(110):
		_stars.append(Vector3(rng.randf_range(-2200.0, 2200.0), rng.randf_range(-1500.0, -50.0), rng.randf_range(1.0, 2.6)))


func spawn_point(index: int, size_scale: float) -> Vector2:
	var x: float = SPAWN_XS[index % SPAWN_XS.size()]
	return Vector2(x, FLOOR_Y - 29.0 * size_scale - 1.0)


func stage_half_width() -> float:
	return MAIN_HALF_WIDTH


## Parallax: called by the arena with the camera position each frame.
func update_parallax(camera_position: Vector2) -> void:
	_far.position = camera_position * 0.3 + Vector2(0.0, 40.0)
	_mid.position = camera_position * 0.12


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	_far_drawer.queue_redraw()


func _build_geometry() -> void:
	var main := StaticBody2D.new()
	main.name = "MainDeck"
	main.collision_layer = 1
	main.collision_mask = 0
	var main_shape := CollisionShape2D.new()
	var main_rect := RectangleShape2D.new()
	main_rect.size = Vector2(MAIN_HALF_WIDTH * 2.0, MAIN_THICKNESS)
	main_shape.shape = main_rect
	main_shape.position = Vector2(0.0, FLOOR_Y + MAIN_THICKNESS * 0.5)
	main.add_child(main_shape)
	add_child(main)

	_add_soft_platform(Vector2(-SIDE_PLATFORM_X, SIDE_PLATFORM_Y), SIDE_PLATFORM_HALF_WIDTH)
	_add_soft_platform(Vector2(SIDE_PLATFORM_X, SIDE_PLATFORM_Y), SIDE_PLATFORM_HALF_WIDTH)
	_add_soft_platform(Vector2(0.0, TOP_PLATFORM_Y), TOP_PLATFORM_HALF_WIDTH)


func _add_soft_platform(top_center: Vector2, half_width: float) -> void:
	var body := StaticBody2D.new()
	body.name = "SoftPlatform"
	body.collision_layer = 16
	body.collision_mask = 0
	body.add_to_group("soft_platform")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(half_width * 2.0, PLATFORM_THICKNESS)
	shape.shape = rect
	shape.one_way_collision = true
	shape.one_way_collision_margin = 6.0
	shape.position = top_center + Vector2(0.0, PLATFORM_THICKNESS * 0.5)
	body.add_child(shape)
	add_child(body)


func _build_background() -> void:
	_far = Node2D.new()
	_far.name = "Far"
	_far.z_index = -30
	add_child(_far)
	var sky := Polygon2D.new()
	sky.polygon = PackedVector2Array([
		Vector2(-3200.0, -2000.0), Vector2(3200.0, -2000.0), Vector2(3200.0, 1600.0), Vector2(-3200.0, 1600.0)
	])
	sky.vertex_colors = PackedColorArray([
		Color(0.05, 0.04, 0.12), Color(0.05, 0.04, 0.12), Color(0.32, 0.14, 0.32), Color(0.32, 0.14, 0.32)
	])
	_far.add_child(sky)
	_far_drawer = Node2D.new()
	_far_drawer.name = "FarDrawer"
	_far_drawer.draw.connect(_draw_far.bind(_far_drawer))
	_far.add_child(_far_drawer)

	_mid = Node2D.new()
	_mid.name = "Mid"
	_mid.z_index = -20
	add_child(_mid)
	var mid_drawer := Node2D.new()
	mid_drawer.name = "MidDrawer"
	mid_drawer.draw.connect(_draw_mid.bind(mid_drawer))
	_mid.add_child(mid_drawer)


func _build_petals() -> void:
	_petals = CPUParticles2D.new()
	_petals.name = "Petals"
	_petals.amount = 70
	_petals.lifetime = 9.0
	_petals.preprocess = 9.0
	_petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_petals.emission_rect_extents = Vector2(1400.0, 40.0)
	_petals.position = Vector2(200.0, -900.0)
	_petals.direction = Vector2(-0.5, 1.0)
	_petals.spread = 20.0
	_petals.gravity = Vector2(-15.0, 45.0)
	_petals.initial_velocity_min = 40.0
	_petals.initial_velocity_max = 90.0
	_petals.angular_velocity_min = -160.0
	_petals.angular_velocity_max = 160.0
	_petals.scale_amount_min = 0.9
	_petals.scale_amount_max = 1.8
	_petals.color = Color(1.0, 0.72, 0.82, 0.9)
	var texture := GradientTexture2D.new()
	texture.width = 8
	texture.height = 8
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.95, 0.5)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.7, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(2, Color(1.0, 1.0, 1.0, 0.0))
	texture.gradient = gradient
	_petals.texture = texture
	_petals.z_index = 5
	add_child(_petals)


func _draw_far(drawer: Node2D) -> void:
	for star in _stars:
		var twinkle := 0.6 + 0.4 * sin(_time * 2.0 + star.x * 0.01)
		drawer.draw_circle(Vector2(star.x, star.y), star.z, Color(1.0, 0.98, 0.9, twinkle))
	var moon := Vector2(-420.0, -330.0)
	drawer.draw_circle(moon, 190.0, Color(1.0, 0.93, 0.7, 0.12))
	drawer.draw_circle(moon, 150.0, Color(1.0, 0.94, 0.75, 0.2))
	drawer.draw_circle(moon, 120.0, Color(0.98, 0.94, 0.8))
	drawer.draw_circle(moon + Vector2(-40.0, -20.0), 22.0, Color(0.9, 0.86, 0.72))
	drawer.draw_circle(moon + Vector2(35.0, 40.0), 14.0, Color(0.9, 0.86, 0.72))
	drawer.draw_circle(moon + Vector2(20.0, -60.0), 10.0, Color(0.9, 0.86, 0.72))
	# Distant mountain ridges.
	var ridge_far := PackedVector2Array([Vector2(-3200.0, 1600.0), Vector2(-3200.0, 260.0)])
	var x := -3200.0
	var i := 0
	while x < 3200.0:
		ridge_far.append(Vector2(x, 260.0 - absf(sin(i * 1.7)) * 260.0 - (i % 3) * 40.0))
		x += 260.0
		i += 1
	ridge_far.append(Vector2(3200.0, 260.0))
	ridge_far.append(Vector2(3200.0, 1600.0))
	drawer.draw_colored_polygon(ridge_far, Color(0.16, 0.1, 0.24))


func _draw_mid(drawer: Node2D) -> void:
	var ridge := PackedVector2Array([Vector2(-2600.0, 1600.0), Vector2(-2600.0, 420.0)])
	var x := -2600.0
	var i := 0
	while x < 2600.0:
		ridge.append(Vector2(x, 420.0 - absf(cos(i * 2.3)) * 180.0 - (i % 2) * 60.0))
		x += 200.0
		i += 1
	ridge.append(Vector2(2600.0, 420.0))
	ridge.append(Vector2(2600.0, 1600.0))
	drawer.draw_colored_polygon(ridge, Color(0.1, 0.07, 0.17))
	# Pagoda silhouette behind the stage.
	var base_y := 380.0
	var pagoda_color := Color(0.07, 0.05, 0.12)
	for level in range(3):
		var w := 260.0 - level * 60.0
		var y := base_y - level * 120.0
		drawer.draw_rect(Rect2(-w * 0.35, y - 90.0, w * 0.7, 90.0), pagoda_color)
		var roof := PackedVector2Array([
			Vector2(-w * 0.62, y - 80.0), Vector2(-w * 0.3, y - 130.0), Vector2(w * 0.3, y - 130.0), Vector2(w * 0.62, y - 80.0),
			Vector2(w * 0.5, y - 92.0), Vector2(-w * 0.5, y - 92.0)
		])
		drawer.draw_colored_polygon(roof, pagoda_color)
	drawer.draw_line(Vector2(0.0, base_y - 370.0), Vector2(0.0, base_y - 430.0), pagoda_color, 6.0)
	# Cherry trees on the far sides.
	for side: float in [-1.0, 1.0]:
		var trunk := Vector2(side * 1150.0, 460.0)
		drawer.draw_line(trunk, trunk + Vector2(-side * 30.0, -220.0), Color(0.12, 0.08, 0.1), 22.0)
		drawer.draw_circle(trunk + Vector2(-side * 40.0, -280.0), 130.0, Color(0.55, 0.22, 0.38))
		drawer.draw_circle(trunk + Vector2(-side * 120.0, -230.0), 90.0, Color(0.6, 0.25, 0.42))
		drawer.draw_circle(trunk + Vector2(side * 30.0, -210.0), 95.0, Color(0.5, 0.2, 0.36))


func _draw() -> void:
	_draw_main_deck()
	_draw_soft_platform(Vector2(-SIDE_PLATFORM_X, SIDE_PLATFORM_Y), SIDE_PLATFORM_HALF_WIDTH)
	_draw_soft_platform(Vector2(SIDE_PLATFORM_X, SIDE_PLATFORM_Y), SIDE_PLATFORM_HALF_WIDTH)
	_draw_soft_platform(Vector2(0.0, TOP_PLATFORM_Y), TOP_PLATFORM_HALF_WIDTH)
	_draw_lanterns()


func _draw_main_deck() -> void:
	var left := -MAIN_HALF_WIDTH
	var right := MAIN_HALF_WIDTH
	var top := FLOOR_Y
	var bottom := FLOOR_Y + MAIN_THICKNESS
	# Stone underside tapering to a point, like a floating island.
	var rock := PackedVector2Array([
		Vector2(left, bottom), Vector2(right, bottom), Vector2(right - 120.0, bottom + 110.0),
		Vector2(140.0, bottom + 210.0), Vector2(-60.0, bottom + 260.0), Vector2(-260.0, bottom + 180.0),
		Vector2(left + 110.0, bottom + 100.0)
	])
	draw_colored_polygon(rock, Color(0.2, 0.17, 0.26))
	var rock_shadow := PackedVector2Array([
		Vector2(left + 60.0, bottom + 20.0), Vector2(right - 60.0, bottom + 20.0), Vector2(120.0, bottom + 180.0),
		Vector2(-60.0, bottom + 220.0), Vector2(-220.0, bottom + 150.0)
	])
	draw_colored_polygon(rock_shadow, Color(0.14, 0.11, 0.2))
	# Wooden deck.
	draw_rect(Rect2(left, top, right - left, MAIN_THICKNESS), Color(0.45, 0.26, 0.16))
	var plank_width := 70.0
	var x := left
	var i := 0
	while x < right:
		var shade := 0.0 if i % 2 == 0 else 0.04
		draw_rect(Rect2(x + 2.0, top + 4.0, minf(plank_width, right - x) - 4.0, MAIN_THICKNESS - 8.0), Color(0.55 + shade, 0.33 + shade, 0.2 + shade))
		x += plank_width
		i += 1
	draw_rect(Rect2(left, top, right - left, 6.0), Color(0.72, 0.5, 0.32))
	draw_rect(Rect2(left, bottom - 8.0, right - left, 8.0), Color(0.28, 0.16, 0.1))
	# Red trim bars along the edge, dojo style.
	draw_rect(Rect2(left, top - 4.0, right - left, 4.0), Color(0.75, 0.16, 0.18))
	for post_x: float in [left + 30.0, right - 30.0]:
		draw_rect(Rect2(post_x - 8.0, top - 70.0, 16.0, 70.0), Color(0.75, 0.16, 0.18))
		draw_rect(Rect2(post_x - 16.0, top - 78.0, 32.0, 10.0), Color(0.85, 0.22, 0.22))


func _draw_soft_platform(top_center: Vector2, half_width: float) -> void:
	var rect := Rect2(top_center.x - half_width, top_center.y, half_width * 2.0, PLATFORM_THICKNESS)
	draw_rect(rect.grow_individual(0.0, 0.0, 0.0, 6.0), Color(0.2, 0.12, 0.1))
	draw_rect(rect, Color(0.62, 0.38, 0.22))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), Color(0.82, 0.58, 0.36))
	draw_rect(Rect2(rect.position.x, rect.position.y - 3.0, rect.size.x, 3.0), Color(0.75, 0.16, 0.18))
	# Tassels swinging under the platform.
	for t in range(3):
		var tx := rect.position.x + rect.size.x * (0.2 + 0.3 * t)
		var sway := sin(_time * 2.0 + tx * 0.05) * 5.0
		draw_line(Vector2(tx, rect.end.y + 6.0), Vector2(tx + sway, rect.end.y + 22.0), Color(0.9, 0.75, 0.3), 3.0)
		draw_circle(Vector2(tx + sway, rect.end.y + 24.0), 3.5, Color(0.9, 0.3, 0.3))


func _draw_lanterns() -> void:
	for side: float in [-1.0, 1.0]:
		var post_x := side * (MAIN_HALF_WIDTH - 30.0)
		var bob := sin(_time * 1.6 + side) * 3.0
		var lantern := Vector2(post_x, FLOOR_Y - 100.0 + bob)
		var glow := 0.18 + 0.05 * sin(_time * 5.0 + side * 2.0)
		draw_circle(lantern, 70.0, Color(1.0, 0.7, 0.3, glow * 0.5))
		draw_circle(lantern, 40.0, Color(1.0, 0.75, 0.35, glow))
		draw_line(Vector2(post_x, FLOOR_Y - 70.0), lantern + Vector2(0.0, 18.0), Color(0.3, 0.2, 0.15), 2.0)
		var body := Rect2(lantern.x - 14.0, lantern.y - 18.0, 28.0, 36.0)
		draw_rect(body, Color(1.0, 0.62, 0.25))
		draw_rect(Rect2(body.position.x, body.position.y - 4.0, body.size.x, 4.0), Color(0.2, 0.12, 0.1))
		draw_rect(Rect2(body.position.x, body.end.y, body.size.x, 4.0), Color(0.2, 0.12, 0.1))
		draw_line(Vector2(body.position.x + 6.0, body.position.y), Vector2(body.position.x + 6.0, body.end.y), Color(0.85, 0.4, 0.15), 1.5)
		draw_line(Vector2(body.end.x - 6.0, body.position.y), Vector2(body.end.x - 6.0, body.end.y), Color(0.85, 0.4, 0.15), 1.5)
