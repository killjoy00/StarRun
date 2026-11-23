extends Control
## Face portraits share the same compact frame wherever a pilot is shown.
const FACES := {
	"rookie":preload("res://assets/pilots/rookie.webp"),
	"ace":preload("res://assets/pilots/ace.webp"),
	"engineer":preload("res://assets/pilots/engineer.webp"),
	"hunter":preload("res://assets/pilots/hunter.webp"),
	"scavenger":preload("res://assets/pilots/scavenger.webp"),
	"tactician":preload("res://assets/pilots/tactician.webp"),
	"daredevil":preload("res://assets/pilots/daredevil.svg")}
var pilot_id := "rookie"
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var side := minf(size.x,size.y)
	var rect := Rect2(Vector2.ZERO,Vector2.ONE*side)
	draw_texture_rect(FACES.get(pilot_id,FACES.rookie),rect,false)
	draw_rect(rect,Color("385464"),false,1.0)
