extends Control
## A drawn ship-service bay, sharing the actual ship art with flight.
const SHIPS = {
	"vanguard": preload("res://assets/art/vanguard.png"),
	"kestrel": preload("res://assets/art/kestrel.svg"),
	"bulwark": preload("res://assets/art/bulwark.svg"),
	"wraith": preload("res://assets/art/wraith.svg"),
	"arcwing": preload("res://assets/art/arcwing.svg"),
	"haven": preload("res://assets/art/haven.svg"),
	"lancer": preload("res://assets/art/lancer.webp")
}
const Catalog = preload("res://scripts/catalog.gd")
var ship_id := "vanguard"
var clock := 0.0
## "bay" is the service dock; "flight" is the title-screen hero with streaking stars.
var style := "bay"
var labels := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var center := Vector2(w * 0.5, h * 0.48)
	var radius := minf(w * 0.39, h * 0.42)
	if style == "flight":
		_draw_flight(w, h)
		return
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
	_draw_ship(center + Vector2(0, sin(clock) * 2), radius)
	var scan_y := center.y - radius + fposmod(clock * 22, radius * 2)
	draw_line(Vector2(center.x - radius * 0.68, scan_y), Vector2(center.x + radius * 0.68, scan_y), Color(0.4, 1.0, 0.85, 0.20), 1, true)
	if labels:
		draw_string(ThemeDB.fallback_font, Vector2(14, 22), Catalog.ship(ship_id).name.to_upper() + " / SERVICE BAY 07", HORIZONTAL_ALIGNMENT_LEFT, w - 20, 11, Color("8797ad"))
		draw_string(ThemeDB.fallback_font, Vector2(14, h - 14), "●  FLIGHT SYSTEMS ONLINE", HORIZONTAL_ALIGNMENT_LEFT, w - 20, 11, Color("66f5df"))

static func tint_for(id: String) -> Color:
	match id:
		"kestrel": return Color("8affdf")
		"bulwark": return Color("b4d3ee")
		"wraith": return Color("ffcf92")
		"arcwing": return Color("cbb8ff")
		"haven": return Color("a8f4d0")
		"lancer": return Color("ffd98a")
	return Color.WHITE

func _draw_flight(w: float, h: float) -> void:
	# Stars stream past a ship holding position: motion without needing gameplay.
	for i in range(70):
		var seed_x := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var depth := 0.35 + fposmod(sin(i * 78.233) * 12345.678, 1.0) * 0.65
		var y := fposmod(fposmod(cos(i * 4.1) * 999.0, 1.0) * h + clock * 140.0 * depth, h + 40.0) - 20.0
		var x := seed_x * w
		var length := 4.0 + depth * 18.0
		draw_line(Vector2(x, y), Vector2(x, y - length), Color(0.62, 0.86, 1.0, 0.12 + depth * 0.35), 1.0 + depth, true)
	var radius := minf(w * 0.36, h * 0.40)
	var center := Vector2(w * 0.5, h * 0.50 + sin(clock * 1.3) * 4.0)
	# Engine plume under the hull.
	for side in [-1, 1]:
		var nozzle := center + Vector2(side * radius * 0.13, radius * 0.52)
		var flicker := 0.85 + 0.15 * sin(clock * 31.0 + side)
		draw_colored_polygon(PackedVector2Array([nozzle + Vector2(-radius * 0.06, 0), nozzle + Vector2(radius * 0.06, 0), nozzle + Vector2(0, radius * 0.75 * flicker)]), Color(0.4, 0.95, 1.0, 0.35))
		draw_colored_polygon(PackedVector2Array([nozzle + Vector2(-radius * 0.03, 0), nozzle + Vector2(radius * 0.03, 0), nozzle + Vector2(0, radius * 0.42 * flicker)]), Color(0.9, 1.0, 1.0, 0.75))
	draw_circle(center, radius * 0.9, Color(0.25, 0.85, 0.8, 0.05))
	_draw_ship(center, radius)

func _draw_ship(center: Vector2, radius: float) -> void:
	var ship_size := Vector2.ONE * radius * 1.8
	draw_texture_rect(SHIPS.get(ship_id, SHIPS.vanguard), Rect2(center - ship_size * 0.5, ship_size), false)
