extends Node2D

# ─── Sound Quest ────────────────────────────────────────────────────────────
# Mastery activity (not a teaching activity) shown once per Prep Group, right
# after that Group's last sub-set finishes (see prep_transition.gd's
# is_main_set_boundary() branch). Reached via SoundQuestState's handoff.
#
# 4 words visible at once in a row across the top, each bobbing in its own
# fixed area. Tap = hear the phoneme (unlimited, exploration only). The
# single shared maze is visible continuously for the whole round — it
# appears the moment the round starts and never hides again until the round
# is over, so the child always has a visible destination. Press-and-drag
# past the bobbing area's boundary begins a two-phase attempt:
#
#  1. Approach — each image has its own hidden, winding path (loops + wide
#     zigzags) connecting it to the maze's single entry point. Invisible
#     until this drag crosses the boundary, then revealed as a dashed
#     purple trail; straying more than a small tolerance off it fails
#     instantly. The dashes disappear the instant the image reaches the
#     maze — the maze itself was already visible the whole time.
#  2. Maze — one entry, one exit, everywhere else on its boundary sealed,
#     with no visible line inside at all — pure hard-wall navigation by
#     feel. Reaching the goal marks the word mastered.
#
# The maze's *shape* regenerates fresh after every attempt (fail or
# success, see _reshape_maze()) so nothing can be memorized, but the maze
# itself never disappears and reappears — it reshapes in place. Failed
# words stay in the same visible slot for immediate retry — never requeued.
#
# Words are grouped into Quest Rounds of exactly 4 — the whole round has to
# finish (all 4 mastered) before the next round of 4 begins; nothing refills
# individually mid-round. A round is never partial: if a Quest's remaining
# new words run short of 4, it's padded with review words already mastered
# earlier in the Group. Each mastered image moves to a horizontal row on the
# right instead of disappearing, staying visible there until the round ends.
#
# 4 Quests per Group; Quest Transition is a purely decorative Play-Button-
# walks-a-maze celebration between them. After Quest 4, hands back to normal
# Prep progression exactly like prep_transition.gd's _continue_to_next_set().
# ─────────────────────────────────────────────────────────────────────────────

const FONT_PATH : String = "res://UI_assets/210 연필스케치R.ttf"
const MUSIC_PATH : String = "res://soundquest/assets/quest_preplevel_bgm.mp3"

const BG_COLOR     : Color = Color("#A8E063")   # same baby-green as Prep
const PURPLE       : Color = Color("#4B0082")
const AMBER        : Color = Color("#FFB703")
const WHITE        : Color = Color("#FFFFFF")
const WALL_COLOR   : Color = Color("#2E2E2E")   # thick hand-drawn-style wall lines
# Light violet, not the deep #4B0082 brand purple — deep purple against near-
# black walls had too little contrast to actually read as a distinct path.
const ROUTE_COLOR  : Color = Color("#B388FF")

# 4 fixed slot centers in a single row across the top, feeding down into the
# one shared maze near the bottom via each image's own approach path.
const SLOT_POSITIONS : Array[Vector2] = [
	Vector2(195, 180),
	Vector2(534, 180),
	Vector2(749, 180),
	Vector2(1090, 180),
]

const IMAGE_BOX     : float = 150.0    # word image fits within this box
# The dragged image shrinks to roughly this size for the whole journey (both
# the approach path and the maze) — at the full 150px IMAGE_BOX it would
# blanket most of a 65px-cell corridor and hide whatever it's meant to be
# following, visible route or not.
const MAZE_DRAG_IMAGE_SIZE : float = 60.0
const BOB_AREA_SIZE : Vector2 = Vector2(190, 190)   # boundary the drag must cross
const BOB_AMPLITUDE : float = 8.0
const BOB_HALF_DUR  : float = 0.9

const TAP_MOVE_THRESHOLD : float = 14.0   # px — below this, a release counts as a tap

# One shared maze for every image and every Group — difficulty is carried by
# route STYLE (see STYLE_WEIGHTS_BY_GROUP below), not by growing the box.
# A wide, tall band near the bottom of the screen, well clear of the top
# image row (which ends around y=255) and the completed row to its right.
# Sealed on every side except one entry (left edge) and one exit (right
# edge, feeding the completed row) — see maze_generator.gd's wall_segments().
const MAZE_COLS       : int      = 12
const MAZE_ROWS        : int      = 4
const MAZE_CELL_SIZE   : float    = 65.0
const MAZE_ORIGIN      : Vector2  = Vector2(60, 420)
const MAZE_START_CELL  : Vector2i = Vector2i(0, 2)   # the maze's one shared entry, left edge
const MAZE_WALL_WIDTH  : float = 6.0
const ROUTE_WIDTH      : float = 8.0
const GOAL_MARKER_R    : float = 14.0

const MOVE_STOP_DELAY : float = 0.18   # no drag-motion event within this window = "stopped"

