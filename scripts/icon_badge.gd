extends Control
## Lightweight vector insignia: readable on desktop and mobile without font emoji or extra textures.
const CYAN := Color("66f5df")
const AMBER := Color("ffc078")
const VIOLET := Color("b3a3ff")
var icon_id := "pulse"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(32, 32)

func _draw() -> void:
	var s := minf(size.x, size.y) / 36.0
	var center := size * 0.5
	var color := CYAN
	if icon_id in ["seeker", "barrage", "missile_bomber", "mine", "station", "bounty", "wraith"]:
		color = AMBER
	elif icon_id in ["arc", "arcwing", "chrono", "coolant", "tactician", "nyx"]:
		color = VIOLET
	draw_set_transform(center, 0.0, Vector2.ONE * s)
	draw_circle(Vector2.ZERO, 17.0, Color(color, 0.08))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 28, Color(color, 0.45), 1.3, true)
	match icon_id:
		"aegis", "shield", "regen", "reserve_shield", "emergency", "shieldguard":
			var points := PackedVector2Array([Vector2(0,-12),Vector2(11,-7),Vector2(9,7),Vector2(0,12),Vector2(-9,7),Vector2(-11,-7)])
			points.append(points[0])
			draw_polyline(points, color, 2.3, true)
			draw_line(Vector2(-4,0), Vector2(-1,4), color, 2.3, true)
			draw_line(Vector2(-1,4), Vector2(6,-4), color, 2.3, true)
		"nova", "amplifier":
			for i in range(8):
				var a: float = i * TAU / 8.0
				draw_line(Vector2.from_angle(a) * 5, Vector2.from_angle(a) * 13, color, 2.2, true)
			draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
		"seeker", "barrage", "wraith", "missile_bomber":
			draw_colored_polygon(PackedVector2Array([Vector2(0,-13),Vector2(6,0),Vector2(4,9),Vector2(-4,9),Vector2(-6,0)]), color)
			draw_circle(Vector2(0,-3), 2.5, Color("182636"))
			draw_line(Vector2(-4,10),Vector2(-7,14),AMBER,2.2,true)
			draw_line(Vector2(4,10),Vector2(7,14),AMBER,2.2,true)
		"pulse", "damage", "fire_rate", "autoloader", "munitions", "guidance", "targeting", "kestrel":
			for x in [-7,0,7]:
				draw_line(Vector2(x,10),Vector2(x,-11),color,2.8,true)
				draw_colored_polygon(PackedVector2Array([Vector2(x-3,-8),Vector2(x,-14),Vector2(x+3,-8)]),color)
		"arc", "arcwing", "chrono", "coolant":
			draw_colored_polygon(PackedVector2Array([Vector2(2,-13),Vector2(-8,2),Vector2(-1,2),Vector2(-4,13),Vector2(10,-4),Vector2(2,-4)]),color)
		"mend", "repair_bots", "repair", "hull", "armor", "bulwark", "haven", "engineer":
			draw_rect(Rect2(-3,-12,6,24),color)
			draw_rect(Rect2(-12,-3,24,6),color)
			draw_rect(Rect2(-2,-2,4,4),Color("182636"))
		"overdrive", "interceptor", "rusher", "ace":
			for x in [-8,0,8]:
				draw_line(Vector2(x,11), Vector2(x+5,-11), color, 3.0, true)
		"xp", "cores", "stipend", "bounty", "harvester", "scavenger":
			draw_arc(Vector2.ZERO, 11, 0, TAU, 32, color, 2.8, true)
			draw_line(Vector2(-4,-4),Vector2(4,4),color,2.4,true)
			draw_line(Vector2(4,-4),Vector2(-4,4),color,2.4,true)
		"extra_card", "rerolls", "banishes", "skips", "tactician":
			for i in range(3):
				draw_rect(Rect2(-10+i*5,-9+i*3,13,16),Color("142235"),true)
				draw_rect(Rect2(-10+i*5,-9+i*3,13,16),color,false,1.8)
		"boulder", "mine", "station":
			draw_colored_polygon(PackedVector2Array([Vector2(-12,-5),Vector2(-4,-13),Vector2(11,-7),Vector2(13,6),Vector2(1,13),Vector2(-13,8)]),Color(color,0.4))
			draw_circle(Vector2.ZERO,4,color)
		_:
			draw_colored_polygon(PackedVector2Array([Vector2(0,-13),Vector2(12,0),Vector2(0,13),Vector2(-12,0)]),color)
	draw_set_transform(Vector2.ZERO)
