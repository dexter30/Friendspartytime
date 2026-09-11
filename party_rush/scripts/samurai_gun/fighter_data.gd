class_name FighterData
extends RefCounted

enum Shape { CIRCLE, SQUARE, TRIANGLE, PENTAGON, STAR, DIAMOND }
enum EyeStyle { CALM, FIERCE, WINK, DOT, STAR, SLIT }

const ROSTER: Array[Dictionary] = [
	{
		"id": 0,
		"name": "Circle Ronin",
		"tagline": "Round and relentless",
		"shape": Shape.CIRCLE,
		"eyes": EyeStyle.CALM,
		"color": Color(0.92, 0.22, 0.28),
		"accent": Color(1.0, 0.75, 0.35),
	},
	{
		"id": 1,
		"name": "Block Samurai",
		"tagline": "Square deal, sharp steel",
		"shape": Shape.SQUARE,
		"eyes": EyeStyle.FIERCE,
		"color": Color(0.28, 0.48, 0.95),
		"accent": Color(0.65, 0.85, 1.0),
	},
	{
		"id": 2,
		"name": "Tri-Shogun",
		"tagline": "Three points of pain",
		"shape": Shape.TRIANGLE,
		"eyes": EyeStyle.SLIT,
		"color": Color(0.18, 0.78, 0.45),
		"accent": Color(0.55, 1.0, 0.65),
	},
	{
		"id": 3,
		"name": "Pentagon Pistoleer",
		"tagline": "Five sides, one shot",
		"shape": Shape.PENTAGON,
		"eyes": EyeStyle.DOT,
		"color": Color(0.62, 0.28, 0.82),
		"accent": Color(0.9, 0.55, 1.0),
	},
	{
		"id": 4,
		"name": "Star Gunshin",
		"tagline": "Cosmic kaboom",
		"shape": Shape.STAR,
		"eyes": EyeStyle.STAR,
		"color": Color(0.98, 0.78, 0.15),
		"accent": Color(1.0, 0.95, 0.55),
	},
	{
		"id": 5,
		"name": "Diamond Blade",
		"tagline": "Cut like crystal",
		"shape": Shape.DIAMOND,
		"eyes": EyeStyle.WINK,
		"color": Color(0.15, 0.82, 0.88),
		"accent": Color(0.65, 1.0, 1.0),
	},
]


static func get_fighter(id: int) -> Dictionary:
	return ROSTER[id % ROSTER.size()]


static func roster_size() -> int:
	return ROSTER.size()