# ─── Approach path ──────────────────────────────────────────────────────────
# The hidden, winding path connecting a chosen image to the maze's single
# entry — invisible until that image is dragged past its bobbing boundary,
# and hidden again the instant it reaches the maze. Distinct from the maze:
# never grid-based, no hard walls — a smooth polyline the drag has to stay
# within a tolerance band of, tracked by progress *along* the path (not raw
# position), since the path loops back over itself and a plain "am I near
# any purple pixel" check would get confused at those crossings.
const APPROACH_TOLERANCE  : float = 40.0   # px — how far off the path still counts as "on" it
const APPROACH_LOOKAHEAD  : int   = 6      # segments searched ahead of current progress each frame
const APPROACH_LOOP_MIN   : int   = 1
const APPROACH_LOOP_MAX   : int   = 2
const APPROACH_ZIGZAG_MIN : int   = 3
const APPROACH_ZIGZAG_MAX : int   = 5
const APPROACH_ZIGZAG_LEFT_X  : float = 80.0
const APPROACH_ZIGZAG_RIGHT_X : float = 1150.0
# Rendered as a dashed trail rather than one solid stroke — a continuous
# line reads as a technical/debug overlay; dashes read as a path to follow.
const APPROACH_DASH_LEN : float = 18.0
const APPROACH_GAP_LEN  : float = 14.0

# A Quest Round is always exactly 4 images — never a partial round. If a
# Quest's remaining new words run short of 4, the round is padded with review
# words already mastered earlier in this Group (see _pick_review_word()).
# All 4 of a round's images must exit before the next round begins.
const ROUND_SIZE : int = 4

# Completed images from the current round move here — a simple horizontal
# row, capped at ROUND_SIZE since a round is never bigger than 4. Positioned
# just past the maze's exit (right edge, x=780) so it reads as "this is
# where the maze leads." Clears at the start of every new round.
const COMPLETED_ROW_Y       : float = 600.0
const COMPLETED_ROW_START_X : float = 900.0
const COMPLETED_ROW_STEP    : float = 90.0
const COMPLETED_THUMB_SIZE  : float = 70.0
const COMPLETED_MOVE_DUR    : float = 0.35
const ROUND_COMPLETE_BEAT   : float = 0.4   # holds the full row on screen for a beat before it clears

const QUEST_COUNT : int = 4

# Route-style eligibility weights by Group (0=A ... 5=F). Weighted, not a hard
# per-Group cutoff, so the spectrum widens gradually — no abrupt jump between
# adjacent Groups. Group A does not start at the gentlest possible maze: it
# leans toward MazeGenerator.STYLE_CURVE but already mixes in zigzag/winding;
# every later Group shifts more weight toward zigzag/winding/spiral.
const STYLE_WEIGHTS_BY_GROUP : Array[Dictionary] = [
	{"curve": 6, "zigzag": 3, "winding": 1, "spiral": 0},   # A
	{"curve": 5, "zigzag": 3, "winding": 2, "spiral": 0},   # B
	{"curve": 3, "zigzag": 4, "winding": 3, "spiral": 1},   # C
	{"curve": 2, "zigzag": 4, "winding": 4, "spiral": 2},   # D
	{"curve": 1, "zigzag": 3, "winding": 4, "spiral": 3},   # E
	{"curve": 1, "zigzag": 2, "winding": 4, "spiral": 4},   # F
]

# Per-slot state
const ST_EMPTY         : String = "empty"
const ST_BOBBING       : String = "bobbing"
const ST_DRAG_IN_AREA  : String = "drag_in_area"
const ST_DRAG_APPROACH : String = "drag_approach"   # following the revealed path toward the maze
const ST_DRAG_MAZE     : String = "drag_maze"


var _font : Font = null

var _quests        : Array = []   # Array[Array[Dictionary]] — 4 quests of {image, word_audio, phoneme_audio}
var _quest_index    : int   = 0
var _quest_remaining : Array = []  # new words in the current Quest not yet placed in a round
var _quest_total_words : int = 0
var _quest_done_words  : int = 0

var _group_mastered : Array = []   # every word mastered so far this Group session — review-word source

var _slots : Array = []   # per-slot Dictionary, see _make_slot()

var _completed_this_round : int   = 0    # how many of the current round's 4 have exited so far
var _completed_row_nodes  : Array = []   # parked TextureButtons, freed when the next round starts

var _dragging_slot_index : int = -1
var _drag_press_pos      : Vector2 = Vector2.ZERO
var _drag_moved_far      : bool    = false
var _drag_anchor_pointer : Vector2 = Vector2.ZERO   # pointer pos at the moment maze mode was entered
var _drag_anchor_target  : Vector2 = Vector2.ZERO   # image center pos at that same moment (== maze start)

var _maze          = null   # MazeGenerator.MazeData
var _maze_container : Node2D = null

var _approach_points    : Array    = []   # Array[Vector2] — this attempt's winding path, image -> maze entry
var _approach_index     : int      = 0    # how far along _approach_points progress has been confirmed
var _approach_container : Node2D   = null

var _phoneme_player : AudioStreamPlayer = null
var _word_player     : AudioStreamPlayer = null
var _success_player  : AudioStreamPlayer = null
var _fail_player     : AudioStreamPlayer = null
var _music_player     : AudioStreamPlayer = null

