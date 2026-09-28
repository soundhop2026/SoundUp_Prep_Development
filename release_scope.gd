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
# Must exactly match the real Coronation hand-off chain — the
# LevelTransition.next_level_id values set by prep_transition.gd/
# transition.gd — in curriculum order.
const PROGRESSION_ORDER : Array[String] = ["prep", "level1", "level15", "level2", "level25"]

# The last entry in PROGRESSION_ORDER that is publicly released in this build.
const HIGHEST_RELEASED_LEVEL_ID : String = "level1"

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
	var released_idx : int = PROGRESSION_ORDER.find(HIGHEST_RELEASED_LEVEL_ID)
	var target_idx   : int = PROGRESSION_ORDER.find(level_id)
	if released_idx == -1 or target_idx == -1:
		return false
	return target_idx <= released_idx
