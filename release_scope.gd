class_name ReleaseScope

# ─── SoundHop framework rule: release-scope gate ───────────────────────────
# After any Level's Coronation, auto-advance continues into the next Level
# ONLY if that next Level is within this build's public release scope —
# otherwise the player returns to Title instead of entering unreleased
# content. Generic across the whole progression chain, not a special case
# for any one Level: as each new Level is prepared for public release, bump
# HIGHEST_RELEASED_LEVEL_ID to it and every Level after it in
# PROGRESSION_ORDER stays gated automatically. No other code changes
# needed anywhere in the framework when advancing this.
#
# This array IS the Coronation hand-off chain: the Level that follows a
# completed Level is simply the next entry (next_level_id()). No Level-to-Level
# route is hardcoded anywhere — prep_transition.gd and transition.gd both call
# begin_coronation(), and level_transition.gd routes through
# coronation_exit_scene().
const PROGRESSION_ORDER : Array[String] = ["prep", "level1", "level15", "level2", "level25"]

# The last entry in PROGRESSION_ORDER that is publicly released in this build.
const HIGHEST_RELEASED_LEVEL_ID : String = "level1"

# Runtime copy of the boundary. Always starts at the constant above; tests assign
# it to simulate a later release (e.g. "level15") without editing the constant.
# Production code never writes it.
static var released_boundary_id : String = HIGHEST_RELEASED_LEVEL_ID

# Display name shown by the Coronation for the Level it leads into.
const LEVEL_NAMES : Dictionary = {
	"prep":    "Prep Level",
	"level1":  "Level 1",
	"level15": "Level 1.5",
	"level2":  "Level 2",
	"level25": "Level 2.5",
}

# The Level that follows level_id in PROGRESSION_ORDER, or "" after the last one.
static func next_level_id(level_id: String) -> String:
	var i : int = PROGRESSION_ORDER.find(level_id)
	if i == -1 or i + 1 >= PROGRESSION_ORDER.size():
		return ""
	return PROGRESSION_ORDER[i + 1]

static func level_name(level_id: String) -> String:
	return String(LEVEL_NAMES.get(level_id, ""))

# The Level's first full completion: records the Level's own completed flag (the
# guard that keeps the Coronation from ever repeating), rewinds its runtime
# position, and tells the Coronation where it leads. It deliberately does NOT mark
# the next Level entered — only the Level Intro's Ready button does that.
static func begin_coronation(level_id: String) -> void:
	match level_id:
		"prep":
			SaveManager.set_prep_completed()
			PrepLevelProgress.reset()
		"level1":
			SaveManager.set_level1_completed()
			LevelProgress.reset()
		"level15":
			SaveManager.set_level15_completed()
			Level15Progress.reset()
		"level2":
			SaveManager.set_level2_completed()
			Level2Progress.reset()
	var next_id : String = next_level_id(level_id)
	LevelTransition.next_level_id = next_id
	LevelTransition.level_name    = level_name(next_id)

# Where the Coronation goes when it ends: the next Level's Intro if that Level is
# released AND has a scene to enter in this build, otherwise Title. Completion is
# already recorded, so a later release unlocks the Level through Title's normal
# forward routing with no Coronation replay.
static func coronation_exit_scene(next_id: String) -> String:
	if next_id != "" and is_level_released(next_id) and is_level_enterable(next_id):
		return "res://level_intro.tscn"
	return "res://title.tscn"

# ─── Minimal level registry ────────────────────────────────────────────────
# The scene each level id actually enters, and how to restore its saved set
# index. Kept here rather than in a separate file because PROGRESSION_ORDER
# above already makes this script the one place that knows the level sequence
# — title.gd and level_intro.gd used to carry parallel hardcoded `match`
# statements, which is how level25 ended up in PROGRESSION_ORDER with no arm
# in either of them (a released level25 would have fallen through title.gd's
# match and frozen the Title after its exit animation).
# An empty scene path means "in the sequence, but not enterable in this build"
# — is_level_enterable() makes that a first-class state instead of a crash.
const LEVEL_SCENES : Dictionary = {
	"prep":    "res://prep_game.tscn",
	"level1":  "res://game.tscn",
	"level15": "res://game15.tscn",
	"level2":  "res://game2.tscn",   # game25.tscn for its own later sets — see scene_for()
	"level25": "",                   # no scene yet
}

