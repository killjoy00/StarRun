extends RefCounted
## Shared vector insignia. Drawn in the caller's transform, on a 36-point canvas.
const PALETTES := {
	"nova_aegis":[Color("7cece7"),Color("f1d69b")],
	"shieldstorm":[Color("87caff"),Color("f2da9c")],
	"railstorm":[Color("f2c078"),Color("c5e9ff")],
	"stasis_lock":[Color("bca4f2"),Color("89dfef")],
	"repair_matrix":[Color("87deb7"),Color("c5efff")],
	"missile_grid":[Color("eac080"),Color("bdacf2")],
	"scrap_converter":[Color("cfb17d"),Color("86ddbc")],
	"prism_focus":[Color("b3aff2"),Color("a6e6f2")],
	"reflective_wall":[Color("a0d7ed"),Color("ddc9fa")],
	"ghost_signal":[Color("a7a2df"),Color("88d3df")],
	"reactor_surge":[Color("8be3d8"),Color("f2d38e")],
	"storm_carrier":[Color("83e6d4"),Color("c3a8f3")]
}

static func polygon(center: Vector2, radius: float, sides: int = 6, rotation: float = -PI / 2.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides): points.append(center + Vector2.from_angle(rotation + i * TAU / sides) * radius)
	return points

static func outline(item: CanvasItem, points: PackedVector2Array, color: Color, width: float = 1.4) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	item.draw_polyline(closed, color, width, true)