var _word_audio_active : bool = false   # guards the manual play->finished->replay loop
var _move_timer : Timer = null   # word audio pauses when no drag-motion arrives within MOVE_STOP_DELAY

var _busy : bool = false   # true during Quest Transition / group handoff — input ignored


func _ready() -> void:
	SceneBackground.set_color(BG_COLOR)
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)

	var bg := ColorRect.new()
	bg.color        = BG_COLOR
	bg.size         = get_viewport_rect().size
	bg.position     = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_build_audio_players()
	_maze_container = Node2D.new()
	add_child(_maze_container)
	_approach_container = Node2D.new()
	add_child(_approach_container)

	var pool : Array = SoundQuestState.build_word_pool(
		SoundQuestState.group_start_index, SoundQuestState.group_end_index)
	_quests = SoundQuestState.split_into_quests(pool)

	_quest_index = 0
	_start_quest()


func _build_audio_players() -> void:
	_phoneme_player = AudioStreamPlayer.new()
	_word_player     = AudioStreamPlayer.new()
	_success_player  = AudioStreamPlayer.new()
	_fail_player     = AudioStreamPlayer.new()
	add_child(_phoneme_player)
	add_child(_word_player)
	add_child(_success_player)
	add_child(_fail_player)

	if ResourceLoader.exists("res://BGM&effect/SoundUp_feedback/gayageum_correct.wav"):
		_success_player.stream = load("res://BGM&effect/SoundUp_feedback/gayageum_correct.wav")
	if ResourceLoader.exists("res://BGM&effect/SoundUp_feedback/oops_try_again.wav"):
		_fail_player.stream = load("res://BGM&effect/SoundUp_feedback/oops_try_again.wav")

	_word_player.finished.connect(_on_word_player_finished)

	_move_timer = Timer.new()
	_move_timer.one_shot   = true
	_move_timer.wait_time  = MOVE_STOP_DELAY
	_move_timer.timeout.connect(_on_move_stop_timeout)
	add_child(_move_timer)


# ─── Background music ───────────────────────────────────────────────────────
# Plays only during the Quest Transition beat between rounds/quests, not
# during gameplay itself — started at the top of _play_quest_transition() and
# stopped at its end. Same manual loop-on-finished idiom as level_transition.
# gd's _start_music()/_on_music_finished().
func _start_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	_music_player           = AudioStreamPlayer.new()
	_music_player.stream    = load(MUSIC_PATH)
	_music_player.volume_db = 0.0
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	_music_player.play()


func _on_music_finished() -> void:
	if _music_player != null:
		_music_player.play()


func _stop_music() -> void:
	if _music_player == null:
		return
	if _music_player.playing:
		var fade := create_tween()
		fade.tween_property(_music_player, "volume_db", -40.0, 1.0)
		await fade.finished
	_music_player.stop()


# ─── Quest lifecycle ────────────────────────────────────────────────────────

func _start_quest() -> void:
	if _quest_index >= QUEST_COUNT:
		_on_all_quests_complete()
		return

	var words : Array = _quests[_quest_index]
	if words.is_empty():
		# Content still evolving — a Group can have fewer than 4 non-empty
		# Quests. Skip straight past an empty one.
		_quest_index += 1
		_start_quest()
		return

	_quest_remaining   = words.duplicate()
	_quest_total_words = words.size()
	_quest_done_words  = 0

	for slot in _slots:
		if slot.get("node") != null:
			slot["node"].queue_free()
	_slots.clear()
	for i in range(SLOT_POSITIONS.size()):
		_slots.append(_make_slot(i))

	_start_round_or_finish()


# No node is created here anymore — _place_word_in_slot() creates a fresh one
# every round, since a mastered word's node is handed off to the completed
# row (see _succeed_attempt()) rather than reused for the next occupant.
func _make_slot(index: int) -> Dictionary:
	return {
		"node"      : null,
		"base_pos"  : SLOT_POSITIONS[index],
		"word"      : {},
		"state"     : ST_EMPTY,
		"bob_tween" : null,
	}


# Starts the next Quest Round, or — if this Quest has no new words left —
# ends the Quest and moves to Quest Transition. A round is only ever started
# with real new content; once _quest_remaining is empty there is nothing left
# to introduce, so the Quest ends here rather than generating an all-review
# round.
func _start_round_or_finish() -> void:
	if _quest_remaining.is_empty():
		_clear_completed_row()
		_clear_maze()
		_quest_index += 1
		_play_quest_transition()
		return
	_start_round()


# Builds exactly ROUND_SIZE (4) words for the round: new words first, padded
# with review words already mastered this Group if the Quest's remaining
# pool runs short (see _pick_review_word()) — a round is never partial.
func _start_round() -> void:
	_clear_completed_row()
	_reshape_maze()

	var round_words : Array = []
	for i in range(ROUND_SIZE):
		if not _quest_remaining.is_empty():
			round_words.append(_quest_remaining.pop_front())
		else:
			round_words.append(_pick_review_word(round_words))

	for i in range(ROUND_SIZE):
		_place_word_in_slot(i, round_words[i])


