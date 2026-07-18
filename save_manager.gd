extends Node

# SaveManager
# Autoload singleton. Persists player progress across sessions.
# Saved to: user://soundup_save.json

const SAVE_PATH := "user://soundup_save.json"

var _data : Dictionary = {
	"prep_completed"      : false,
	"prep_set_index"      : 0,
	"level1_completed"    : false,
	"level1_set_index"    : 0,
	"level1_cubes_earned" : 0,
	"level15_completed"   : false,
	"level15_set_index"   : 0,
	"level15_cubes_earned": 0,
	"level2_completed"    : false,
	"level2_set_index"    : 0,
	"level2_cubes_earned" : 0,
	"path_chosen"         : false,
	"chose_level1_path"   : false,
	"review_counts"       : {},
}

func _ready() -> void:
	load_game()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

# --- Public API ---

func is_prep_completed() -> bool:
	return _data.get("prep_completed", false)

func set_prep_completed() -> void:
	_data["prep_completed"] = true
	save_game()

func get_prep_set_index() -> int:
	return _data.get("prep_set_index", 0)

func set_prep_set_index(idx: int) -> void:
	_data["prep_set_index"] = idx
	save_game()

func get_level1_set_index() -> int:
	return _data.get("level1_set_index", 0)

func set_level1_set_index(idx: int) -> void:
	_data["level1_set_index"] = idx
	save_game()

func is_level1_completed() -> bool:
	return _data.get("level1_completed", false)

func set_level1_completed() -> void:
	_data["level1_completed"] = true
	save_game()

func is_level15_completed() -> bool:
	return _data.get("level15_completed", false)

func set_level15_completed() -> void:
	_data["level15_completed"] = true
	save_game()

func get_level15_set_index() -> int:
	return _data.get("level15_set_index", 0)

func set_level15_set_index(idx: int) -> void:
	_data["level15_set_index"] = idx
	save_game()

func is_level2_completed() -> bool:
	return _data.get("level2_completed", false)

func set_level2_completed() -> void:
	_data["level2_completed"] = true
	save_game()

func get_level2_set_index() -> int:
	return _data.get("level2_set_index", 0)

func set_level2_set_index(idx: int) -> void:
	_data["level2_set_index"] = idx
	save_game()

func get_level1_cubes_earned() -> int:
	return _data.get("level1_cubes_earned", 0)

func set_level1_cubes_earned(n: int) -> void:
	_data["level1_cubes_earned"] = n
	save_game()

func get_level15_cubes_earned() -> int:
	return _data.get("level15_cubes_earned", 0)

func set_level15_cubes_earned(n: int) -> void:
	_data["level15_cubes_earned"] = n
	save_game()

func get_level2_cubes_earned() -> int:
	return _data.get("level2_cubes_earned", 0)

func set_level2_cubes_earned(n: int) -> void:
	_data["level2_cubes_earned"] = n
	save_game()

func get_review_count(key: String) -> int:
	var counts : Dictionary = _data.get("review_counts", {})
	return counts.get(key, 0)

func increment_review_count(key: String) -> void:
	if not _data.has("review_counts"):
		_data["review_counts"] = {}
	_data["review_counts"][key] = _data["review_counts"].get(key, 0) + 1
	save_game()

func is_path_chosen() -> bool:
	return _data.get("path_chosen", false)

func set_path_chosen() -> void:
	_data["path_chosen"] = true
	save_game()

func is_chose_level1_path() -> bool:
	return _data.get("chose_level1_path", false)

func set_chose_level1_path() -> void:
	_data["chose_level1_path"] = true
	save_game()

# --- File I/O ---

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open save file for writing.")
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: could not open save file for reading.")
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		for key in parsed:
			_data[key] = parsed[key]
