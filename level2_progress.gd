class_name Level2Progress

static var sets : Array[String] = [
	"res://level2_set1.json",   # 2A  /a/ only
	"res://level2_set2.json",   # 2B  /i/ only
	"res://level2_set3.json",   # 2C  /a/ vs /i/
	"res://level2_set4.json",   # 2D  /o/ only
	"res://level2_set5.json",   # 2E  /u/ only
	"res://level2_set6.json",   # 2F  /o/ vs /u/
	"res://level2_set7.json",   # 2G  /e/ only
	"res://level2_set8.json",   # 2H  all 5 mixed
	"res://level2_set9.json",   # 2I  /a/+/e/  (Option 1)
	"res://level2_set10.json",  # 2J  /o/+/u/  (Option 1)
	"res://level2_set11.json",  # 2K  /i/ focus (Option 1)
	"res://level2_set12.json",  # 2L  all 5 mixed (Option 1)
]

static var set_labels : Array[String] = [
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
]

static var current_index  : int   = 0
static var last_score_pct : float = 0.0
static var retry_rounds   : Array = []
static var is_retry       : bool  = false
static var active         : bool  = false
static var cubes_earned   : int   = 0

static func current_set() -> String:
	return sets[current_index]

static func current_set_label() -> String:
	return set_labels[current_index]

static func has_next() -> bool:
	return current_index + 1 < sets.size()

static func advance() -> void:
	current_index += 1

static func is_option1() -> bool:
	return current_index >= 8

static func reset() -> void:
	current_index  = 0
	last_score_pct = 0.0
	retry_rounds.clear()
	is_retry      = false
	active        = false
	cubes_earned  = 0
