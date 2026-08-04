class_name LevelProgress

# Level 1 sets — add new set JSON paths here to extend.
# Transition scene reads this list automatically — nothing else needs changing.
# IMPORTANT: has_next() must be checked BEFORE advance() — see memory note.
static var sets : Array[String] = [
	"res://level_1a_1.json",  # 1A-1 — m, s, t, b, k, v        (3 choices) rounds 1–20
	"res://level_1a_2.json",  # 1A-2 — m, s, t, b, k, v        (3 choices) rounds 21–40
	"res://level_1b_1.json",  # 1B-1 — n, f, p, d, g-hard, j   (4 choices) rounds 1–20
	"res://level_1b_2.json",  # 1B-2 — n, f, p, d, g-hard, j   (4 choices) rounds 21–40
	"res://level_1c_1.json",  # 1C-1 — h, w, y, l, z, r        (4 choices) rounds 1–20
	"res://level_1c_2.json",  # 1C-2 — h, w, y, l, z, r        (4 choices) rounds 21–40
	"res://level_1c_3.json",  # 1C-3 — h, w, y, l, z, r        (4 choices) rounds 41–60
	"res://level_1d_1.json",  # 1D-1 — contrast pairs          (4 choices) rounds 1–19
	"res://level_1d_2.json",  # 1D-2 — contrast pairs          (4 choices) rounds 20–38
	"res://level_1d_3.json",  # 1D-3 — contrast pairs          (4 choices) rounds 39–56
	"res://level_1e_1.json",  # 1E-1 — c-soft, g-soft, x, q   (3 choices) rounds 1–20
	"res://level_1e_2.json",  # 1E-2 — c-soft, g-soft, x, q   (3 choices) rounds 21–40
	"res://level_1f_1.json",  # 1F-1 — all 21 mixed            (5 choices) rounds 1–20
	"res://level_1f_2.json",  # 1F-2 — all 21 mixed            (5 choices) rounds 21–40
	"res://level_1g_1.json",  # 1G-1 — ending sounds           (4 choices) rounds 1–19
	"res://level_1g_2.json",  # 1G-2 — ending sounds           (4 choices) rounds 20–37
	"res://level_1g_3.json",  # 1G-3 — ending sounds           (4 choices) rounds 38–55
]
static var set_labels : Array[String] = [
	"A1", "A2",
	"B1", "B2",
	"C1", "C2", "C3",
	"D1", "D2", "D3",
	"E1", "E2",
	"F1", "F2",
	"G1", "G2", "G3",
]
static var current_index  : int   = 0
static var last_score_pct : float = 0.0
static var cubes_earned   : int   = 0

# Retry system
# retry_rounds  — the non-clean round dicts from the last play; used on 2-star path
# is_retry      — true means _load_rounds() should load retry_rounds, not the JSON file
static var retry_rounds : Array = []
static var is_retry     : bool  = false

# ─── Main-set boundaries ──────────────────────────────────────────────────────
# 7 Groups (A–G). Each boundary is the index of the LAST sub-set in a Group.
# A:0-1 | B:2-3 | C:4-6 | D:7-9 | E:10-11 | F:12-13 | G:14-16
const MAIN_SET_BOUNDARIES : Array[int] = [1, 3, 6, 9, 11, 13, 16]

static func is_main_set_boundary() -> bool:
	return current_index in MAIN_SET_BOUNDARIES

# Returns which Group (0–6) the current sub-set belongs to.
static func main_set_number() -> int:
	for i in range(MAIN_SET_BOUNDARIES.size()):
		if current_index <= MAIN_SET_BOUNDARIES[i]:
			return i
	return MAIN_SET_BOUNDARIES.size() - 1

# Inclusive [start, end] sub-set index range for the Group current_index
# belongs to (e.g. Group A -> [0, 1]) — used by Level 1 Sound Quest to
# assemble a Group's combined word pool once is_main_set_boundary() is true.
static func current_group_range() -> Vector2i:
	var group   : int = main_set_number()
	var end_idx : int = MAIN_SET_BOUNDARIES[group]
	var start_idx : int = 0 if group == 0 else MAIN_SET_BOUNDARIES[group - 1] + 1
	return Vector2i(start_idx, end_idx)

static func current_set() -> String:
	return sets[current_index]

static func current_set_label() -> String:
	return set_labels[current_index]

static func has_next() -> bool:
	return current_index + 1 < sets.size()

static func advance() -> void:
	current_index += 1

static func reset() -> void:
	current_index = 0
	cubes_earned  = 0
	retry_rounds.clear()
	is_retry = false
