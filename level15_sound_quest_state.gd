class_name Level15SoundQuestState

# ─── Level 1.5 Sound Quest — shared data layer ─────────────────────────────
# Mirrors sound_quest_state.gd's role for Level 1, but built against Level
# 1.5's actual data model (data/words.json + data/phonemes.json, words tagged
# by structure/initial/final/phonemes[] — not a per-phoneme image folder scan
# like Level 1 uses). Loading follows game15.gd's own established pattern
# (same WORDS_PATH/PHONEMES_PATH, same JSON shape) for consistency.
#
# Quest A/B/C/D all share the same 117-word pool (CVC+CCVC+CVCC). Quest E/F
# use a wider pool (up to all 130 words) — their own builders come later.
# ─────────────────────────────────────────────────────────────────────────

const WORDS_PATH    := "res://data/words.json"
const PHONEMES_PATH := "res://data/phonemes.json"

const ABCD_STRUCTURES : Array = ["CVC", "CCVC", "CVCC"]

# ─── Data loading ───────────────────────────────────────────────────────────

static func load_words() -> Dictionary:
	var f : FileAccess = FileAccess.open(WORDS_PATH, FileAccess.READ)
	var data : Dictionary = (JSON.parse_string(f.get_as_text()) as Dictionary)["words"]
	f.close()
	return data


static func load_phonemes() -> Dictionary:
	var f : FileAccess = FileAccess.open(PHONEMES_PATH, FileAccess.READ)
	var data : Dictionary = (JSON.parse_string(f.get_as_text()) as Dictionary)["phonemes"]
	f.close()
	return data


# ─── Word pools ─────────────────────────────────────────────────────────────

# The shared 117-word pool for Quest A/B/C/D (CVC+CCVC+CVCC structures).
static func build_pool_abcd(all_words: Dictionary) -> Array:
	var pool : Array = []
	for key : String in all_words:
		if all_words[key]["structure"] in ABCD_STRUCTURES:
			pool.append(key)
	return pool


# ─── Quest A/B: eligible target phonemes ───────────────────────────────────
# position is "initial" (Quest A) or "final" (Quest B). A phoneme is eligible
# as a target only if its USABLE pool (total matching words minus the target
# word itself, since the target is never in its own correct pool) is >= 3 —
# the locked Quest A/B floor rule. Returns {phoneme: usable_count}.
static func eligible_target_phonemes(all_words: Dictionary, pool: Array, position: String) -> Dictionary:
	var totals : Dictionary = {}
	for key in pool:
		var ph : String = all_words[key][position]
		totals[ph] = totals.get(ph, 0) + 1

	var eligible : Dictionary = {}
	for ph in totals:
		var usable : int = totals[ph] - 1   # target word itself excluded
		if usable >= 3:
			eligible[ph] = usable
	return eligible


# Words in `pool` whose `position` ("initial"/"final") phoneme equals `phoneme`.
static func words_for_phoneme(all_words: Dictionary, pool: Array, position: String, phoneme: String) -> Array:
	var matches : Array = []
	for key in pool:
		if all_words[key][position] == phoneme:
			matches.append(key)
	return matches


# Correct pool (patches) for a chosen target word: every OTHER word sharing
# its position-phoneme, floor/ceiling applied. usable 3-10 -> use all; >10 ->
# a fresh random 6-10 subset each call (not fixed), per the locked rule.
static func build_correct_pool(all_words: Dictionary, pool: Array, position: String, target_word: String) -> Array:
	var phoneme : String = all_words[target_word][position]
	var candidates : Array = words_for_phoneme(all_words, pool, position, phoneme)
	candidates.erase(target_word)

	if candidates.size() <= 10:
		return candidates

	candidates.shuffle()
	var n : int = randi_range(6, 10)
	return candidates.slice(0, n)


# Distractors: any word in `pool` whose position-phoneme differs from the
# target's — floor/ceiling never applies to distractors, only the correct
# pool. Excludes the target word and every word already in the correct pool.
static func build_distractors(all_words: Dictionary, pool: Array, position: String, target_word: String, correct_pool: Array, count: int) -> Array:
	var target_phoneme : String = all_words[target_word][position]
	var exclude : Dictionary = {target_word: true}
	for w in correct_pool:
		exclude[w] = true

	var candidates : Array = []
	for key in pool:
		if exclude.has(key):
			continue
		if all_words[key][position] != target_phoneme:
			candidates.append(key)

	candidates.shuffle()
	return candidates.slice(0, mini(count, candidates.size()))


# ─── Quest A/B: 32/40-round target-phoneme schedule ────────────────────────
# Continuous round-robin across the WHOLE Quest arc (all Sets combined, not
# reset per Set) — every eligible phoneme gets at least one round; leftover
# rounds (total_rounds - eligible_phonemes.size()) go to the richest
# phonemes first, since repeating a rich phoneme shows genuinely different
# words (fresh ceiling redraw) while repeating a thin one would not.
static func build_target_schedule(eligible: Dictionary, total_rounds: int) -> Array:
	var phonemes : Array = eligible.keys()
	phonemes.sort_custom(func(a, b): return eligible[a] > eligible[b])   # richest first

	var schedule : Array = phonemes.duplicate()
	var extra : int = total_rounds - phonemes.size()
	for i in range(extra):
		schedule.append(phonemes[i % phonemes.size()])

	schedule.shuffle()
	return schedule
