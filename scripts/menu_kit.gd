extends RefCounted
## Shared look for every screen outside combat: one type scale, one set of
## surfaces and one button vocabulary, so menus read as the same flight deck.

const CYAN := Color("66f5df")
const AMBER := Color("ffc078")
const VIOLET := Color("c9a8ff")
const DANGER := Color("ff8a78")
const INK := Color("061019")
const TEXT := Color("e8f0f6")
const MUTED := Color("93a3b8")
const DIM := Color("5d6e82")
const SURFACE := Color("0e1a2a")
const SURFACE_HI := Color("142438")
const LINE := Color("22364a")

static var _fonts := {}
static var _core: ImageTexture

## Open Sans with optional tracking and weight, for wordmarks and caps labels.
static func font(tracking: int = 0, embolden: float = 0.0) -> Font:
	var key := "%d:%.2f" % [tracking, embolden]
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = ThemeDB.fallback_font
		variation.spacing_glyph = tracking
		variation.variation_embolden = embolden
		_fonts[key] = variation
	return _fonts[key]

static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 10, width: int = 1, pad_x: float = 14.0, pad_y: float = 12.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	style.anti_aliasing = true
	return style

## Amber salvage core, drawn once so it never depends on a font glyph.
static func core_texture() -> Texture2D:
	if _core != null:
		return _core
	var n := 48
	var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in range(n):
		for x in range(n):
			var d := absf(x - c) / (n * 0.38) + absf(y - c) / (n * 0.48)
			if d <= 1.0:
				var edge := clampf((1.0 - d) * 10.0, 0.0, 1.0)
				var tint := AMBER.lerp(Color("fff1d6"), 0.75) if d < 0.42 else AMBER
				image.set_pixel(x, y, Color(tint, edge))
	_core = ImageTexture.create_from_image(image)
	return _core

static func core_icon(px: float = 16.0) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = core_texture()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(px, px)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

static func label(parent: Node, text_value: String, font_size: int, color: Color = TEXT, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.custom_minimum_size.x = 0
	parent.add_child(node)
	return node

## Small tracked capitals: section names, tags and eyebrows above titles.
static func caps(parent: Node, text_value: String, color: Color = MUTED, font_size: int = 14) -> Label:
	var node := label(parent, text_value.to_upper(), font_size, color)
	node.add_theme_font_override("font", font(2, 0.25))
	return node

## Button kinds: primary (one per screen), secondary, ghost, danger, amber.
static func style_button(button: Button, kind: String = "secondary", font_size: int = 17, radius: int = 10, pad_x: float = 14.0) -> void:
	var fills := {
		"primary": [CYAN, CYAN, Color("9bfff0"), Color("44c7b2"), INK],
		"secondary": [SURFACE_HI, Color("2b4459"), Color("1b3046"), Color("10202f"), TEXT],
		"ghost": [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.08), CYAN],
		"danger": [Color("3a1717"), DANGER, Color("4a1d1d"), Color("2b1010"), Color("ffd4cc")],
		"amber": [Color("2b2112"), AMBER, Color("3a2c15"), Color("1f170c"), AMBER],
		"selected": [Color("173a40"), CYAN, Color("1c4850"), Color("123036"), Color.WHITE],
	}
	var spec: Array = fills.get(kind, fills.secondary)
	button.add_theme_stylebox_override("normal", box(spec[0], spec[1], radius, 1, pad_x, 8))
	button.add_theme_stylebox_override("hover", box(spec[2], spec[1] if kind != "secondary" else CYAN, radius, 1, pad_x, 8))
	button.add_theme_stylebox_override("pressed", box(spec[3], spec[1], radius, 1, pad_x, 8))
	button.add_theme_stylebox_override("disabled", box(Color("0b1420") if kind != "ghost" else Color(0, 0, 0, 0), Color("1a2a3a") if kind != "ghost" else Color(0, 0, 0, 0), radius, 1, pad_x, 8))
	var focus := box(Color(0, 0, 0, 0), AMBER, radius, 2, pad_x, 8)
	button.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, spec[4])
	button.add_theme_color_override("font_disabled_color", DIM)
	button.add_theme_font_size_override("font_size", font_size)
	if kind == "primary":
		button.add_theme_font_override("font", font(1, 0.45))

static func meter(parent: Node, value: float, tint: Color = CYAN, height: float = 6.0) -> Control:
	var bar := Meter.new()
	bar.value = value
	bar.tint = tint
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(bar)
	return bar

static func glyph(parent: Node, kind: String, tint: Color = TEXT, px: float = 22.0) -> Control:
	var icon := Glyph.new()
	icon.kind = kind
	icon.tint = tint
	icon.custom_minimum_size = Vector2(px, px)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(icon)
	return icon

class Meter extends Control:
	var value := 0.5
	var tint := Color("66f5df")
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := size.y * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), Color("1a2a3b"))
		draw_rect(Rect2(Vector2.ZERO, Vector2(maxf(r, size.x * clampf(value, 0.0, 1.0)), size.y)), tint)

## Vector glyphs for chrome (back, settings, close, lock, check, play).
class Glyph extends Control:
	var kind := "back"
	var tint := Color.WHITE
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var s := minf(size.x, size.y) / 24.0
		draw_set_transform(size * 0.5, 0.0, Vector2.ONE * s)
		match kind:
			"back":
				draw_polyline(PackedVector2Array([Vector2(4, -8), Vector2(-4, 0), Vector2(4, 8)]), tint, 2.6, true)
			"next":
				draw_polyline(PackedVector2Array([Vector2(-3, -7), Vector2(4, 0), Vector2(-3, 7)]), tint, 2.4, true)
			"close":
				draw_line(Vector2(-7, -7), Vector2(7, 7), tint, 2.4, true)
				draw_line(Vector2(7, -7), Vector2(-7, 7), tint, 2.4, true)
			"settings":
				for i in range(3):
					var y := -7.0 + i * 7.0
					draw_line(Vector2(-9, y), Vector2(9, y), tint, 2.0, true)
					var knob: float = [-4.0, 4.0, -1.0][i]
					draw_circle(Vector2(knob, y), 3.0, Color("0b1624"))
					draw_arc(Vector2(knob, y), 3.0, 0, TAU, 16, tint, 2.0, true)
			"lock":
				draw_arc(Vector2(0, -3), 5.0, PI, TAU, 16, tint, 2.2, true)
				draw_line(Vector2(-5, -3), Vector2(-5, 0), tint, 2.2)
				draw_line(Vector2(5, -3), Vector2(5, 0), tint, 2.2)
				draw_rect(Rect2(-7, 0, 14, 10), tint)
			"check":
				draw_polyline(PackedVector2Array([Vector2(-7, 0), Vector2(-2, 5), Vector2(8, -6)]), tint, 2.8, true)
			"play":
				draw_colored_polygon(PackedVector2Array([Vector2(-5, -8), Vector2(8, 0), Vector2(-5, 8)]), tint)
			"plus":
				draw_line(Vector2(-6, 0), Vector2(6, 0), tint, 2.6, true)
				draw_line(Vector2(0, -6), Vector2(0, 6), tint, 2.6, true)
			"minus":
				draw_line(Vector2(-6, 0), Vector2(6, 0), tint, 2.6, true)
		draw_set_transform(Vector2.ZERO)
