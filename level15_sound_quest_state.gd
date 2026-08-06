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


# ─── Quest C/D: phoneme frequency + linear-scaled target bubble count ──────
# Unlike A/B, every phoneme that appears at all is a valid target — no floor
# — since C/D bubbles are repeated audio copies of a phoneme, not distinct
# words, so even a 1-word phoneme (z, s, l) can still anchor a round.
# position is "initial" (Quest C) or "final" (Quest D). Returns
# {phoneme: word_count} across the whole A/B/C/D pool.
static func phoneme_frequencies(all_words: Dictionary, pool: Array, position: String) -> Dictionary:
	var counts : Dictionary = {}
	for key in pool:
		var ph : String = all_words[key][position]
		counts[ph] = counts.get(ph, 0) + 1
	return counts


# Linear-scaled 4-10 target bubble count: the richest phoneme (highest word
# frequency) maps to 10, the rarest to 4. min_freq/max_freq are the extremes
# across all eligible phonemes for this position (phoneme_frequencies()'s
# values), not global constants.
static func cd_target_bubble_count(freq: int, min_freq: int, max_freq: int) -> int:
	if max_freq == min_freq:
		return 10
	var t : float = 4.0 + float(freq - min_freq) / float(max_freq - min_freq) * 6.0
	return roundi(t)


# Distractor phonemes: any of the full phonemes.json set (19 consonants + 5
# vowels) except the target, each used at most once per round — only the
# target phoneme repeats across the round's 20-bubble pool.
static func cd_build_distractor_phonemes(all_phonemes: Dictionary, target_phoneme: String, count: int) -> Array:
	var candidates : Array = []
	for ph in all_phonemes:
		if ph != target_phoneme:
			candidates.append(ph)
	candidates.shuffle()
	return candidates.slice(0, mini(count, candidates.size()))


# ─── Quest E: full word pool (all 4 structures, unlike A/B/C/D's 117-word ──
# ─── CVC/CCVC/CVCC-only subset) ─────────────────────────────────────────────
static func build_pool_e(all_words: Dictionary) -> Array:
	return all_words.keys()


# Shuffled word schedule for Quest E's 100 rounds. No frequency weighting
# needed (unlike A/B's phoneme schedule) — each word is an equal unit, and
# 100 rounds is under the ~130-word pool size so this lands as no-repeat
# coverage in the common case; the cycle-with-reshuffle fallback only
# matters if total_rounds ever exceeds the pool.
static func build_word_schedule(pool: Array, total_rounds: int) -> Array:
	var schedule : Array = pool.duplicate()
	schedule.shuffle()
	if schedule.size() >= total_rounds:
		return schedule.slice(0, total_rounds)
	var extra : int = total_rounds - schedule.size()
	for i in range(extra):
		schedule.append(schedule[i % pool.size()])
	schedule.shuffle()
	return schedule


# Distractor phonemes for Quest E: the full 24-phoneme pool, excluding ALL of
# the target word's own phonemes (not just one, unlike C/D's single-phoneme
# exclusion) — a longer (CCVCC) word's difficulty comes from the sequencing
# task itself, not also a bigger distractor field to search.
static func e_build_distractor_phonemes(all_phonemes: Dictionary, target_phonemes: Array, count: int) -> Array:
	var exclude : Dictionary = {}
	for ph in target_phonemes:
		exclude[ph] = true
	var candidates : Array = []
	for ph in all_phonemes:
		if not exclude.has(ph):
			candidates.append(ph)
	candidates.shuffle()
	return candidates.slice(0, mini(count, candidates.size()))
