class_name Level15Progress

# Level 1.5 sets — 13 total, in order.
# Same mastery thresholds as Level 1: 95%+ = 3★, 85–94% = 2★, <85% = 1★.
static var sets : Array[String] = [
	"res://data/level1.5/set_1a.json",   # Initial Phoneme Identification  15 rounds
	"res://data/level1.5/set_1b.json",   # Initial Phoneme Identification  15 rounds
	"res://data/level1.5/set_2a.json",   # Final Phoneme Identification    15 rounds
	"res://data/level1.5/set_2b.json",   # Final Phoneme Identification    15 rounds
	"res://data/level1.5/set_3a.json",   # Initial Phoneme Isolation       15 rounds
	"res://data/level1.5/set_3b.json",   # Initial Phoneme Isolation       15 rounds
	"res://data/level1.5/set_4a.json",   # Final Phoneme Isolation         15 rounds
	"res://data/level1.5/set_4b.json",   # Final Phoneme Isolation         15 rounds
	"res://data/level1.5/set_5a.json",   # Build the Word — CVC only       20 rounds
	"res://data/level1.5/set_5b.json",   # Build the Word — CVC/CCVC/CVCC  20 rounds
	"res://data/level1.5/set_5c.json",   # Build the Word — Advanced       20 rounds
	"res://data/level1.5/set_5d.json",   # Build the Word — Challenge      20 rounds
	"res://data/level1.5/set_6.json",    # Sound Count                     20 rounds
]
static var set_labels : Array[String] = [
	"A1", "A2",
	"B1", "B2",
	"C1", "C2",
	"D1", "D2",
	"E1", "E2", "E3", "E4",
	"F",
]
static var current_index  : int   = 0
static var last_score_pct : float = 0.0
static var cubes_earned   : int   = 0

# Retry system — mirrors LevelProgress exactly.
# is_retry = true  → game15.gd loads retry_rounds instead of generating fresh rounds.
static var retry_rounds : Array = []
static var is_retry     : bool  = false

# Set true by game15.gd before routing to transition.tscn.
# transition.gd reads this flag to know it should use Level15Progress.
# Reset to false by transition.gd after routing completes.
static var active : bool = false


static func current_set() -> String:
	return sets[current_index]


static func current_set_label() -> String:
	return set_labels[current_index]


static func has_next() -> bool:
	return current_index + 1 < sets.size()


static func advance() -> void:
	current_index += 1
	SaveManager.set_level15_set_index(current_index)


static func reset() -> void:
	current_index = 0
	cubes_earned  = 0
	retry_rounds.clear()
	is_retry = false
	SaveManager.set_level15_set_index(0)
