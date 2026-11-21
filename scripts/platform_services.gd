extends RefCounted
## Gameplay never depends on an ad SDK or a store being available.
## Native ads/purchases require the separate hardware spike; this build grants no fake entitlement.
const PROFILE := "user://profile.save"
const RUN := "user://run.save"
const TMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"

## "" after a clean read. Otherwise which fallback a read used ("tmp" or
## "backup"), or "corrupt" when nothing was readable and the damaged file
## was moved aside (to `last_quarantine`) instead of being overwritten.
var last_recovery := ""
var last_quarantine := ""

## Writes are verified before they replace anything, and the previous good
## copy is kept as a backup. On Windows, Godot's rename deletes the target
## before moving the new file in, so a crash between those two steps leaves
## only the .tmp; read_save() recovers from it (and from the backup).
func write_atomic(path: String, value: Dictionary) -> bool:
	var tmp := path + TMP_SUFFIX
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(value)
	var error := file.get_error()
	file.close()
	# A short write (for example a full disk) must never replace a good save.
	if error != OK or not _read_file(tmp) is Dictionary:
		DirAccess.remove_absolute(tmp)
		return false
	# Only a readable save is promoted to the backup slot, so a damaged
	# primary can never overwrite the last good backup.
	if FileAccess.file_exists(path) and _read_file(path) is Dictionary:
		DirAccess.copy_absolute(path, path + BACKUP_SUFFIX)
	return DirAccess.rename_absolute(tmp, path) == OK

func read_save(path: String) -> Dictionary:
	last_recovery = ""
	last_quarantine = ""
	var value: Variant = _read_file(path)
	if value is Dictionary:
		return value
	# The primary is missing or unreadable. A complete .tmp is newer than the
	# backup (it was verified before the interrupted replace), so try it first.
	for fallback in [[TMP_SUFFIX, "tmp"], [BACKUP_SUFFIX, "backup"]]:
		var candidate: Variant = _read_file(path + str(fallback[0]))
		if candidate is Dictionary:
			last_recovery = str(fallback[1])
			return candidate
	if FileAccess.file_exists(path):
		# Nothing usable. Keep the damaged bytes for recovery rather than
		# letting the next save silently replace them with a fresh profile.
		last_quarantine = "%s.corrupt-%d" % [path, int(Time.get_unix_time_from_system())]
		DirAccess.rename_absolute(path, last_quarantine)
		last_recovery = "corrupt"
	return {}

func _read_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 4:
		return null
	# store_var() writes a 32-bit payload length, then the payload. Check it
	# first so truncated or foreign files are rejected without decoding.
	if int(file.get_32()) + 4 != file.get_length():
		return null
	file.seek(0)
	var value: Variant = file.get_var()
	if file.get_error() not in [OK, ERR_FILE_EOF]:
		return null
	return value

func delete_run() -> void:
	# Remove every copy, or a finished flight could be resumed from its backup.
	for suffix in ["", TMP_SUFFIX, BACKUP_SUFFIX]:
		if FileAccess.file_exists(RUN + suffix):
			DirAccess.remove_absolute(RUN + suffix)

func ads_available() -> bool:
	return false

func store_available() -> bool:
	return false
