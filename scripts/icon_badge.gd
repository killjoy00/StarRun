extends Control
## Lightweight vector insignia: readable on desktop and mobile without font emoji or extra textures.
const FusionArt = preload("res://scripts/fusion_art.gd")
const CYAN := Color("66f5df")
const AMBER := Color("ffc078")
const VIOLET := Color("b3a3ff")
const TRACK_ICONS := {"beam_plating": "armor", "shield_restart": "regen", "hazard_seals": "insulation", "warp_repairs": "mend", "arc_start": "arc", "lance_start": "pulse", "boss_damage": "boss_hunter", "ordnance_damage": "seeker", "signature_rank": "amplifier", "cast_repair": "repair", "opening_charge": "coolant", "reroll_focus": "rerolls", "banish_relay": "banishes", "skip_patch": "skips", "module_salvage": "cores", "clean_clear": "bounty"}
var icon_id := "pulse"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(32, 32)

func _draw() -> void:
	var display_id: String = str(TRACK_ICONS.get(icon_id,icon_id))
	var s := minf(size.x, size.y) / 36.0
	var center := size * 0.5
	var color := CYAN
	if display_id in ["seeker", "barrage", "missile_bomber", "mine", "station", "bounty", "wraith"]:
		color = AMBER
	elif display_id in ["arc", "arcwing", "chrono", "coolant", "tactician", "nyx"]:
		color = VIOLET
	draw_set_transform(center, 0.0, Vector2.ONE * s)
	if FusionArt.PALETTES.has(display_id):
		FusionArt.badge(self, display_id)
		draw_set_transform(Vector2.ZERO)
		return
	draw_circle(Vector2.ZERO, 17.0, Color(color, 0.08))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 28, Color(color, 0.45), 1.3, true)
	match display_id:
		"wing_drones":
			for side in [-1,1]:
				var p := Vector2(side*7,0)
				draw_colored_polygon(PackedVector2Array([p+Vector2(0,-10),p+Vector2(5,6),p,p+Vector2(-5,6)]),CYAN)
				draw_line(p+Vector2(0,6),p+Vector2(0,11),Color.WHITE,1.6,true)
		"ion_mine":
			draw_colored_polygon(FusionArt.polygon(Vector2.ZERO,7,4),VIOLET)
			for i in range(4):
				var v := Vector2.from_angle(i*TAU/4)
				draw_line(v*8,v*13,CYAN,2,true)
			draw_circle(Vector2.ZERO,2,Color.WHITE)
		"aegis", "shield", "regen", "reserve_shield", "emergency", "shieldguard", "ablative", "insulation", "shield_surge", "shield_focus":
			var points := PackedVector2Array([Vector2(0,-12),Vector2(11,-7),Vector2(9,7),Vector2(0,12),Vector2(-9,7),Vector2(-11,-7)])
			points.append(points[0])
			draw_polyline(points, color, 2.3, true)
			draw_line(Vector2(-4,0), Vector2(-1,4), color, 2.3, true)
			draw_line(Vector2(-1,4), Vector2(6,-4), color, 2.3, true)
		"boss_hunter", "finisher", "opening_salvo":
			draw_arc(Vector2.ZERO, 10, 0, TAU, 24, color, 2.0, true)
			draw_line(Vector2(-14, 0), Vector2(14, 0), color, 1.5, true)
			draw_line(Vector2(0, -14), Vector2(0, 14), color, 1.5, true)
			draw_circle(Vector2.ZERO, 3, Color.WHITE)
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
		"mend", "repair_bots", "repair", "hull", "armor", "bulwark", "haven", "engineer", "field_medic", "last_stand":
			draw_rect(Rect2(-3,-12,6,24),color)
			draw_rect(Rect2(-12,-3,24,6),color)
			draw_rect(Rect2(-2,-2,4,4),Color("182636"))
		"overdrive", "interceptor", "rusher", "ace", "afterburn":
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
		"flak":
			for offset in [Vector2(-9,-8), Vector2(0,-11), Vector2(9,-8), Vector2(-8,4), Vector2(8,4)]:
				draw_circle(offset, 2.7, AMBER)
			draw_arc(Vector2(0,9), 12, PI+0.2, TAU-0.2, 18, color, 2.5, true)
		"emp":
			draw_circle(Vector2.ZERO, 3, Color.WHITE)
			for radius in [7.0, 12.0]:
				for quadrant in range(4):
					draw_arc(Vector2.ZERO, radius, quadrant * PI/2.0+0.23, (quadrant+1) * PI/2.0-0.23, 8, color, 2.3, true)
		"deflector":
			draw_colored_polygon(PackedVector2Array([Vector2(-12,-7),Vector2(0,-14),Vector2(12,-7),Vector2(9,7),Vector2(0,13),Vector2(-9,7)]),Color(color,0.25))
			for x in [-6,0,6]:
				draw_line(Vector2(x,-8),Vector2(x*0.6,7),color,2.5,true)
		"strike":
			draw_line(Vector2(0,-15),Vector2(0,13),color,4,true)
			draw_line(Vector2(-11,-6),Vector2(11,-6),Color.WHITE,1.5,true)
			draw_colored_polygon(PackedVector2Array([Vector2(-7,-9),Vector2(0,-16),Vector2(7,-9)]),AMBER)
		"prism":
			draw_colored_polygon(PackedVector2Array([Vector2(0,-13),Vector2(13,9),Vector2(-13,9)]),Color(color,0.17))
			draw_polyline(PackedVector2Array([Vector2(0,-13),Vector2(13,9),Vector2(-13,9),Vector2(0,-13)]),color,2.4,true)
			draw_line(Vector2(-13,-3),Vector2(1,2),Color.WHITE,2,true)
			draw_line(Vector2(1,2),Vector2(15,-2),VIOLET,2.5,true)
		"barrier":
			for x in [-10,0,10]:
				draw_rect(Rect2(x-4,-11,8,9),Color(color,0.60),true)
				draw_rect(Rect2(x-4,0,8,9),color,false,2.0)
		"capacitor":
			for x in [-8,8]:
				draw_line(Vector2(x,-12),Vector2(x,12),color,4,true)
			draw_colored_polygon(PackedVector2Array([Vector2(-4,-9),Vector2(3,-9),Vector2(-2,1),Vector2(4,1),Vector2(-3,12),Vector2(-1,3),Vector2(-7,3)]),Color.WHITE)
		"focus":
			draw_arc(Vector2.ZERO,11,0,TAU,28,color,2.0,true)
			for angle in [0.0, PI/2.0, PI, PI*1.5]:
				draw_line(Vector2.from_angle(angle)*6,Vector2.from_angle(angle)*15,color,2.2,true)
			draw_circle(Vector2.ZERO,2.5,AMBER)
		"decoy":
			draw_colored_polygon(PackedVector2Array([Vector2(0,-13),Vector2(6,9),Vector2(0,6),Vector2(-6,9)]),color)
			for side in [-1,1]:
				draw_arc(Vector2(side*2,0),10,-PI/3.0 if side>0 else PI*2.0/3.0,PI/3.0 if side>0 else PI*4.0/3.0,12,AMBER,2.0,true)
		"jammer":
			for y in [-9,0,9]:
				draw_line(Vector2(-13,y),Vector2(-4,y-4),color,2.2,true)
				draw_line(Vector2(-4,y-4),Vector2(4,y+4),color,2.2,true)
				draw_line(Vector2(4,y+4),Vector2(13,y),color,2.2,true)
			draw_line(Vector2(-13,13),Vector2(13,-13),Color.WHITE,1.8,true)
		"siphon":
			draw_circle(Vector2(-8,-6),6,Color(color,0.35))
			draw_circle(Vector2(8,6),6,Color(AMBER,0.4))
			draw_arc(Vector2.ZERO,11,PI*0.8,TAU*0.98,18,color,2.8,true)
			draw_colored_polygon(PackedVector2Array([Vector2(12,-2),Vector2(15,5),Vector2(7,3)]),color)
		"overload":
			for x in [-9,0,9]:
				draw_circle(Vector2(x,0),4,color)
			draw_line(Vector2(-9,0),Vector2(0,-9),AMBER,2,true)
			draw_line(Vector2(0,-9),Vector2(9,0),AMBER,2,true)
			draw_line(Vector2(0,-9),Vector2(0,12),Color.WHITE,2,true)
		"reboot":
			draw_arc(Vector2.ZERO,11,-PI*0.68,PI*1.68,30,color,3,true)
			draw_line(Vector2(0,-15),Vector2(0,1),Color.WHITE,3,true)
			draw_circle(Vector2(0,12),1.5,AMBER)
		"salvage":
			draw_line(Vector2(-10,-12),Vector2(-10,4),color,4,true)
			draw_line(Vector2(10,-12),Vector2(10,4),color,4,true)
			draw_arc(Vector2(0,4),10,0,PI,16,color,4,true)
			draw_rect(Rect2(-13,-14,6,5),AMBER,true)
			draw_rect(Rect2(7,-14,6,5),AMBER,true)
		"gravity":
			draw_circle(Vector2.ZERO,4,color)
			draw_arc(Vector2.ZERO,12,0,TAU,30,Color(color,0.8),2.2,true)
		"heat":
			draw_colored_polygon(PackedVector2Array([Vector2(-4,-14),Vector2(5,-4),Vector2(1,3),Vector2(8,12),Vector2(-8,12),Vector2(-5,3)]),color)
		_:
			draw_colored_polygon(PackedVector2Array([Vector2(0,-13),Vector2(12,0),Vector2(0,13),Vector2(-12,0)]),color)
	draw_set_transform(Vector2.ZERO)
