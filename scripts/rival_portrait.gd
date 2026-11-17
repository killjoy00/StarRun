extends Control
## Original vector-drawn helmet portrait. The seed changes faceplate, warning
## stripes and visor: distinct captains remain recognizable without image files.
const RED := Color("ff777b")
const AMBER := Color("ffc078")
const INK := Color("081321")
var rival: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(136, 158)

func _draw() -> void:
	var side: float = minf(size.x, size.y * 0.88)
	if side <= 0.0:
		return
	var seed_value := int(rival.get("portrait_seed", 31))
	var accent: Color = [RED, AMBER, Color("d18cfa"), Color("73dce3")][posmod(seed_value, 4)]
	draw_set_transform(Vector2((size.x-side)/2.0, (size.y-side)/2.0), 0.0, Vector2.ONE * (side / 160.0))
	draw_rect(Rect2(0, 0, 160, 160), INK)
	draw_rect(Rect2(4, 4, 152, 152), accent, false, 3)
	for i in range(5):
		draw_line(Vector2(7+i*30, 4),Vector2(0+i*30, 12),Color(accent,0.38),2)
		draw_line(Vector2(160-i*30,148),Vector2(148-i*30,160),Color(accent,0.38),2)
	# Suit and collar silhouette.
	draw_colored_polygon(PackedVector2Array([Vector2(19,151),Vector2(28,112),Vector2(57,99),Vector2(103,99),Vector2(133,112),Vector2(142,151)]),Color("25374e"))
	draw_colored_polygon(PackedVector2Array([Vector2(45,104),Vector2(80,128),Vector2(115,104),Vector2(109,151),Vector2(51,151)]),Color("3c4b63"))
	draw_colored_polygon(PackedVector2Array([Vector2(53,110),Vector2(80,130),Vector2(107,110),Vector2(94,143),Vector2(66,143)]),Color("132a38"))
	# Broad helmet with asymmetric armour cuts, not a generic avatar circle.
	var cheek := float(posmod(seed_value, 5) * 2)
	draw_colored_polygon(PackedVector2Array([Vector2(48,100),Vector2(33,77),Vector2(40,40),Vector2(57,23),Vector2(98,23),Vector2(119,40),Vector2(126,77),Vector2(111,100),Vector2(80,116)]),Color("4d6377"))
	draw_colored_polygon(PackedVector2Array([Vector2(52,92),Vector2(45,64),Vector2(56,42),Vector2(102,42),Vector2(114,64),Vector2(106,92),Vector2(80,108)]),Color("14283b"))
	draw_colored_polygon(PackedVector2Array([Vector2(51,60),Vector2(109,60),Vector2(111,79),Vector2(99,89),Vector2(60,89),Vector2(49,79)]),Color("030f1e"))
	var slit: float = float(posmod(seed_value, 4) + 3)
	draw_line(Vector2(53,69),Vector2(107,69+cheek*0.5),accent,slit,true)
	draw_line(Vector2(55,78),Vector2(102,78),Color(accent,0.42),2,true)
	draw_line(Vector2(80,24),Vector2(80,48),Color("c1cbd2"),3,true)
	draw_line(Vector2(43,58),Vector2(49,92),accent,2,true)
	draw_line(Vector2(116,58),Vector2(109,92),accent,2,true)
	for i in range(3):
		draw_rect(Rect2(62+i*14,98,9,3),accent)
	draw_rect(Rect2(14,137,22,7),accent)
	draw_rect(Rect2(124,137,22,7),accent)
	# Unmissable (!) is part of the actual portrait artwork.
	draw_circle(Vector2(130,29),20,Color("8a242d"))
	draw_circle(Vector2(130,29),17,AMBER)
	draw_line(Vector2(130,20),Vector2(130,31),INK,5,true)
	draw_circle(Vector2(130,38),2.7,INK)
	draw_set_transform(Vector2.ZERO)
