extends Node

# SaveManager
# Autoload singleton. Persists player progress across sessions.
# Saved to: user://soundup_save.json

const SAVE_PATH := "user://soundup_save.json"

var _data : Dictionary = _default_data()

static func _default_data() -> Dictionary:
	return {
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
		"levels_entered"      : {},
		"path_chosen"         : false,
		"chose_level1_path"   : false,
		"review_counts"       : {},
		"subscribed"          : false,
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

# ─── Entered-level state (generic, one entry per level id) ──────────────────
# Locked rule: normal progression creates first entry into a level; Where Am I
# never does. Title shows a level's Intro until that level is marked entered,
# and gnb_where_am_i.gd's lock cascade reads the same flag — one source of
# truth, so the two can't drift (they did: the lock cascade used to unlock on
# "previous level completed", which the release-scope gate turned into a real
# bypass for players who finished a level in an earlier build).
# Written only by level_intro.gd's Ready button — i.e. at actual gameplay
# entry, never on Intro display, so abandoning the Intro leaves it unset.
func has_entered_level(level_id: String) -> bool:
	var entered : Dictionary = _data.get("levels_entered", {})
	return entered.get(level_id, false)

func mark_level_entered(level_id: String) -> void:
	if not _data.has("levels_entered"):
		_data["levels_entered"] = {}
	if _data["levels_entered"].get(level_id, false):
		return
	_data["levels_entered"][level_id] = true
	save_game()

# Saves written before levels_entered existed (1.0.1 and earlier) carry no
# entry flags, which would re-lock levels the player already had access to and
# re-show Intros they already passed. Infer entry from the evidence those saves
# do carry, once, on load. A level with progress or completion was necessarily
# entered; Prep's own long-standing path_chosen flag means the same thing for
# Prep. Residual gap, accepted: a player sitting on set 1 of a level with no
# other evidence infers as not-entered and sees that Intro once.
func _infer_entered_levels() -> void:
	if not _data.has("levels_entered"):
		_data["levels_entered"] = {}
	var evidence : Dictionary = {
		"prep":    _data.get("path_chosen", false)      or _data.get("prep_completed", false)    or _data.get("prep_set_index", 0) > 0,
		"level1":  _data.get("chose_level1_path", false) or _data.get("level1_completed", false)  or _data.get("level1_set_index", 0) > 0,
		"level15": _data.get("level15_completed", false) or _data.get("level15_set_index", 0) > 0,
		"level2":  _data.get("level2_completed", false)  or _data.get("level2_set_index", 0) > 0,
	}
	var changed : bool = false
	for lid : String in evidence:
		if evidence[lid] and not _data["levels_entered"].get(lid, false):
			_data["levels_entered"][lid] = true
			changed = true
	if changed:
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

func is_subscribed() -> bool:
	return _data.get("subscribed", false)

func set_subscribed(value: bool) -> void:
	_data["subscribed"] = value
	save_game()

# --- Debug utilities (QA only — see debug_config.gd) ---

func reset_progress() -> void:
	var keep_path_chosen       : bool       = _data.get("path_chosen", false)
	var keep_chose_level1_path : bool       = _data.get("chose_level1_path", false)
	var keep_review_counts     : Dictionary = _data.get("review_counts", {})
	var keep_subscribed        : bool       = _data.get("subscribed", false)
	_data                       = _default_data()
	_data["path_chosen"]       = keep_path_chosen
	_data["chose_level1_path"] = keep_chose_level1_path
	_data["review_counts"]     = keep_review_counts
	_data["subscribed"]        = keep_subscribed
	# levels_entered is cleared with the rest of progress; re-derive it from the
	# flags that were deliberately kept, so the result is identical whether or
	# not the app is relaunched afterwards.
	_infer_entered_levels()
	save_game()

func unlock_all_levels() -> void:
	_data["prep_completed"]    = true
	_data["level1_completed"]  = true
	_data["level15_completed"] = true
	_data["level2_completed"]  = true
	# Completion alone never grants entry (locked rule) — but a QA "unlock all"
	# is meant to open everything, so mark the levels entered explicitly too.
	for lid : String in ["prep", "level1", "level15", "level2", "level25"]:
		_data["levels_entered"][lid] = true
	save_game()

func clear_all_data() -> void:
	_data = _default_data()
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
	_infer_entered_levels()
