class_name PrepLevelProgress

# ─── Prep Level Progress ──────────────────────────────────────────────────────
# Manages routing through the 33 prep sets and accuracy tracking.
#
# Accuracy rule: a round is "wrong" if the child pressed a wrong button
# at least once, even if they eventually got it right.
# Gate: accuracy >= 85% to graduate to Level 1.
#
# IMPORTANT: has_next() must be checked BEFORE advance().
# ─────────────────────────────────────────────────────────────────────────────

static var sets : Array[String] = [
	# ── Set 1: M S T B V K (3 choices) ──────────────────────────────────────
	"res://prep_1a_1.json",
	"res://prep_1a_2.json",
	"res://prep_1a_3.json",
	"res://prep_1a_4.json",
	# ── Set 2: N F P D G J (4 choices) ──────────────────────────────────────
	"res://prep_1b_1.json",
	"res://prep_1b_2.json",
	"res://prep_1b_3.json",
	"res://prep_1b_4.json",
	# ── Set 3: H W Y L R Z (4 choices) ──────────────────────────────────────
	"res://prep_1c_1.json",
	"res://prep_1c_2.json",
	"res://prep_1c_3.json",
	"res://prep_1c_4.json",
	"res://prep_1c_5.json",
	"res://prep_1c_6.json",
	# ── Set 4: Contrast pairs (4 choices) ────────────────────────────────────
	"res://prep_1d_1.json",
	"res://prep_1d_2.json",
	"res://prep_1d_3.json",
	"res://prep_1d_4.json",
	"res://prep_1d_5.json",
	"res://prep_1d_6.json",
	# ── Set 5: Q X-ks S K (3 choices) ───────────────────────────────────────
	"res://prep_1e_1.json",
	"res://prep_1e_2.json",
	# ── Set 6: All sounds mixed (5 choices) ──────────────────────────────────
	"res://prep_1f_1.json",
	"res://prep_1f_2.json",
	"res://prep_1f_3.json",
	"res://prep_1f_4.json",
]

static var set_labels : Array[String] = [
	"A1", "A2", "A3", "A4",
	"B1", "B2", "B3", "B4",
	"C1", "C2", "C3", "C4", "C5", "C6",
	"D1", "D2", "D3", "D4", "D5", "D6",
	"E1", "E2",
	"F1", "F2", "F3", "F4",
]
static var current_index  : int   = 0
static var last_score_pct : float = 100.0
static var cubes_earned   : int   = 0

# Retry state
static var retry_rounds : Array = []
static var is_retry     : bool  = false

# ─── Main-set boundaries ──────────────────────────────────────────────────────
# 6 main sets (1A–1F). Each boundary is the index of the LAST sub-set in a group.
# 1A:0-3 | 1B:4-7 | 1C:8-13 | 1D:14-19 | 1E:20-21 | 1F:22-25
const MAIN_SET_BOUNDARIES : Array[int] = [3, 7, 13, 19, 21, 25]

static func is_main_set_boundary() -> bool:
	return current_index in MAIN_SET_BOUNDARIES

# ─── Free / premium boundary ───────────────────────────────────────────────────
# Sets 1-2 (index 0-1) are free; Set 3 (index 2) onward requires the Parent Gate.
const FREE_SET_COUNT : int = 2

static func is_free_set(index: int) -> bool:
	return index < FREE_SET_COUNT

# True right after finishing the last free set, before advancing past it —
# the exact moment the Parent Gate should intercept progression.
static func crosses_into_premium() -> bool:
	return is_free_set(current_index) and not is_free_set(current_index + 1)

# Returns which main set (0–6) the current sub-set belongs to.
static func main_set_number() -> int:
	for i in range(MAIN_SET_BOUNDARIES.size()):
		if current_index <= MAIN_SET_BOUNDARIES[i]:
			return i
	return MAIN_SET_BOUNDARIES.size() - 1

# ─── Routing ──────────────────────────────────────────────────────────────────

static func current_set() -> String:
	return sets[current_index]

static func current_set_label() -> String:
	return set_labels[current_index]

static func has_next() -> bool:
	return current_index + 1 < sets.size()

static func advance() -> void:
	current_index += 1
	SaveManager.set_prep_set_index(current_index)

# ─── Reset / Save ─────────────────────────────────────────────────────────────

static func reset() -> void:
	current_index  = 0
	last_score_pct = 100.0
	cubes_earned   = 0
	retry_rounds   = []
	is_retry       = false
	SaveManager.set_prep_set_index(0)

static func load_from_save() -> void:
	current_index = SaveManager.get_prep_set_index()
