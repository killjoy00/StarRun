extends RefCounted
## Gameplay never depends on an ad SDK or a store being available.
## Native ads/purchases require the separate hardware spike; this build grants no fake entitlement.
const PROFILE := "user://profile.save"
const RUN := "user://run.save"

func write_atomic(path: String, value: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(value)
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = file.get_var()
	return value if value is Dictionary else {}

func delete_run() -> void:
	if FileAccess.file_exists(RUN):
		DirAccess.remove_absolute(RUN)

func ads_available() -> bool:
	return false

func store_available() -> bool:
	return false