# Picks a word already mastered this Group session, excluding anything
# already chosen for this round (both new and review picks so far) so a
# round never shows the same image twice. Falls back to allowing a repeat
# only if the distinct mastered pool is smaller than what's still needed —
# not possible with the current word bank (every Quest that needs padding
# already has at least 8 mastered words to draw from within itself, and
# Group E's one 3-word Quest draws from its Group's earlier Quests) but kept
# as a graceful degradation rather than a crash if content ever gets sparser.
func _pick_review_word(exclude: Array) -> Dictionary:
	if _group_mastered.is_empty():
		return {}
	var exclude_images : Dictionary = {}
	for w in exclude:
		exclude_images[w.get("image", "")] = true
	var candidates : Array = []
	for w in _group_mastered:
		if not exclude_images.has(w.get("image", "")):
			candidates.append(w)
	if candidates.is_empty():
		candidates = _group_mastered.duplicate()
	return candidates[randi() % candidates.size()]


func _place_word_in_slot(index: int, word: Dictionary) -> void:
	var base_pos : Vector2 = SLOT_POSITIONS[index]
	var btn := TextureButton.new()
	btn.ignore_texture_size = true
	btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.size                = Vector2(IMAGE_BOX, IMAGE_BOX)
	btn.pivot_offset        = Vector2(IMAGE_BOX, IMAGE_BOX) / 2.0
	btn.mouse_filter        = Control.MOUSE_FILTER_STOP
	add_child(btn)

	var tex : Texture2D = null
	if word.get("image", "") != "" and ResourceLoader.exists(word["image"]):
		tex = load(word["image"]) as Texture2D
	btn.texture_normal = tex
	btn.position        = base_pos - btn.pivot_offset
	btn.modulate.a      = 0.0
	btn.visible         = true

	var slot : Dictionary = _slots[index]
	slot["node"]  = btn
	slot["word"]  = word
	slot["state"] = ST_BOBBING
	_slots[index] = slot

	var fade := create_tween()
	fade.tween_property(btn, "modulate:a", 1.0, 0.25)

	_start_bob(index)


func _completed_row_slot_pos(i: int) -> Vector2:
	return Vector2(COMPLETED_ROW_START_X + i * COMPLETED_ROW_STEP, COMPLETED_ROW_Y)


func _clear_completed_row() -> void:
	for n in _completed_row_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_completed_row_nodes.clear()
	_completed_this_round = 0


# All 4 of the current round's slots are empty (every image has exited) —
# hold the completed row on screen for a beat, then start the next round or
# finish the Quest.
func _check_round_complete() -> void:
	for slot in _slots:
		if slot["state"] != ST_EMPTY:
			return
	_on_round_complete()


func _on_round_complete() -> void:
	await get_tree().create_timer(ROUND_COMPLETE_BEAT).timeout
	_start_round_or_finish()


# ─── Bobbing ────────────────────────────────────────────────────────────────

func _start_bob(index: int) -> void:
	var slot : Dictionary = _slots[index]
	var btn  : TextureButton = slot["node"]
	if slot["bob_tween"] != null:
		slot["bob_tween"].kill()
	btn.position = slot["base_pos"] - btn.pivot_offset
	var t := create_tween().set_loops()
	t.tween_property(btn, "position:y", btn.position.y - BOB_AMPLITUDE, BOB_HALF_DUR) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(btn, "position:y", btn.position.y + BOB_AMPLITUDE, BOB_HALF_DUR) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	slot["bob_tween"] = t
	slot["state"]     = ST_BOBBING
	_slots[index] = slot


func _stop_bob(index: int) -> void:
	var slot : Dictionary = _slots[index]
	if slot["bob_tween"] != null:
		slot["bob_tween"].kill()
		slot["bob_tween"] = null
	_slots[index] = slot


func _snap_back(index: int) -> void:
	var slot : Dictionary = _slots[index]
	var btn  : TextureButton = slot["node"]
	# Restores full size in case this snap-back follows a failed approach/maze
	# attempt (_enter_approach_mode() shrinks the image for the whole journey)
	# — harmless no-op if it never left the bobbing area, already full size.
	btn.size         = Vector2(IMAGE_BOX, IMAGE_BOX)
	btn.pivot_offset = Vector2(IMAGE_BOX, IMAGE_BOX) / 2.0
	btn.position     = slot["base_pos"] - btn.pivot_offset
	_start_bob(index)