static func is_level_enterable(level_id: String) -> bool:
	return String(LEVEL_SCENES.get(level_id, "")) != ""

# Level 2 splits across two scenes by set index, exactly as transition.gd's
# own routing already does (game25.tscn from set 9 on). Resolving it here
# means Title resumes Level 2 in the right scene; before this it always
# entered game2.tscn, which was wrong for a save parked in sets I-L.
static func scene_for(level_id: String) -> String:
	if level_id == "level2" and Level2Progress.is_option1():
		return "res://game25.tscn"
	return String(LEVEL_SCENES.get(level_id, ""))

# Every Set of a level as its progress-record key, "<level_id>_<label>" — the
# same shape as the review_counts keys. A level with no Sets yet returns [].
static func set_keys(level_id: String) -> Array[String]:
	var labels : Array[String] = []
	match level_id:
		"prep":    labels = PrepLevelProgress.set_labels
		"level1":  labels = LevelProgress.set_labels
		"level15": labels = Level15Progress.set_labels
		"level2":  labels = Level2Progress.set_labels
	var keys : Array[String] = []
	for label : String in labels:
		keys.append(level_id + "_" + label)
	return keys

# The progress-record key of one Set, or "" if the index is out of range.
static func set_key(level_id: String, index: int) -> String:
	var keys : Array[String] = set_keys(level_id)
	return keys[index] if index >= 0 and index < keys.size() else ""

# Saves the resume cursor: the Set the player last actually played (or, after a
# pass, the Set that follows). It is a resume pointer only — never evidence of
# entry or completion.
static func record_cursor(level_id: String, index: int) -> void:
	match level_id:
		"prep":    SaveManager.set_prep_set_index(index)
		"level1":  SaveManager.set_level1_set_index(index)
		"level15": SaveManager.set_level15_set_index(index)
		"level2":  SaveManager.set_level2_set_index(index)

static func is_level_completed(level_id: String) -> bool:
	match level_id:
		"prep":    return SaveManager.is_prep_completed()
		"level1":  return SaveManager.is_level1_completed()
		"level15": return SaveManager.is_level15_completed()
		"level2":  return SaveManager.is_level2_completed()
	return false

# Loads the level's own saved set index into its progress singleton. Used by
# both entry paths (Title resume and the Intro's Ready button) so neither can
# silently drop the player back to set 1 — level_intro.gd used to hardcode
# current_index = 0 for every level but Prep.
static func restore_index(level_id: String) -> void:
	match level_id:
		"prep":
			PrepLevelProgress.load_from_save()
			PrepLevelProgress.current_index = _safe_index(PrepLevelProgress.current_index, PrepLevelProgress.sets.size())
		"level1":  LevelProgress.current_index   = _safe_index(SaveManager.get_level1_set_index(),   LevelProgress.sets.size())
		"level15": Level15Progress.current_index = _safe_index(SaveManager.get_level15_set_index(), Level15Progress.sets.size())
		"level2":  Level2Progress.current_index  = _safe_index(SaveManager.get_level2_set_index(),  Level2Progress.sets.size())

# A saved index outside the level's own set list means the save predates a
# reset() that now rewinds it, or is otherwise stale — treat it as "start this
# level from the beginning" rather than indexing past the end of sets[], which
# would hard-crash the game scene's own _load_rounds().
static func _safe_index(idx: int, set_count: int) -> int:
	return idx if idx >= 0 and idx < set_count else 0


# True if level_id is within this build's public release scope — i.e. safe
# for Coronation to auto-advance into, or for Where Am I to ever unlock
# regardless of progression state. An unrecognized id fails closed (false),
# never auto-advanced into or unlocked.
static func is_level_released(level_id: String) -> bool:
	var released_idx : int = PROGRESSION_ORDER.find(released_boundary_id)
	var target_idx   : int = PROGRESSION_ORDER.find(level_id)
	if released_idx == -1 or target_idx == -1:
		return false
	return target_idx <= released_idx
