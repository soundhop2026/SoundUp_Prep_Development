class_name SoundQuestState

# Handoff state for Sound Quest, same pattern as PremiumIntroState/ReviewState/
# LevelIntroState — set right before change_scene_to_file("res://sound_quest.tscn"),
# read once by sound_quest.gd's _ready().
#
# group_start_index / group_end_index are inclusive indices into
# PrepLevelProgress.sets (and set_labels) spanning the Group that just
# finished — e.g. Group A = 0..3. Set via PrepLevelProgress.current_group_range().
static var group_start_index : int = 0
static var group_end_index   : int = 0

# QA-only: when true, sound_quest.gd's _ready() skips straight to Quest 1's
# Quest Transition celebration instead of playing through the quest itself —
# lets the debug menu preview the transition without grinding a full quest.
# Read once and reset to false immediately, same one-shot handoff pattern as
# the group indices above.
static var debug_skip_to_transition : bool = false


# ─── Word pool ──────────────────────────────────────────────────────────────
# Reads every sub-set JSON in [start_index, end_index] and returns the unique
# CORRECT-ANSWER words from each round — not every choice/distractor. This
# matters for two reasons: (1) a round's distractors are frequently OTHER
# groups' phonemes mixed in for discrimination practice, so only the correct
# answer reliably represents "the phonemes used in this Group"; (2) only the
# correct answer has a well-defined phoneme_audio (the round's own target
# phoneme) for the "tap to hear its phoneme" interaction — a distractor's
# actual initial sound isn't recorded anywhere in the round data.
# Dedupes by image path, since the same word can be the correct answer in
# more than one round across a Group's 4 sub-sets.
static func build_word_pool(start_index: int, end_index: int) -> Array:
	var seen : Dictionary = {}
	var pool : Array = []
	for i in range(start_index, end_index + 1):
		if i < 0 or i >= PrepLevelProgress.sets.size():
			continue
		var path : String = PrepLevelProgress.sets[i]
		if not FileAccess.file_exists(path):
			continue
		var file : FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(data) != TYPE_DICTIONARY:
			continue
		for rd in data.get("rounds", []):
			var choices : Array = rd.get("choices", [])
			var slot    : int   = rd.get("correct_slot", 0)
			if slot < 1 or slot > choices.size():
				continue
			var choice : Dictionary = choices[slot - 1]
			var image  : String     = choice.get("image", "")
			if image == "" or seen.has(image):
				continue
			seen[image] = true
			pool.append({
				"image": image,
				"word_audio": choice.get("word_audio", ""),
				"phoneme_audio": rd.get("phoneme_audio", ""),
			})
	return pool


# ─── Quest split ────────────────────────────────────────────────────────────
# Divides the pool into 4 as-even-as-possible chunks — same base+remainder
# split already used in gnb_where_am_i.gd's _chunk_sets(). Not hardcoded to
# any specific word count: content is still evolving, some Groups may
# temporarily have fewer words than others, or fewer than 4 total (in which
# case the last chunk(s) come back empty — the gameplay loop is expected to
# skip an empty Quest and move to the next one).
const QUEST_COUNT : int = 4

static func split_into_quests(pool: Array) -> Array:
	var total : int = pool.size()
	var base  : int = total / QUEST_COUNT
	var extra : int = total % QUEST_COUNT
	var quests : Array = []
	var idx : int = 0
	for q in range(QUEST_COUNT):
		var size : int = base + (1 if q < extra else 0)
		quests.append(pool.slice(idx, idx + size))
		idx += size
	return quests