static func badge(item: CanvasItem, id: String, alpha: float = 1.0) -> void:
	var colors: Array = PALETTES[id]
	var a := Color(colors[0], alpha)
	var b := Color(colors[1], alpha)
	var white := Color("edf5ff", alpha)
	var rim := polygon(Vector2.ZERO, 17)
	item.draw_colored_polygon(rim, Color("0b1725", alpha))
	outline(item, rim, Color(a, alpha * 0.8), 1.1)
	# Two inset corner seams identify the whole family without replacing its symbol.
	for side in [-1,1]:
		item.draw_line(Vector2(side * 13, -9), Vector2(side * 15, -5), b, 1.6, true)
		item.draw_line(Vector2(side * 13, 9), Vector2(side * 15, 5), Color(a, alpha * 0.5), 1.0, true)
	match id:
		"storm_carrier":
			for side in [-1,1]:
				var p := Vector2(side*9,-2)
				item.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-7),p+Vector2(4,5),p,p+Vector2(-4,5)]),a)
				item.draw_line(p+Vector2(0,6),p+Vector2(0,10),white,1.3,true)
			outline(item,polygon(Vector2(0,5),5,4),b,1.7)
			item.draw_circle(Vector2(0,5),2,white)
			item.draw_arc(Vector2.ZERO,12,PI*1.15,PI*1.85,16,b,1.5,true)
		"shieldstorm":
			# Shield + outward-moving flak dots, legible even at 36px.
			var plate := PackedVector2Array([Vector2(0,-12),Vector2(11,-7),Vector2(10,4),Vector2(0,12),Vector2(-10,4),Vector2(-11,-7)])
			item.draw_colored_polygon(plate,Color(a,alpha*0.16))
			outline(item,plate,a,1.8)
			item.draw_line(Vector2(0,-9),Vector2(0,8),white,1.1,true)
			for offset in [Vector2(-14,-9),Vector2(14,-9),Vector2(-14,7),Vector2(14,7)]:
				item.draw_circle(offset,1.8,b)
			item.draw_arc(Vector2.ZERO,8,PI*0.15,PI*0.85,12,b,1.5,true)
		"nova_aegis":
			var shield := PackedVector2Array([Vector2(-10,-8),Vector2(0,-12),Vector2(10,-8),Vector2(8,5),Vector2(0,12),Vector2(-8,5)])
			item.draw_colored_polygon(shield, Color(a, alpha * 0.13))
			outline(item, shield, a, 1.8)
			item.draw_colored_polygon(PackedVector2Array([Vector2(0,-8),Vector2(2,-2),Vector2(7,0),Vector2(2,2),Vector2(0,8),Vector2(-2,2),Vector2(-7,0),Vector2(-2,-2)]), b)
			item.draw_circle(Vector2.ZERO, 2, white)
		"railstorm":
			for lane in [-1,0,1]:
				var x: float = lane * 7
				var top := -12.0 if lane == 0 else -7.0
				item.draw_line(Vector2(x,10),Vector2(x,top),a,3,true)
				item.draw_line(Vector2(x+1,7),Vector2(x+1,top+2),white,0.9,true)
				item.draw_colored_polygon(PackedVector2Array([Vector2(x-3,top+2),Vector2(x,top-3),Vector2(x+3,top+2)]),b)
			item.draw_line(Vector2(-9,11),Vector2(9,11),b,1.3,true)
		"stasis_lock":
			item.draw_arc(Vector2.ZERO,11,-PI*0.4,PI*1.4,32,a,2,true)
			for i in range(8):
				var v := Vector2.from_angle(i*TAU/8)
				item.draw_line(v*9,v*11,b,1.5,true)
			item.draw_polyline(PackedVector2Array([Vector2(0,-7),Vector2(0,0),Vector2(5,3)]),white,2,true)
			item.draw_circle(Vector2.ZERO,2,b)
			item.draw_line(Vector2(-4,12),Vector2(4,12),a,2,true)
		"repair_matrix":
			for x in [-1,1]:
				for y in [-1,1]:
					var p := Vector2(x*9,y*9)
					item.draw_colored_polygon(polygon(p,3,4),b)
					item.draw_line(p,p*0.6,Color(a,alpha*0.6),1.1,true)
			item.draw_rect(Rect2(-3,-9,6,18),a)
			item.draw_rect(Rect2(-9,-3,18,6),a)
			item.draw_rect(Rect2(-1.3,-5,2.6,10),white)
			item.draw_rect(Rect2(-5,-1.3,10,2.6),white)
		"missile_grid":
			for x in [-1,1]:
				for y in [-1,1]:
					var p := Vector2(x*5,y*6)
					item.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-5),p+Vector2(3,0),p+Vector2(2,3),p+Vector2(-2,3),p+Vector2(-3,0)]),a)
					item.draw_line(p+Vector2(0,3),p+Vector2(0,5),b,1.5,true)
			item.draw_line(Vector2(-11,-10),Vector2(-11,10),Color(b,alpha*0.6),1.2,true)
			item.draw_line(Vector2(11,-10),Vector2(11,10),Color(b,alpha*0.6),1.2,true)
		"scrap_converter":
			for i in range(3):
				var angle: float = i*TAU/3
				item.draw_arc(Vector2.ZERO,10,angle,angle+1.3,14,a,2.5,true)
				var p := Vector2.from_angle(angle+1.3)*10
				var v := Vector2.from_angle(angle+1.3)
				item.draw_colored_polygon(PackedVector2Array([p+v*3,p-v*3,p+v.orthogonal()*5]),b)
			item.draw_colored_polygon(polygon(Vector2.ZERO,4,4),white)
		"prism_focus":
			var crystal := PackedVector2Array([Vector2(0,-13),Vector2(8,-2),Vector2(0,12),Vector2(-8,-2)])
			item.draw_colored_polygon(crystal,Color(a,alpha*0.28))
			outline(item,crystal,b,1.6)
			item.draw_line(Vector2(0,-13),Vector2(0,12),white,1.5,true)
			item.draw_line(Vector2(-8,-2),Vector2(8,-2),a,1.5,true)
			for side in [-1,1]: item.draw_line(Vector2(side*9,0),Vector2(side*13,4),b,1.5,true)
		"reflective_wall":
			for side in [-1,0,1]:
				var tile := polygon(Vector2(side*7,abs(side)*4),6)
				item.draw_colored_polygon(tile,Color(a,alpha*(0.3 if side==0 else 0.15)))
				outline(item,tile,white if side==0 else a,1.4)
			item.draw_polyline(PackedVector2Array([Vector2(-10,-8),Vector2(-5,-4),Vector2(-9,-2)]),b,1.6,true)
			item.draw_polyline(PackedVector2Array([Vector2(10,-8),Vector2(5,-4),Vector2(9,-2)]),b,1.6,true)
		"ghost_signal":
			var ship := PackedVector2Array([Vector2(0,-9),Vector2(5,3),Vector2(10,8),Vector2(2,6),Vector2(0,11),Vector2(-2,6),Vector2(-10,8),Vector2(-5,3)])
			item.draw_colored_polygon(ship,Color(a,alpha*0.28))
			outline(item,ship,white,1.3)
			for side in [-1,1]:
				item.draw_arc(Vector2.ZERO,12,(-0.6 if side==1 else PI-0.6), (0.1 if side==1 else PI+0.1),10,b,1.8,true)
				item.draw_line(Vector2(side*9,-10),Vector2(side*12,-6),Color(a,alpha*0.5),1.0,true)
		"reactor_surge":
			for i in range(3):
				var angle: float = i*TAU/3
				item.draw_arc(Vector2.ZERO,11,angle,angle+1.3,14,a,2.2,true)
				item.draw_line(Vector2.from_angle(angle)*8,Vector2.from_angle(angle)*4,b,1.3,true)
			item.draw_colored_polygon(polygon(Vector2.ZERO,5),b)
			item.draw_colored_polygon(PackedVector2Array([Vector2(1,-7),Vector2(-4,1),Vector2(0,1),Vector2(-1,7),Vector2(4,-1),Vector2(0,-1)]),white)
