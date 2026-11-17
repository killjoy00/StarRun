extends Control
## Original procedural silhouette for the traveling quartermaster. Cargo cases,
## asymmetrical antenna and an amber transponder make the shop recognizable.
const INK := Color("081320")
const GOLD := Color("ffc078")
const CYAN := Color("66f5df")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(122, 132)

func _draw() -> void:
	var side: float = minf(size.x, size.y * 0.92)
	if side <= 0.0:
		return
	draw_set_transform(Vector2((size.x - side)*0.5,(size.y-side)*0.5),0.0,Vector2.ONE*(side/150.0))
	draw_rect(Rect2(0,0,150,150),INK)
	draw_rect(Rect2(3,3,144,144),GOLD,false,2.5)
	for n in range(4):
		draw_line(Vector2(10+n*34,7),Vector2(n*34,20),Color(GOLD,0.33),1.4)
	# Asymmetrical ore freight ship and stacked licensed/unlicensed crates.
	draw_colored_polygon(PackedVector2Array([Vector2(22,116),Vector2(30,61),Vector2(43,38),Vector2(92,31),Vector2(119,61),Vector2(125,117),Vector2(84,137),Vector2(58,137)]),Color("536879"))
	draw_colored_polygon(PackedVector2Array([Vector2(42,65),Vector2(49,45),Vector2(89,40),Vector2(108,65),Vector2(98,104),Vector2(59,105)]),Color("152b3a"))
	draw_colored_polygon(PackedVector2Array([Vector2(54,71),Vector2(64,55),Vector2(90,54),Vector2(96,71),Vector2(82,84),Vector2(66,83)]),Color("ffba67"))
	draw_line(Vector2(64,72),Vector2(88,72),CYAN,3,true)
	draw_rect(Rect2(17,80,28,34),Color("374a60"))
	draw_rect(Rect2(17,80,28,34),GOLD,false,2)
	draw_line(Vector2(21,88),Vector2(40,88),Color(GOLD,0.85),2,true)
	draw_rect(Rect2(110,80,24,26),Color("374a60"))
	draw_rect(Rect2(110,80,24,26),GOLD,false,2)
	draw_line(Vector2(122,80),Vector2(122,106),GOLD,2,true)
	draw_line(Vector2(74,39),Vector2(74,14),CYAN,2.2,true)
	draw_circle(Vector2(74,13),5,CYAN)
	for x in [45.0,103.0]:
		draw_rect(Rect2(x-6,118,12,13),Color("ff8b54"))
		draw_rect(Rect2(x-3,128,6,8),Color("f9d8a3"))
	# Amber hail beacon — merchant is a choice, not an enemy target.
	draw_circle(Vector2(122,28),17,Color("784818"))
	draw_circle(Vector2(122,28),14,GOLD)
	draw_string(ThemeDB.fallback_font,Vector2(115,37),"?",HORIZONTAL_ALIGNMENT_LEFT,20,25,INK)
	draw_set_transform(Vector2.ZERO)
