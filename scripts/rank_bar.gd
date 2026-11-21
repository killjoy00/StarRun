extends Control
## Hangar progress: one bar instead of a row of pips, so 15-rank trees stay
## readable on a phone. Original ranks fill cyan; extended ranks (past the
## old cap, `tier_from`) fill amber after a small notch. Short trees get a
## tick per rank; long trees a tick every five. The next rank is outlined
## when the player can afford it.

const TRACK := Color("213447")
const BASE := Color("43e8d8")
const EXTENDED := Color("ffb347")
const TICK := Color(0.04, 0.07, 0.1, 0.85)

var filled := 0
var total := 1
var tier_from := 0
var next_available := false

func setup(bought: int, top_rank: int, extended_from: int, affordable: bool) -> void:
	filled = bought
	total = maxi(1, top_rank)
	tier_from = extended_from if extended_from > 0 and extended_from < top_rank else 0
	next_available = affordable
	custom_minimum_size = Vector2(0, 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _rank_x(rank: int) -> float:
	return size.x * float(rank) / float(total)

func _draw() -> void:
	var height := size.y
	var radius := height * 0.5
	draw_style_box(_box(TRACK, radius), Rect2(Vector2.ZERO, size))
	if filled > 0:
		var base_end := mini(filled, tier_from) if tier_from > 0 else filled
		if base_end > 0:
			draw_style_box(_box(BASE, radius), Rect2(0, 0, _rank_x(base_end), height))
		if tier_from > 0 and filled > tier_from:
			var start := _rank_x(tier_from)
			draw_style_box(_box(EXTENDED, radius), Rect2(start, 0, _rank_x(filled) - start, height))
	# Rank ticks: every rank on short trees, every fifth rank on long ones.
	var step := 1 if total <= 10 else 5
	for rank in range(step, total, step):
		var x := _rank_x(rank)
		draw_line(Vector2(x, 1), Vector2(x, height - 1), TICK, 1.0)
	# Where the extended (pricier) ranks begin.
	if tier_from > 0:
		var notch := _rank_x(tier_from)
		draw_line(Vector2(notch, -2), Vector2(notch, height + 2), EXTENDED, 2.0)
	if next_available and filled < total:
		var rect := Rect2(_rank_x(filled), 0, _rank_x(filled + 1) - _rank_x(filled), height)
		draw_rect(rect.grow(0.5), Color("ffc078"), false, 1.5)

func _box(color: Color, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	return box
