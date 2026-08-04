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
# The complete word bank for a Group, NOT a sample of it. A Level's own
# rounds only cover a subset of each phoneme's real word bank (some words
# only ever show up as a distractor there, or never at all), so reading
# round data for the word list itself silently undercounts what's actually
# available — for Prep Group A that meant 38 words surfaced out of 54 that
# actually exist.
#
# Shared by Prep and Level 1 Sound Quest alike — everything below the
# phoneme-detection step reads from the same level-agnostic asset folders
# regardless of which caller's round JSONs were used to find the phonemes.
#
# Two-step fix: read every given JSON path only to find out which PHONEMES
# this Group range covers (each round's own phoneme_audio field is a
# reliable, already-correct signal for that), then pull the actual word
# list for each of those phonemes straight from its image folder
# (SoundUp_level1_word images/<LETTER>/) — the true complete bank —
# deriving word_audio/phoneme_audio from the matching asset folders rather
# than from whatever a specific round happened to reference.
static func build_word_pool(json_paths: Array) -> Array:
	var letters : Dictionary = {}   # phoneme letter -> true
	for path in json_paths:
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
# Divides the pool into 4 chunks using the same base+remainder split already
# used in gnb_where_am_i.gd's _chunk_sets() (e.g. 54 words -> 14/14/13/13),
# then tops up any chunk smaller than the largest one by borrowing random
# words from elsewhere in the pool, so every Quest ends up the SAME size
# (e.g. 14/14/13/13 -> 14/14/14/14). A word repeating across a Quest
# boundary is fine here — sound_quest.gd's round loop re-samples each
# Quest's own pool repeatedly by design (that's the mastery mechanic), so
# uniqueness across the whole Group was never the goal, just a consistent
# round count per Quest. Not hardcoded to any specific word count: content
# is still evolving, some Groups may temporarily have fewer words than
# others, or fewer than 4 total (in which case the last chunk(s) come back
# empty — the gameplay loop is expected to skip an empty Quest and move to
# the next one).
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

	var target_size : int = 0
	for q in quests:
		target_size = maxi(target_size, q.size())
	for q in quests:
		while q.size() < target_size:
			var have : Dictionary = {}
			for w in q:
				have[w.get("image", "")] = true
			var candidates : Array = []
			for w in pool:
				if not have.has(w.get("image", "")):
					candidates.append(w)
			if candidates.is_empty():
				candidates = pool.duplicate()   # pool smaller than target_size itself; allow repeats within the Quest
			candidates.shuffle()
			q.append(candidates[0])
	return quests


# ─── Level 1 Sound Quest helpers ────────────────────────────────────────────
# Level 1's Quests don't split the pool like split_into_quests() above — all
# 4 Quests in a Group replay the SAME pool from scratch (repetition through
# full replay, not through content division). These two helpers support that
# model instead.

# Unique phoneme letters actually present in a built pool, derived from each
# entry's own phoneme_audio field — needed by build_round_schedule() below,
# since build_word_pool() only returns word entries, not the letter list it
# detected along the way.
static func phonemes_in_pool(pool: Array) -> Array:
	var letters : Dictionary = {}
	for w in pool:
		var letter : String = String(w.get("phoneme_audio", "")).get_file().get_basename()
		if letter != "":
			letters[letter] = true
	var sorted_letters : Array = letters.keys()
	sorted_letters.sort()
	return sorted_letters