# ─── Input ──────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _busy:
		return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed : bool = event.pressed if event is InputEventScreenTouch else \
			(event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		var released : bool = not pressed
		var pos : Vector2 = event.position

		if pressed and _dragging_slot_index == -1:
			var idx : int = _hit_test_slot(pos)
			if idx != -1:
				_dragging_slot_index = idx
				_drag_press_pos      = pos
				_drag_moved_far      = false
				var slot : Dictionary = _slots[idx]
				slot["state"] = ST_DRAG_IN_AREA
				_slots[idx] = slot
				get_viewport().set_input_as_handled()
			return

		if released and _dragging_slot_index != -1:
			_end_drag(pos)
			get_viewport().set_input_as_handled()
			return

	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _dragging_slot_index != -1:
			_update_drag(event.position)
			get_viewport().set_input_as_handled()


func _hit_test_slot(pos: Vector2) -> int:
	for i in range(_slots.size()):
		var slot : Dictionary = _slots[i]
		if slot["state"] != ST_BOBBING:
			continue
		var rect := Rect2(slot["base_pos"] - BOB_AREA_SIZE / 2.0, BOB_AREA_SIZE)
		if rect.has_point(pos):
			return i
	return -1


func _update_drag(pos: Vector2) -> void:
	var idx  : int = _dragging_slot_index
	var slot : Dictionary = _slots[idx]
	var btn  : TextureButton = slot["node"]

	if pos.distance_to(_drag_press_pos) > TAP_MOVE_THRESHOLD:
		_drag_moved_far = true

	if slot["state"] == ST_DRAG_IN_AREA:
		var bob_rect := Rect2(slot["base_pos"] - BOB_AREA_SIZE / 2.0, BOB_AREA_SIZE)
		if bob_rect.has_point(pos):
			# Still exploring inside the bobbing area — follow the finger but
			# no word audio yet, per spec.
			btn.position = pos - btn.pivot_offset
			return
		# Crossed the boundary — reveal this image's approach path.
		_enter_approach_mode(idx, pos)
		return

	if slot["state"] == ST_DRAG_APPROACH:
		_update_approach_drag(idx, pos)
		return

	if slot["state"] == ST_DRAG_MAZE:
		_update_maze_drag(idx, pos)


# Following the revealed approach path — progress is tracked by how far
# along the path the drag has confirmed reaching, not raw distance to "any"
# point on it, since the path loops back over itself (see APPROACH_TOLERANCE
# doc comment above).
func _update_approach_drag(idx: int, pos: Vector2) -> void:
	var slot : Dictionary = _slots[idx]
	var btn  : TextureButton = slot["node"]
	btn.position = pos - btn.pivot_offset

	_move_timer.start()
	if _word_audio_active and not _word_player.playing:
		_word_player.play()

	var window_end : int   = mini(_approach_index + APPROACH_LOOKAHEAD, _approach_points.size() - 1)
	var best_dist  : float = INF
	var best_index : int   = _approach_index
	for i in range(_approach_index, window_end):
		var cp : Vector2 = _closest_point_on_segment(pos, _approach_points[i], _approach_points[i + 1])
		var d  : float   = pos.distance_to(cp)
		if d < best_dist:
			best_dist  = d
			best_index = i

	if best_dist > APPROACH_TOLERANCE:
		_fail_attempt(idx)
		return

	_approach_index = maxi(_approach_index, best_index)

	var last_point : Vector2 = _approach_points[-1]
	if _approach_index >= _approach_points.size() - 2 and pos.distance_to(last_point) <= APPROACH_TOLERANCE:
		_enter_maze_from_approach(idx, pos)


func _update_maze_drag(idx: int, pos: Vector2) -> void:
	var slot : Dictionary = _slots[idx]
	var btn  : TextureButton = slot["node"]

	# The maze sits at one fixed shared position, not centered on any slot,
	# so the image tracks pointer movement relative to the anchor set in
	# _enter_maze_from_approach() rather than jumping straight to the raw
	# pointer position — that keeps it inside the corridor's start cell
	# regardless of exactly where the approach path happened to end.
	var center : Vector2 = _drag_anchor_target + (pos - _drag_anchor_pointer)
	btn.position = center - btn.pivot_offset

	# Word audio is tied to active movement, not the whole attempt: every
	# drag-motion event restarts the "still moving" timer and resumes
	# playback if a prior pause already stopped it. _on_move_stop_timeout()
	# stops playback again once no motion arrives for MOVE_STOP_DELAY.
	_move_timer.start()
	if _word_audio_active and not _word_player.playing:
		_word_player.play()

	if not _maze.is_point_in_corridor(center):
		_fail_attempt(idx)
		return
	if _maze.goal_pos().distance_to(center) <= _maze.cell_size * 0.5:
		_succeed_attempt(idx)


static func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab     : Vector2 = b - a
	var len_sq : float   = ab.length_squared()
	if len_sq == 0.0:
		return a
	var t : float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t


func _end_drag(pos: Vector2) -> void:
	var idx  : int = _dragging_slot_index
	var slot : Dictionary = _slots[idx]

	if slot["state"] == ST_DRAG_IN_AREA:
		# Released without ever leaving the bobbing area.
		if not _drag_moved_far:
			_play_phoneme(idx)
		slot["state"] = ST_BOBBING
		_slots[idx] = slot
		_snap_back(idx)
	elif slot["state"] == ST_DRAG_APPROACH or slot["state"] == ST_DRAG_MAZE:
		# Released before reaching the maze, or mid-maze before the goal.
		_fail_attempt(idx)

	_dragging_slot_index = -1


func _play_phoneme(index: int) -> void:
	var word : Dictionary = _slots[index]["word"]
	var path : String = word.get("phoneme_audio", "")
	if path != "" and ResourceLoader.exists(path):
		_phoneme_player.stream = load(path)
		_phoneme_player.play()


# ─── Maze gameplay ──────────────────────────────────────────────────────────

# Weighted-random style pick, eligible set widening by Group. See
# STYLE_WEIGHTS_BY_GROUP above and maze_generator.gd's style constants.
func _pick_style() -> String:
	var group   : int        = clampi(PrepLevelProgress.main_set_number(), 0, STYLE_WEIGHTS_BY_GROUP.size() - 1)
	var weights : Dictionary = STYLE_WEIGHTS_BY_GROUP[group]
	var total   : float      = 0.0
	for w in weights.values():
		total += w
	var r : float = randf() * total
	for style_id in weights.keys():
		r -= weights[style_id]
		if r <= 0.0:
			return style_id
	return MazeGenerator.STYLE_CURVE


# Crossing the bobbing boundary — the maze is already visible (it appears at
# round start and reshapes after every attempt, see _reshape_maze()), so this
# just builds an approach path from the image to that already-showing maze's
# entry, rather than generating a new maze of its own.
func _enter_approach_mode(index: int, drag_pos: Vector2) -> void:
	var slot : Dictionary = _slots[index]
	_stop_bob(index)
	slot["state"] = ST_DRAG_APPROACH
	_slots[index] = slot

	var btn : TextureButton = slot["node"]
	btn.size         = Vector2(MAZE_DRAG_IMAGE_SIZE, MAZE_DRAG_IMAGE_SIZE)
	btn.pivot_offset = btn.size / 2.0
	btn.position     = drag_pos - btn.pivot_offset

	_approach_points = _generate_approach_path(drag_pos, _maze.start_pos())
	_approach_index  = 0
	_render_approach_path()

	_start_word_audio(index)


# A wandering polyline from the image to the maze entry: one or two small
# loops near the start, then a wide zigzag that never crosses back above the
# image itself (min_y), scaled to actually reach the entry's height by the
# time it settles there.
func _generate_approach_path(image_pos: Vector2, entry_pos: Vector2) -> Array:
	var points  : Array  = [image_pos]
	var min_y   : float   = image_pos.y + 15.0
	var current : Vector2 = image_pos

	var loop_count : int = randi_range(APPROACH_LOOP_MIN, APPROACH_LOOP_MAX)
	for i in range(loop_count):
		var loop_cy     : float   = current.y + randf_range(35.0, 55.0)
		var loop_center : Vector2 = Vector2(current.x + randf_range(-50.0, 50.0), loop_cy)
		var loop_radius : float   = randf_range(30.0, 50.0)
		var steps       : int     = 10
		for s in range(1, steps + 1):
			var angle : float  = (float(s) / steps) * TAU
			var p     : Vector2 = loop_center + Vector2(cos(angle), sin(angle)) * loop_radius
			p.y = maxf(p.y, min_y)
			points.append(p)
		current = points[-1]

	var zigzag_count : int   = randi_range(APPROACH_ZIGZAG_MIN, APPROACH_ZIGZAG_MAX)
	var remaining_dy : float = maxf(entry_pos.y - current.y, 40.0)
	var y_step       : float = remaining_dy / float(zigzag_count + 1)
	var going_right  : bool  = current.x < (APPROACH_ZIGZAG_LEFT_X + APPROACH_ZIGZAG_RIGHT_X) * 0.5
	for i in range(zigzag_count):
		var target_x : float = APPROACH_ZIGZAG_RIGHT_X if going_right else APPROACH_ZIGZAG_LEFT_X
		current = Vector2(target_x, current.y + y_step)
		points.append(current)
		going_right = not going_right

	points.append(entry_pos)
	return points


# Dashed rather than one continuous Line2D — Godot's Line2D has no native
# dash pattern, so this walks the polyline by arc length and emits a
# separate short Line2D per "on" stretch, skipping the "off" gaps.
func _render_approach_path() -> void:
	for c in _approach_container.get_children():
		c.queue_free()
	if _approach_points.size() < 2:
		return

	var dash_on        : bool  = true
	var dash_remaining  : float = APPROACH_DASH_LEN
	var current_dash    : Line2D = null

	for i in range(_approach_points.size() - 1):
		var a : Vector2 = _approach_points[i]
		var b : Vector2 = _approach_points[i + 1]
		var seg_len : float = a.distance_to(b)
		if seg_len <= 0.0:
			continue
		var traveled : float = 0.0
		while traveled < seg_len:
			var step : float = minf(dash_remaining, seg_len - traveled)
			var p1 : Vector2 = a.lerp(b, traveled / seg_len)
			var p2 : Vector2 = a.lerp(b, (traveled + step) / seg_len)
			if dash_on:
				if current_dash == null:
					current_dash = _new_dash_segment()
					current_dash.add_point(p1)
				current_dash.add_point(p2)
			traveled        += step
			dash_remaining  -= step
			if dash_remaining <= 0.0:
				dash_on = not dash_on
				dash_remaining = APPROACH_DASH_LEN if dash_on else APPROACH_GAP_LEN
				if not dash_on:
					current_dash = null


func _new_dash_segment() -> Line2D:
	var line := Line2D.new()
	line.width          = ROUTE_WIDTH
	line.default_color  = ROUTE_COLOR
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode   = Line2D.LINE_CAP_ROUND
	_approach_container.add_child(line)
	return line


func _clear_approach_path() -> void:
	_approach_points = []
	_approach_index  = 0
	for c in _approach_container.get_children():
		c.queue_free()


# The image has followed the approach path all the way to the maze entry —
# only the purple approach line disappears here; the maze itself has already
# been visible (with no line of its own) since the round started.
func _enter_maze_from_approach(index: int, drag_pos: Vector2) -> void:
	var slot : Dictionary = _slots[index]
	slot["state"] = ST_DRAG_MAZE
	_slots[index] = slot

	_clear_approach_path()

	# Anchor the image to the maze's actual start cell rather than the raw
	# arrival point — see _update_maze_drag(), which maps further pointer
	# motion relative to this anchor.
	_drag_anchor_pointer = drag_pos
	_drag_anchor_target  = _maze.start_pos()

	var btn : TextureButton = slot["node"]
	btn.position = _drag_anchor_target - btn.pivot_offset


func _render_maze() -> void:
	for c in _maze_container.get_children():
		c.queue_free()
	if _maze == null:
		return

	for seg in _maze.wall_segments():
		var line := Line2D.new()
		line.width           = MAZE_WALL_WIDTH
		line.default_color   = WALL_COLOR
		line.begin_cap_mode  = Line2D.LINE_CAP_ROUND
		line.end_cap_mode    = Line2D.LINE_CAP_ROUND
		line.add_point(seg[0])
		line.add_point(seg[1])
		_maze_container.add_child(line)

	var goal := ColorRect.new()
	goal.color    = AMBER
	goal.size     = Vector2(GOAL_MARKER_R, GOAL_MARKER_R) * 2.0
	goal.position = _maze.goal_pos() - goal.size / 2.0
	goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_maze_container.add_child(goal)


# The maze stays visible continuously for the whole round rather than
# hiding and reappearing between attempts — this generates a fresh layout
# and redraws in place. Called once at round start, then again after every
# attempt resolves (fail or success) so the next attempt always gets its
# own fresh shape, matching "every attempt generates a new maze" without
# ever actually hiding the maze itself.
func _reshape_maze() -> void:
	_maze = MazeGenerator.generate(MAZE_COLS, MAZE_ROWS, MAZE_CELL_SIZE, MAZE_ORIGIN,
		_pick_style(), MAZE_START_CELL, MAZE_COLS - 1)
	_render_maze()


func _start_word_audio(index: int) -> void:
	var word : Dictionary = _slots[index]["word"]
	var path : String = word.get("word_audio", "")
	_word_audio_active = false
	if path != "" and ResourceLoader.exists(path):
		_word_player.stream = load(path)
		_word_audio_active = true
		_word_player.play()


func _stop_word_audio() -> void:
	_word_audio_active = false
	_move_timer.stop()
	if _word_player.playing:
		_word_player.stop()


func _on_word_player_finished() -> void:
	if _word_audio_active:
		_word_player.play()


# No drag-motion event arrived within MOVE_STOP_DELAY — the child is holding
# still mid-maze (not released, just paused). Pause the word audio; it
# resumes the instant _update_drag() sees movement again.
func _on_move_stop_timeout() -> void:
	if _word_player.playing:
		_word_player.stop()


func _fail_attempt(index: int) -> void:
	_stop_word_audio()
	_fail_player.play()
	_reshape_maze()
	_clear_approach_path()
	var slot : Dictionary = _slots[index]
	slot["state"] = ST_BOBBING
	_slots[index] = slot
	_snap_back(index)
	if _dragging_slot_index == index:
		_dragging_slot_index = -1


func _succeed_attempt(index: int) -> void:
	_stop_word_audio()
	_success_player.play()
	_reshape_maze()
	if _dragging_slot_index == index:
		_dragging_slot_index = -1

	var slot : Dictionary = _slots[index]
	var btn  : TextureButton = slot["node"]
	var word : Dictionary = slot["word"]
	slot["state"] = ST_EMPTY
	slot["word"]  = {}
	slot["node"]  = null
	_slots[index] = slot
	_quest_done_words += 1
	_group_mastered.append(word)

	# Hand this image off to the completed row instead of fading it away —
	# it stays visible there as a record for the rest of the round. The slot
	# itself stays empty until the whole round finishes (_check_round_complete).
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_completed_row_nodes.append(btn)
	var target_center : Vector2 = _completed_row_slot_pos(_completed_this_round)
	_completed_this_round += 1

	var move := create_tween()
	move.set_parallel(true)
	move.tween_property(btn, "position", target_center - Vector2(COMPLETED_THUMB_SIZE, COMPLETED_THUMB_SIZE) * 0.5, COMPLETED_MOVE_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move.tween_property(btn, "size", Vector2(COMPLETED_THUMB_SIZE, COMPLETED_THUMB_SIZE), COMPLETED_MOVE_DUR)
	await move.finished

	_check_round_complete()


func _clear_maze() -> void:
	_maze = null
	for c in _maze_container.get_children():
		c.queue_free()


# ─── Quest Transition — decorative only ─────────────────────────────────────
# The Play Button character hops through its own independent maze between
# Quests 1->2->3->4. This maze is never played by the child and never shares
# state with the gameplay maze/collision above — it exists purely so the
# child sees the Play Button "finish" something each time a Quest ends, same
# spirit as the cube-dance beat between Prep sub-sets.

const QT_MAZE_COLS        : int   = 4
const QT_MAZE_ROWS         : int   = 3
const QT_CELL_SIZE         : float = 60.0
const QT_HOP_DUR           : float = 0.22
const QT_PLAY_BUTTON_SIZE  : float = 70.0

func _play_quest_transition() -> void:
	_busy = true
	_start_music()

	var maze_size : Vector2 = Vector2(QT_MAZE_COLS, QT_MAZE_ROWS) * QT_CELL_SIZE
	var origin    : Vector2 = Vector2(640, 380) - maze_size / 2.0
	var deco_maze = MazeGenerator.generate(QT_MAZE_COLS, QT_MAZE_ROWS, QT_CELL_SIZE, origin)

	var deco_container := Node2D.new()
	add_child(deco_container)
	for seg in deco_maze.wall_segments():
		var line := Line2D.new()
		line.width           = MAZE_WALL_WIDTH
		line.default_color   = WALL_COLOR
		line.begin_cap_mode  = Line2D.LINE_CAP_ROUND
		line.end_cap_mode    = Line2D.LINE_CAP_ROUND
		line.add_point(seg[0])
		line.add_point(seg[1])
		deco_container.add_child(line)

	var play_button := TextureButton.new()
	play_button.ignore_texture_size = true
	play_button.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	play_button.size                = Vector2(QT_PLAY_BUTTON_SIZE, QT_PLAY_BUTTON_SIZE)
	play_button.pivot_offset        = play_button.size / 2.0
	play_button.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://UI_assets/playbutton.png"):
		play_button.texture_normal = load("res://UI_assets/playbutton.png")
	play_button.position   = deco_maze.start_pos() - play_button.pivot_offset
	play_button.modulate.a = 0.0
	deco_container.add_child(play_button)

	var enter := create_tween()
	enter.tween_property(play_button, "modulate:a", 1.0, 0.25)
	await enter.finished

	for cell in deco_maze.path_cells:
		var target : Vector2 = deco_maze.cell_center(cell) - play_button.pivot_offset
		var hop := create_tween()
		hop.set_parallel(true)
		hop.tween_property(play_button, "position", target, QT_HOP_DUR) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		hop.tween_property(play_button, "scale", Vector2(1.15, 0.85), QT_HOP_DUR * 0.5)
		await hop.finished
		var settle := create_tween()
		settle.tween_property(play_button, "scale", Vector2(1.0, 1.0), QT_HOP_DUR * 0.5)
		await settle.finished

	# Celebration hop at the goal.
	for _b in range(3):
		var up := create_tween()
		up.tween_property(play_button, "position:y", play_button.position.y - 18.0, 0.15).set_ease(Tween.EASE_OUT)
		await up.finished
		var down := create_tween()
		down.tween_property(play_button, "position:y", play_button.position.y + 18.0, 0.15).set_ease(Tween.EASE_IN)
		await down.finished

	var ext := create_tween()
	ext.set_parallel(true)
	ext.tween_property(play_button, "modulate:a", 0.0, 0.25)
	ext.tween_property(deco_container, "modulate:a", 0.0, 0.25)
	await ext.finished

	deco_container.queue_free()
	await _stop_music()
	_busy = false
	_start_quest()


# ─── Group complete — hand back to normal Prep progression ─────────────────
# Mirrors prep_transition.gd's _continue_to_next_set() exactly (has_next()
# BEFORE advance() — CLAUDE.md locked rule #3). Duplicated locally rather than
# calling into prep_transition.gd since that logic lives on a scene this
# scene doesn't instance; SoundQuestState intentionally carries no such
# helper either, per the plan's "no new SaveManager fields" persistence note.
func _on_all_quests_complete() -> void:
	_busy = true
	await _stop_music()
	if PrepLevelProgress.has_next():
		PrepLevelProgress.advance()
		get_tree().change_scene_to_file("res://prep_game.tscn")
	else:
		SaveManager.set_prep_completed()
		PrepLevelProgress.reset()
		LevelTransition.next_level_id = "level1"
		LevelTransition.level_name    = "Level 1"
		get_tree().change_scene_to_file("res://level_transition.tscn")
