class_name Level1SoundQuestState

# Handoff state for Level 1 Sound Quest, same pattern as SoundQuestState (Prep's
# equivalent) — set right before change_scene_to_file("res://level1_sound_quest.tscn"),
# read once by level1_sound_quest.gd's _ready().
#
# group_start_index / group_end_index are inclusive indices into
# LevelProgress.sets (and set_labels) spanning the Group that just finished —
# e.g. Group A = 0..1. Set via LevelProgress.current_group_range().
#
# Quest progression (1 -> 4) is NOT part of this handoff — it stays internal
# to level1_sound_quest.gd's own state, same as sound_quest.gd's _quest_index,
# since all 4 Quests play out within one scene instance.
static var group_start_index : int = 0
static var group_end_index   : int = 0

# QA-only: when true, level1_sound_quest.gd's _ready() skips straight to the
# Quest Transition celebration instead of playing through the Rounds phase —
# same one-shot handoff pattern as SoundQuestState.debug_skip_to_transition.
static var debug_skip_to_transition : bool = false


# ─── Per-Group Quest counts ─────────────────────────────────────────────────
# Groups A/B/C/E fit comfortably under the ~56-word chunk target, so they
# stay at the standard 4 Quests replaying their one whole (padded) pool.
# D, F, and G don't — their real word banks are much bigger (contrast
# pairs, all-sounds-mixed, and ending-sounds all span far more phonemes
# than a single-phoneme-family Group does), so their pools get split into
# multiple ~56-word chunks (see SoundQuestState.split_pool_by_phoneme_balanced),
# and their Quest counts scale accordingly:
#   D: 2 chunks, each replayed 4x  -> 8 Quests
#   F: 3 chunks, each shown once   -> 3 Quests (kids already drilled these
#      phonemes individually elsewhere; this is one consolidating pass,
#      not repeated mastery practice)
#   G: 2 chunks, each replayed 4x  -> 8 Quests (matches D's repetition depth)
# A Group's Quest N uses chunk (N mod chunk_count) — cycling back to the
# first chunk once every chunk has had a turn.
const QUEST_COUNTS_BY_GROUP : Array[int] = [4, 4, 4, 8, 4, 3, 8]   # A, B, C, D, E, F, G

static func quest_count_for_group(group_number: int) -> int:
	if group_number < 0 or group_number >= QUEST_COUNTS_BY_GROUP.size():
		return 4
	return QUEST_COUNTS_BY_GROUP[group_number]