# Pads a pool up to target_size (~56) by repeating existing words — round-
# robin across phonemes, and round-robin within each phoneme's own word
# list, so repeats stay spread out rather than piling onto one word or one
# phoneme. A no-op if the pool already meets or exceeds target_size.
static func pad_pool_to_size(pool: Array, target_size: int) -> Array:
	if pool.is_empty() or pool.size() >= target_size:
		return pool.duplicate()

	var by_phoneme : Dictionary = {}   # letter -> Array of this phoneme's pool entries
	for w in pool:
		var letter : String = String(w.get("phoneme_audio", "")).get_file().get_basename()
		if not by_phoneme.has(letter):
			by_phoneme[letter] = []
		by_phoneme[letter].append(w)

	var letters : Array = by_phoneme.keys()
	letters.sort()   # deterministic order

	var cursor : Dictionary = {}   # letter -> next repeat index into its own word list
	for letter in letters:
		cursor[letter] = 0

	var padded : Array = pool.duplicate()
	var li : int = 0
	while padded.size() < target_size:
		var letter : String = letters[li % letters.size()]
		var words  : Array  = by_phoneme[letter]
		padded.append(words[cursor[letter] % words.size()])
		cursor[letter] += 1
		li += 1
	return padded


# Builds a round_count-long schedule of bins_per_round active phonemes each,
# round-robin balanced via a shuffle-and-refill "bag" (draw phonemes without
# repeats until the bag empties, then reshuffle a fresh bag) so every
# phoneme gets a turn before any repeats, keeping exposure as even as
# round_count/bins_per_round allows across the whole schedule. Falls back to
# allowing within-round repeats only when a Group genuinely has fewer
# phonemes than bins_per_round (true uniqueness would be impossible then).
static func build_round_schedule(phonemes: Array, round_count: int, bins_per_round: int) -> Array:
	if phonemes.is_empty():
		return []
	var letters : Array = phonemes.duplicate()
	letters.sort()   # deterministic base order before shuffling

	var bag : Array = []
	var schedule : Array = []
	for _r in range(round_count):
		var round_phonemes : Array = []
		while round_phonemes.size() < bins_per_round:
			if bag.is_empty():
				bag = letters.duplicate()
				bag.shuffle()
			var candidate : String = bag.pop_back()
			if candidate in round_phonemes:
				if letters.size() < bins_per_round:
					round_phonemes.append(candidate)
				else:
					bag.push_front(candidate)   # retry with a different draw
			else:
				round_phonemes.append(candidate)
		schedule.append(round_phonemes)
	return schedule


# Splits a pool into chunks by whole PHONEME — never splitting one
# phoneme's own words across two chunks, since a Bin needs its full word
# set available in whichever single chunk/Quest features it — using a
# greedy largest-phoneme-first balance (repeatedly assign the biggest
# remaining phoneme to whichever chunk currently has the smallest total)
# so each chunk's word count stays close to max_chunk_size. A pool that
# already fits within max_chunk_size comes back as a single chunk — this
# is a strict generalization of the single-pool-per-Group model, not a
# separate path: Groups small enough to need no splitting just get
# chunk count 1.
static func split_pool_by_phoneme_balanced(pool: Array, max_chunk_size: int) -> Array:
	if pool.is_empty():
		return [[]]
	if pool.size() <= max_chunk_size:
		return [pool.duplicate()]

	var by_phoneme : Dictionary = {}   # letter -> Array of this phoneme's pool entries
	for w in pool:
		var letter : String = String(w.get("phoneme_audio", "")).get_file().get_basename()
		if not by_phoneme.has(letter):
			by_phoneme[letter] = []
		by_phoneme[letter].append(w)

	var letters : Array = by_phoneme.keys()
	letters.sort()   # deterministic base order
	letters.sort_custom(func(a, b): return by_phoneme[a].size() > by_phoneme[b].size())

	var chunk_count : int = ceili(float(pool.size()) / float(max_chunk_size))
	var chunks : Array = []
	var chunk_totals : Array = []
	for _c in range(chunk_count):
		chunks.append([])
		chunk_totals.append(0)

	for letter in letters:
		var smallest_idx : int = 0
		for i in range(1, chunk_totals.size()):
			if chunk_totals[i] < chunk_totals[smallest_idx]:
				smallest_idx = i
		chunks[smallest_idx].append_array(by_phoneme[letter])
		chunk_totals[smallest_idx] += by_phoneme[letter].size()

	return chunks
