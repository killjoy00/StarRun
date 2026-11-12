extends Control
## A drawn ship-service bay, sharing the actual ship art with flight.
const SHIP = preload("res://assets/art/vanguard.png")
var clock := 0.0

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var center := Vector2(w * 0.5, h * 0.48)
	var radius := minf(w * 0.39, h * 0.42)
	draw_rect(Rect2(Vector2.ZERO, size), Color("080f19"))
	for x in range(0, int(w), 24):
		draw_line(Vector2(x, 0), Vector2(x, h), Color(0.2, 0.4, 0.45, 0.09))
	for y in range(0, int(h), 24):
		draw_line(Vector2(0, y), Vector2(w, y), Color(0.2, 0.4, 0.45, 0.09))
	draw_circle(center, radius, Color(0.15, 0.4, 0.4, 0.10))
	for ring in [0.72, 0.90, 1.0]:
		draw_arc(center, radius * ring, 0, TAU, 96, Color(0.35, 0.7, 0.65, 0.18), 1.0, true)
	for i in range(16):
		var a := i * TAU / 16
		draw_line(center + Vector2.from_angle(a) * radius * 0.95, center + Vector2.from_angle(a) * radius * 1.04, Color("4b716f"), 1, true)
	for side in [-1, 1]:
		var x: float = center.x + side * radius * 0.88
		draw_line(Vector2(x, center.y - radius * 0.4), Vector2(x, center.y + radius * 0.4), Color("273c4a"), 10, true)
		draw_line(Vector2(x, center.y - radius * 0.35), center + Vector2(side * radius * 0.48, -radius * 0.25), Color("587279"), 3, true)
		draw_circle(center + Vector2(side * radius * 0.48, -radius * 0.25), 3, Color("ffc078"))
	var ship_size := Vector2.ONE * radius * 1.58
	draw_texture_rect(SHIP, Rect2(center - ship_size * 0.5 + Vector2(0, sin(clock) * 2), ship_size), false)
	var scan_y := center.y - radius + fposmod(clock * 22, radius * 2)
	draw_line(Vector2(center.x - radius * 0.68, scan_y), Vector2(center.x + radius * 0.68, scan_y), Color(0.4, 1.0, 0.85, 0.20), 1, true)
	draw_string(ThemeDB.fallback_font, Vector2(14, 22), "VANGUARD / SERVICE BAY 07", HORIZONTAL_ALIGNMENT_LEFT, w - 20, 11, Color("8797ad"))
	draw_string(ThemeDB.fallback_font, Vector2(14, h - 14), "●  FLIGHT SYSTEMS ONLINE", HORIZONTAL_ALIGNMENT_LEFT, w - 20, 11, Color("66f5df"))
