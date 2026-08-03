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
# The complete word bank for a Group, NOT a sample of it. Prep's own rounds
# only cover a subset of each phoneme's real word bank (some words only ever
# show up as a distractor there, or never at all), so reading round data for
# the word list itself silently undercounts what's actually available — for
# Group A that meant 38 words surfaced out of 54 that actually exist.
#
# Two-step fix: read every sub-set JSON in [start_index, end_index] only to
# find out which PHONEMES this Group range covers (each round's own
# phoneme_audio field is a reliable, already-correct signal for that), then
# pull the actual word list for each of those phonemes straight from its
# image folder (SoundUp_level1_word images/<LETTER>/) — the true complete
# bank — deriving word_audio/phoneme_audio from the matching asset folders
# rather than from whatever a specific round happened to reference.
static func build_word_pool(start_index: int, end_index: int) -> Array:
	var letters : Dictionary = {}   # phoneme letter -> true
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
			var ph_audio : String = rd.get("phoneme_audio", "")
			if ph_audio == "":
				continue
			letters[ph_audio.get_file().get_basename()] = true   # ".../M.wav" -> "M"

	var sorted_letters : Array = letters.keys()
	sorted_letters.sort()   # deterministic pool order across runs

	var seen : Dictionary = {}
	var pool : Array = []
	for letter in sorted_letters:
		var image_folder : String = _resolve_image_folder(letter)
		for word in _list_words_for_phoneme(image_folder):
			var image_path : String = "res://SoundUp_level1_word images/%s/%s.png" % [image_folder, word]
			if seen.has(image_path):
				continue
			seen[image_path] = true
			pool.append({
				"image": image_path,
				"word_audio": _resolve_word_audio(letter, word),
				"phoneme_audio": "res://BGM&effect/SoundUp_level1_phonemes/%s.wav" % letter,
			})
	return pool


# The image folder name doesn't always match the phoneme_audio basename it's
# derived from — per CLAUDE.md's documented special cases, some are dash-
# styled where the audio is underscore-styled (G-hard vs G_hard.wav), and a
# couple are lowercase on top of that (c-soft, x-gz). Rather than guess a
# single substitution rule (the casing isn't consistent even among the
# dash-styled ones), try the plausible variants and use whichever actually
# exists as a real folder.
static func _resolve_image_folder(letter: String) -> String:
	var candidates : Array = [
		letter,
		letter.replace("_", "-"),
		letter.replace("_", "-").to_lower(),
		letter.to_lower(),
	]
	for c in candidates:
		if DirAccess.dir_exists_absolute("res://SoundUp_level1_word images/%s" % c):
			return c
	return letter   # no match found; _list_words_for_phoneme() will just find nothing


# Every .png in a phoneme's (already-resolved) image folder — the source of
# truth for "which words exist for this phoneme," independent of which ones
# any specific round happened to sample.
static func _list_words_for_phoneme(image_folder: String) -> Array:
	var words : Array = []
	var dir := DirAccess.open("res://SoundUp_level1_word images/%s" % image_folder)
	if dir == null:
		return words
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.get_extension() == "png":
			words.append(fname.get_basename())
		fname = dir.get_next()
	dir.list_dir_end()
	words.sort()
	return words


# Word-sounds subfolders are inconsistently cased in the asset library —
# most phonemes are "V.wav"/"S.wav" etc., but at least B and M are lowercase
# "b.wav"/"m.wav" — so this tries the phoneme's own casing first, then
# lowercase, rather than assuming either is correct.
static func _resolve_word_audio(letter: String, word: String) -> String:
	var upper_path : String = "res://BGM&effect/SoundUp_level1_word sounds/%s.wav/%s.wav" % [letter, word]
	if ResourceLoader.exists(upper_path):
		return upper_path
	var lower_path : String = "res://BGM&effect/SoundUp_level1_word sounds/%s.wav/%s.wav" % [letter.to_lower(), word]
	if ResourceLoader.exists(lower_path):
		return lower_path
	return ""


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
