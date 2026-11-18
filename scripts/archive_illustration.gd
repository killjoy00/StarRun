extends Control
## The same ring machine appears in the transmission, in combat and in the epilogue.
const Archive = preload("res://scripts/hidden_sector.gd")
var scene := "gate"
var reduced := false
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(not reduced)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("081616"))
	var origin := size * Vector2(0.5, 0.48)
	for i in range(95):
		var point := Vector2(fposmod(i * 71.25, size.x), fposmod(i * 41.77, size.y))
		draw_circle(point, 1.05 if i % 7 == 0 else 0.55, Color(Archive.COLOR, 0.16 + float(i % 5) * 0.09))
	for i in range(11):
		var row := float(i) / 10.0
		var y := lerpf(size.y * 0.52, size.y - 2.0, row * row)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(Archive.MINT, row * 0.18), 1.0)
	for i in range(-6, 7):
		draw_line(origin + Vector2(i * 10.0, 4.0), Vector2(origin.x + i * size.x / 5.0, size.y), Color(Archive.MINT, 0.16), 1.0, true)
	var accent := Archive.MINT if scene in ["arrival", "epilogue"] else Archive.COLOR
	var radius := minf(size.y * 0.38, size.x * 0.29)
	if scene == "arrival":
		radius *= 1.14
		for i in range(26):
			var direction := Vector2.from_angle(i * 2.39996)
			var distance := fposmod(i * 15.13 + elapsed * 94.0, size.x * 0.55)
			var start := origin + direction * distance
			draw_line(start, start + direction * (5.0 + distance * 0.08), Color(accent, clampf(distance / radius - 0.40, 0.0, 0.34)), 1.25, true)
	for i in range(6):
		draw_circle(origin, radius * (1.19 - i * 0.13), Color(accent, 0.038))
	if scene == "boss":
		draw_set_transform(origin, 0.0, Vector2.ONE * radius / 74.0)
		custodian(self, elapsed, false)
		draw_set_transform(Vector2.ZERO)
	else:
		var angle := elapsed * 0.27
		for side in [0, 1, 2]:
			var offset: float = side * TAU / 3.0 + angle
			draw_arc(origin, radius, offset + 0.10, offset + 1.96, 32, Color(accent, 0.28), 12.0, true)
			draw_arc(origin, radius, offset + 0.13, offset + 1.93, 32, accent, 2.0, true)
			draw_circle(origin + Vector2.from_angle(offset) * radius, 4, accent)
		draw_arc(origin, radius * 0.78, -angle, -angle + TAU, 64, Color(accent, 0.48), 1.6, true)
		for side in [-1, 1]:
			var edge := float(side)
			shape(self, PackedVector2Array([Vector2(edge * 60, 0),Vector2(edge * 94,-55),Vector2(edge * 115,-43),Vector2(edge * 103,53),Vector2(edge * 74,37)]), origin, Color("213936"), Color(accent, 0.54))
		var flare := (0.52 + 0.17 * sin(elapsed * 1.4)) if scene == "gate" else 0.85
		draw_line(Vector2(16, origin.y), Vector2(size.x - 16.0, origin.y), Color(accent, 0.22), 1.0, true)
		draw_line(origin - Vector2(0, radius * 0.60), origin + Vector2(0, radius * 0.60), Color(accent, flare), 3.0, true)
		draw_circle(origin, 7 if scene == "gate" else 12, accent)
		draw_circle(origin, 3, Color.WHITE)
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(accent, 0.40), false, 1.0)

static func shape(canvas: CanvasItem, points: PackedVector2Array, origin: Vector2, fill: Color, edge: Color) -> void:
	var path := PackedVector2Array()
	for point in points:
		path.append(point + origin)
	canvas.draw_colored_polygon(path, fill)
	path.append(path[0])
	canvas.draw_polyline(path, edge, 1.6, true)

static func custodian(canvas: CanvasItem, clock: float, open: bool) -> void:
	var accent := Archive.MINT if open else Archive.COLOR
	var spacing := 16.0 if open else 0.0
	for side in [-1, 1]:
		var edge := float(side)
		var offset := Vector2(edge * spacing, 0)
		shape(canvas, PackedVector2Array([Vector2(edge * 18,-57),Vector2(edge * 73,-42),Vector2(edge * 92,9),Vector2(edge * 66,59),Vector2(edge * 28,42),Vector2(edge * 48,3)]), offset, Color("32554e"), accent)
		shape(canvas, PackedVector2Array([Vector2(edge * 55,-29),Vector2(edge * 76,1),Vector2(edge * 56,30),Vector2(edge * 60,2)]), offset, Color("101e22"), Color(accent, 0.68))
		canvas.draw_circle(offset + Vector2(edge * 67, 9), 4.0, accent)
	for i in range(3):
		var a: float = i * TAU / 3.0 + clock * 0.65
		canvas.draw_arc(Vector2.ZERO, 34.0, a, a + 1.75, 22, accent, 3.0, true)
	shape(canvas, PackedVector2Array([Vector2(0,-27),Vector2(22,0),Vector2(0,29),Vector2(-22,0)]), Vector2.ZERO, Color("13242a"), accent)
	canvas.draw_line(Vector2(0,-13), Vector2(0,13), accent, 3, true)
	canvas.draw_circle(Vector2.ZERO, 6 + sin(clock * 3.0) * 1.5, Color.WHITE)
