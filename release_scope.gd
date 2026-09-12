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
