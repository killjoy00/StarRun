extends SceneTree
# Render the same original Star/Run mark used by iPhone, without binary assets.
func _initialize() -> void:
	var svg := FileAccess.get_file_as_bytes("res://assets/icon.svg")
	if svg.is_empty():
		push_error("Star/Run source icon is missing")
		quit(1)
		return
	var image := Image.new()
	var result := image.load_svg_from_buffer(svg, 2.0)
	if result != OK or image.get_width() != 512 or image.get_height() != 512:
		push_error("Could not render the 512x512 Star/Run Android icon")
		quit(1)
		return
	var output := ProjectSettings.globalize_path("res://assets/android-icon.png")
	if image.save_png(output) != OK:
		push_error("Could not save Android icon to " + output)
		quit(1)
		return
	print("Android icon rendered from assets/icon.svg at 512x512")
	quit(0)
