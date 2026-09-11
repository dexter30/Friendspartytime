class_name FighterRoster
extends RefCounted

## Static roster for Samurai Gun. Every fighter is a simple shape; colour, eyes and
## name are what tell them apart, with light stat tweaks so each one plays a bit differently.

enum Shape { SQUARE, CIRCLE, TRIANGLE, DIAMOND, PENTAGON, HEXAGON, STAR, CAPSULE }

## Eye styles drawn procedurally by FighterVisual.
enum Eyes { ROUND, ANGRY, SLEEPY, WIDE, CYCLOPS, DOT, STAR, SPARKLE }

const FIGHTERS: Array[Dictionary] = [
	{
		"id": "ronin_rhombus",
		"name": "Ronin Rhombus",
		"tagline": "Sharp on every side.",
		"shape": Shape.DIAMOND,
		"eyes": Eyes.ANGRY,
		"color": Color(0.86, 0.2, 0.22),
		"headband": Color(0.1, 0.08, 0.1),
		"weight": 100.0,
		"run_speed": 340.0,
		"jump_force": 850.0,
		"size": 1.0,
	},
	{
		"id": "sensei_square",
		"name": "Sensei Square",
		"tagline": "Patience. Then pain.",
		"shape": Shape.SQUARE,
		"eyes": Eyes.SLEEPY,
		"color": Color(0.25, 0.32, 0.85),
		"headband": Color(0.95, 0.92, 0.85),
		"weight": 124.0,
		"run_speed": 285.0,
		"jump_force": 800.0,
		"size": 1.14,
	},
	{
		"id": "shuriken_tri",
		"name": "Shuriken Tri",
		"tagline": "Three points, zero mercy.",
		"shape": Shape.TRIANGLE,
		"eyes": Eyes.WIDE,
		"color": Color(0.2, 0.75, 0.45),
		"headband": Color(0.08, 0.1, 0.09),
		"weight": 84.0,
		"run_speed": 390.0,
		"jump_force": 890.0,
		"size": 0.92,
	},
	{
		"id": "daimyo_dot",
		"name": "Daimyo Dot",
		"tagline": "Rich in style, richer in stocks.",
		"shape": Shape.CIRCLE,
		"eyes": Eyes.DOT,
		"color": Color(0.98, 0.78, 0.2),
		"headband": Color(0.55, 0.1, 0.2),
		"weight": 104.0,
		"run_speed": 320.0,
		"jump_force": 930.0,
		"size": 1.02,
	},
	{
		"id": "hexa_hanzo",
		"name": "Hexa Hanzo",
		"tagline": "Six sides. One eye. No blind spots.",
		"shape": Shape.HEXAGON,
		"eyes": Eyes.CYCLOPS,
		"color": Color(0.58, 0.3, 0.85),
		"headband": Color(0.15, 0.9, 0.9),
		"weight": 100.0,
		"run_speed": 330.0,
		"jump_force": 850.0,
		"size": 1.0,
	},
	{
		"id": "penta_petal",
		"name": "Penta Petal",
		"tagline": "Blooms with every blow.",
		"shape": Shape.PENTAGON,
		"eyes": Eyes.SPARKLE,
		"color": Color(1.0, 0.55, 0.72),
		"headband": Color(0.35, 0.8, 0.45),
		"weight": 88.0,
		"run_speed": 350.0,
		"jump_force": 940.0,
		"size": 0.96,
	},
	{
		"id": "star_shogun",
		"name": "Star Shogun",
		"tagline": "Commands the night sky.",
		"shape": Shape.STAR,
		"eyes": Eyes.STAR,
		"color": Color(1.0, 0.52, 0.15),
		"headband": Color(0.2, 0.15, 0.4),
		"weight": 112.0,
		"run_speed": 305.0,
		"jump_force": 820.0,
		"size": 1.08,
	},
	{
		"id": "kappa_capsule",
		"name": "Kappa Capsule",
		"tagline": "Never fully awake. Never fully beaten.",
		"shape": Shape.CAPSULE,
		"eyes": Eyes.ROUND,
		"color": Color(0.2, 0.72, 0.72),
		"headband": Color(0.95, 0.35, 0.2),
		"weight": 96.0,
		"run_speed": 345.0,
		"jump_force": 860.0,
		"size": 1.0,
	},
]


static func count() -> int:
	return FIGHTERS.size()


static func get_fighter(index: int) -> Dictionary:
	return FIGHTERS[wrapi(index, 0, FIGHTERS.size())]


static func random_index() -> int:
	return randi() % FIGHTERS.size()


## Outline points (unit radius, centred on origin) for a shape. Circles are approximated.
static func shape_points(shape: Shape, radius: float = 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	match shape:
		Shape.SQUARE:
			points = PackedVector2Array([
				Vector2(-0.82, -0.82), Vector2(0.82, -0.82), Vector2(0.82, 0.82), Vector2(-0.82, 0.82)
			])
		Shape.TRIANGLE:
			points = PackedVector2Array([Vector2(0.0, -1.0), Vector2(1.0, 0.85), Vector2(-1.0, 0.85)])
		Shape.DIAMOND:
			points = PackedVector2Array([
				Vector2(0.0, -1.05), Vector2(0.78, 0.0), Vector2(0.0, 1.05), Vector2(-0.78, 0.0)
			])
		Shape.PENTAGON:
			points = _regular_polygon(5, -PI / 2.0)
		Shape.HEXAGON:
			points = _regular_polygon(6, 0.0)
		Shape.STAR:
			for i in range(10):
				var angle := -PI / 2.0 + i * PI / 5.0
				var r := 1.05 if i % 2 == 0 else 0.55
				points.append(Vector2(cos(angle), sin(angle)) * r)
		Shape.CAPSULE:
			for i in range(13):
				var angle := PI + i * PI / 12.0
				points.append(Vector2(cos(angle) * 0.72, -0.35 + sin(angle) * 0.72))
			for i in range(13):
				var angle := i * PI / 12.0
				points.append(Vector2(cos(angle) * 0.72, 0.35 + sin(angle) * 0.72))
		_:
			points = _regular_polygon(28, 0.0)
	for i in range(points.size()):
		points[i] *= radius
	return points


static func _regular_polygon(sides: int, start_angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle := start_angle + i * TAU / sides
		points.append(Vector2(cos(angle), sin(angle)))
	return points
