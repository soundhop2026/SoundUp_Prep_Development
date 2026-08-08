extends Node2D

# ─── Sound Quest ────────────────────────────────────────────────────────────
# Mastery activity (not a teaching activity) shown once per Prep Group, right
# after that Group's last sub-set finishes (see prep_transition.gd's
# is_main_set_boundary() branch). Reached via SoundQuestState's handoff.
#
# 4 words visible at once in a row across the top, sitting still (no idle
# animation). Tap = hear the phoneme (unlimited, exploration only). A maze
# is already on screen the instant the round starts — ready and waiting
# before any image is even touched, entry visible as a gap in its top wall.
# Press-and-drag past the bobbing area's boundary begins a two-phase
# attempt, and this specific attempt gets its own fresh maze the same
# instant (replacing whatever was showing):
#
#  1. Approach — free drag, no guide line at all: the maze (and its entry
#     gap) is already fully visible, so the child just drags the image
#     straight to it. Reaching the entry locks into the maze; releasing
#     before then fails the attempt.
#  2. Maze — one entry, one exit, everywhere else on its boundary sealed,
#     with no visible line inside at all — pure hard-wall navigation by
#     feel. Reaching the goal marks the word mastered.
#
# The maze reshapes fresh per attempt (_reshape_maze()) — a retry after a
# fail, or the next image's turn, each get their own new layout — but the
# maze itself is never actually hidden once a round has started; a resolved
# attempt just leaves it showing its last shape until the next selection
# swaps it. Failed words stay in the same visible slot for immediate
# retry — never requeued.
#
# Words are grouped into Quest Rounds of exactly 4 — the whole round has to
# finish (all 4 mastered) before the next round of 4 begins; nothing refills
# individually mid-round. Each mastered image moves to a horizontal row on
# the right instead of disappearing, staying visible there until the round
# ends.
#
# A Quest's round COUNT equals its own word count (a 14-word Quest runs 14
# rounds), and every round draws its 4 words at random from that SAME fixed
# pool — words repeating across rounds is the whole point, not a fallback:
# frequent repeated exposure to a small set of words is the actual mastery
# mechanic here (see _pick_round_words()). The only constraint on the draw
# is that a round never repeats the exact same word from the round
# immediately before it (when the pool is large enough to allow that), so
# two consecutive rounds never show an identical picture back to back.
#
# 4 Quests per Group; Quest Transition is a purely decorative Play-Button-
# walks-a-maze celebration between them. After Quest 4, hands back to normal
# Prep progression exactly like prep_transition.gd's _continue_to_next_set().
# ─────────────────────────────────────────────────────────────────────────────

const FONT_PATH : String = "res://UI_assets/210 연필스케치R.ttf"
const MUSIC_PATH : String = "res://soundquest/assets/quest_preplevel_bgm.mp3"

const BG_COLOR     : Color = Color("#A8E063")   # same baby-green as Prep
const PURPLE       : Color = Color("#4B0082")
const WHITE        : Color = Color("#FFFFFF")
const WALL_COLOR   : Color = Color("#2E2E2E")   # thick hand-drawn-style wall lines

# 4 fixed slot centers in a single row across the top, feeding down into the
# one shared maze near the bottom via each image's own approach path.
const SLOT_POSITIONS : Array[Vector2] = [
	Vector2(195, 180),
	Vector2(493, 180),
	Vector2(792, 180),
	Vector2(1090, 180),
]

const IMAGE_BOX     : float = 150.0    # word image fits within this box
# The dragged image shrinks for the whole journey through the maze — at the
# full 150px IMAGE_BOX it would blanket most of a 65px-cell corridor. Half
# of IMAGE_BOX, not smaller — small enough to fit the corridor, still large
# enough that the child can tell what word it still is.
const MAZE_DRAG_IMAGE_SIZE : float = IMAGE_BOX * 0.5
const BOB_AREA_SIZE : Vector2 = Vector2(190, 190)   # boundary the drag must cross

const TAP_MOVE_THRESHOLD : float = 14.0   # px — below this, a release counts as a tap

# One shared maze for every image and every Group — difficulty is carried by
# route STYLE (see STYLE_WEIGHTS_BY_GROUP below), not by growing the box.
# A wide, tall band near the bottom of the screen, well clear of the top
# image row (which ends around y=255) and the completed row to its right.
# Sealed on every side except one entry (top edge — the 4 images sit above
# the maze, so an approach path coming down from any of them reaches this
# directly without having to curve around the maze's own boundary the way
# a side entry would force it to) and one exit (right edge, feeding the
# completed row) — see maze_generator.gd's wall_segments().
const MAZE_COLS       : int      = 12
const MAZE_ROWS        : int      = 4
const MAZE_CELL_SIZE   : float    = 65.0
const MAZE_ORIGIN      : Vector2  = Vector2(60, 420)
const MAZE_START_CELL  : Vector2i = Vector2i(6, 0)   # the maze's one shared entry, top edge
const MAZE_WALL_WIDTH  : float = 6.0

# Success doesn't fire the instant the drag reaches the goal cell — the
# child has to actually pull the image out through the exit and slightly
# past the maze's boundary. EXIT_ZONE_DEPTH is how far past that boundary
# still counts as "still exiting" (movement allowed, past it the drag is
# blocked same as any other wall — see _on_blocked()); EXIT_SUCCESS_
# THRESHOLD (smaller, well inside that depth) is how far past it actually
# has to go before success triggers. EXIT_ZONE_Y_TOLERANCE forgives
# imprecise vertical alignment with the exit row.
const EXIT_ZONE_DEPTH        : float = 60.0
const EXIT_ZONE_Y_TOLERANCE  : float = 30.0
const EXIT_SUCCESS_THRESHOLD : float = 25.0

# Hitting a wall never resets the attempt — just a gentle bounce, debounced
# so it doesn't spam every single frame while the drag is pressed against
# one spot.
const BLOCKED_FEEDBACK_COOLDOWN : float = 0.35

const MOVE_STOP_DELAY : float = 0.18   # no drag-motion event within this window = "stopped"

# No guide line — the maze (and its entry) is already fully visible, so the
# child just free-drags the image toward it. This is how close the drag has
# to get to the entry cell's center to lock into the maze.
const APPROACH_ENTRY_RADIUS : float = 45.0

# Pointed-hand guides at the maze's entry and exit gaps — same asset/scale as
# prep_game.gd's PointedHand. Entry hovers up-left of the entry gap, index
# finger reaching down-right into it, and vanishes the instant a real drag
# toward the maze begins (its job — "here's where to start" — is done once
# the child is actually underway). Exit hovers down-right of the exit gap,
# finger reaching up-left into it, and stays up longer, since finding the
# exit is the actual challenge — it only vanishes once the drag actually
# arrives at the goal cell (see _update_maze_drag()), not on release/success.
#
# Rotation values are computed, not eyeballed: the asset's own fingertip
# (the topmost drawn pixel at rotation 0) sits at a measured angle of
# -121.91 degrees from the texture's center (Godot screen convention: 0=east,
# 90=south). Target direction minus that base angle gives the rotation that
# actually points the finger the intended way — verified by rendering the
# computed rotation and confirming the fingertip lands where expected.
const HAND_TEXTURE_PATH : String  = "res://UI_assets/handsigns/pointed.png"
const HAND_SCALE         : Vector2 = Vector2(0.08, 0.08)
const ENTRY_HAND_ROTATION_DEG : float = 167.0    # finger points southeast (down-right)
const EXIT_HAND_ROTATION_DEG  : float = 90.0
const ENTRY_HAND_OFFSET : Vector2 = Vector2(-35, -40)   # up-left of the entry gap
const EXIT_HAND_OFFSET  : Vector2 = Vector2(50, 0)      # vertically centered on the exit gap, held a bit off to the side — same distance-from-gap feel as the entry hand

# A Quest Round is always exactly 4 images, drawn at random from the
# Quest's own fixed pool every time (see _pick_round_words()) — never a
# partial round. All 4 of a round's images must exit before the next round
# begins.
const ROUND_SIZE : int = 4

# Completed images from the current round move here — a simple horizontal
# row, capped at ROUND_SIZE since a round is never bigger than 4. Positioned
# just past the maze's exit so it reads as "this is where the maze leads."
# Clears at the start of every new round.
#
# Start X pushed out (900 -> 960) and spacing tightened (90/70 -> 80/65) so
# the row clears the exit hand: the maze's right edge is at x=840
# (MAZE_ORIGIN.x + MAZE_COLS*MAZE_CELL_SIZE) and EXIT_HAND_OFFSET puts the
# hand's center around x=890 with ~72px width, spanning roughly x:854-926 —
# the old start_x=900 sat right inside that span, visually overlapping the
# hand with whichever image had just exited.
const COMPLETED_ROW_Y       : float = 600.0
const COMPLETED_ROW_START_X : float = 960.0
const COMPLETED_ROW_STEP    : float = 80.0
const COMPLETED_THUMB_SIZE  : float = 65.0
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
const ST_DRAG_APPROACH : String = "drag_approach"   # free-dragging toward the already-visible maze entry
const ST_DRAG_MAZE     : String = "drag_maze"


var _font : Font = null

var _quests        : Array = []   # Array[Array[Dictionary]] — 4 quests of {image, word_audio, phoneme_audio}
var _quest_index    : int   = 0
var _quest_pool        : Array = []   # this Quest's fixed word set — re-sampled every round, never consumed
var _quest_round_count : int   = 0    # target round count for this Quest == its own word count
var _quest_rounds_done : int   = 0
var _prev_round_words  : Array = []   # last round's 4 picks, excluded from the next draw when possible

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
var _maze_current_cell : Vector2i = Vector2i.ZERO   # which maze cell the drag currently occupies
var _entry_hand : Sprite2D = null
var _exit_hand  : Sprite2D = null

var _phoneme_player : AudioStreamPlayer = null
var _word_player     : AudioStreamPlayer = null
var _success_player  : AudioStreamPlayer = null
var _music_player     : AudioStreamPlayer = null

var _word_audio_active : bool = false   # guards the manual play->finished->replay loop
var _move_timer : Timer = null   # word audio pauses when no drag-motion arrives within MOVE_STOP_DELAY
var _last_blocked_time : float = -1000.0   # debounces the wall-bump feedback, see _on_blocked()

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
	_entry_hand = _make_hand_sprite(ENTRY_HAND_ROTATION_DEG)
	_exit_hand  = _make_hand_sprite(EXIT_HAND_ROTATION_DEG)
	add_child(_entry_hand)
	add_child(_exit_hand)

	var pool : Array = SoundQuestState.build_word_pool(
		PrepLevelProgress.sets.slice(SoundQuestState.group_start_index, SoundQuestState.group_end_index + 1))
	_quests = SoundQuestState.split_into_quests(pool)

	_quest_index = 0
	if SoundQuestState.debug_skip_to_transition:
		SoundQuestState.debug_skip_to_transition = false
		# _quest_rounds_done and _quest_round_count are both still 0 at this
		# point (never populated yet), so 0 >= 0 routes straight into the
		# Quest Transition celebration the same way a real Quest 1 completion
		# would, then continues normally into Quest 2 afterward.
		_start_round_or_finish()
	else:
		_start_quest()


func _build_audio_players() -> void:
	_phoneme_player = AudioStreamPlayer.new()
	_word_player     = AudioStreamPlayer.new()
	_success_player  = AudioStreamPlayer.new()
	add_child(_phoneme_player)
	add_child(_word_player)
	add_child(_success_player)

	if ResourceLoader.exists("res://BGM&effect/SoundUp_feedback/gayageum_correct.wav"):
		_success_player.stream = load("res://BGM&effect/SoundUp_feedback/gayageum_correct.wav")

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

	_quest_pool        = words
	_quest_round_count = words.size()
	_quest_rounds_done = 0
	_prev_round_words  = []

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


# Starts the next Quest Round, or — if this Quest has already run its target
# number of rounds — ends the Quest and moves to Quest Transition.
func _start_round_or_finish() -> void:
	if _quest_rounds_done >= _quest_round_count:
		_clear_completed_row()
		_clear_maze()
		_quest_index += 1
		_play_quest_transition()
		return
	_start_round()


# Draws ROUND_SIZE (4) words for this round.
func _start_round() -> void:
	_clear_completed_row()
	# A maze is ready and visible the moment the round starts, before any
	# image is touched — _enter_approach_mode() still generates this
	# attempt's own fresh maze the instant an image is actually selected
	# (replacing this placeholder one), and _fail_attempt()/_succeed_attempt()
	# still hide it once that attempt resolves — this only changes what's on
	# screen during the gap before the very first selection of the round.
	_reshape_maze()
	_show_entry_hand()

	var round_words : Array = _pick_round_words()
	_prev_round_words = round_words

	for i in range(ROUND_SIZE):
		_place_word_in_slot(i, round_words[i])


# Draws ROUND_SIZE words at random from the Quest's own fixed pool — words
# repeating across rounds is the point (frequent exposure to a small set is
# the actual mastery mechanic), not a fallback. The only constraint: avoid
# repeating the exact same word from the immediately preceding round, so two
# consecutive rounds never show an identical picture back to back. Falls
# back to allowing that repeat only if the pool is too small to exclude
# _prev_round_words and still have ROUND_SIZE candidates left (not possible
# with the current word bank — every Quest has well over ROUND_SIZE words —
# but kept as graceful degradation rather than a crash if content ever gets
# sparser).
func _pick_round_words() -> Array:
	var pool : Array = _quest_pool.duplicate()
	if pool.size() > ROUND_SIZE and not _prev_round_words.is_empty():
		var prev_images : Dictionary = {}
		for w in _prev_round_words:
			prev_images[w.get("image", "")] = true
		var filtered : Array = []
		for w in pool:
			if not prev_images.has(w.get("image", "")):
				filtered.append(w)
		if filtered.size() >= ROUND_SIZE:
			pool = filtered
	pool.shuffle()
	return pool.slice(0, ROUND_SIZE)


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


func _all_slots_empty() -> bool:
	for slot in _slots:
		if slot["state"] != ST_EMPTY:
			return false
	return true


# All 4 of the current round's slots are empty (every image has exited) —
# hold the completed row on screen for a beat, then start the next round or
# finish the Quest.
func _check_round_complete() -> void:
	if _all_slots_empty():
		_quest_rounds_done += 1
		_on_round_complete()


func _on_round_complete() -> void:
	await get_tree().create_timer(ROUND_COMPLETE_BEAT).timeout
	_start_round_or_finish()


# ─── Idle state ─────────────────────────────────────────────────────────────
# The 4 top images sit still — no idle animation. Function/state name (and
# the "bob_tween" dict key, always null now) kept as-is since ST_BOBBING is
# the state the rest of the state machine (_hit_test_slot() etc.) checks for
# "this slot holds an untouched, draggable image."
func _start_bob(index: int) -> void:
	var slot : Dictionary = _slots[index]
	var btn  : TextureButton = slot["node"]
	if slot["bob_tween"] != null:
		slot["bob_tween"].kill()
		slot["bob_tween"] = null
	btn.position  = slot["base_pos"] - btn.pivot_offset
	slot["state"] = ST_BOBBING
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


# Free drag toward the already-visible maze entry — no guide line, no fail
# condition here at all (releasing early is what _end_drag() treats as a
# fail). The image just follows the finger until it gets close enough to
# the entry cell to lock into the maze.
func _update_approach_drag(idx: int, pos: Vector2) -> void:
	var slot : Dictionary = _slots[idx]
	var btn  : TextureButton = slot["node"]
	btn.position = pos - btn.pivot_offset

	_move_timer.start()
	if _word_audio_active and not _word_player.playing:
		_word_player.play()

	if pos.distance_to(_maze.start_pos()) <= APPROACH_ENTRY_RADIUS:
		_enter_maze_from_approach(idx, pos)


# This is a discovery activity, not an assessment: hitting a wall never
# resets the image back to the start, and never fully halts the drag either
# — a move that's blocked diagonally still slides along whichever single
# axis (X or Y) is still open, the same "slide along the wall" approach
# most top-down games use, so trying a different direction keeps feeling
# responsive instead of getting stuck until the child retraces back to
# exactly where they were. Only a move blocked on BOTH axes at once holds
# still (with a gentle bounce) for that one frame. The maze is a spanning
# tree with exactly one route, so persistence always finds it eventually.
# Only actually letting go (_end_drag()) ends the attempt.
func _update_maze_drag(idx: int, pos: Vector2) -> void:
	var slot : Dictionary = _slots[idx]
	var btn  : TextureButton = slot["node"]

	var current  : Vector2 = btn.position + btn.pivot_offset
	# The maze sits at one fixed shared position, not centered on any slot,
	# so the proposed move tracks pointer movement relative to the anchor
	# set below rather than jumping straight to the raw pointer position.
	var proposed : Vector2 = _drag_anchor_target + (pos - _drag_anchor_pointer)

	# Word audio is tied to active movement, not the whole attempt: every
	# drag-motion event restarts the "still moving" timer and resumes
	# playback if a prior pause already stopped it. _on_move_stop_timeout()
	# stops playback again once no motion arrives for MOVE_STOP_DELAY.
	_move_timer.start()
	if _word_audio_active and not _word_player.playing:
		_word_player.play()

	var resolved : Vector2 = current
	if _maze_point_valid(proposed):
		resolved = proposed
	else:
		var x_only : Vector2 = Vector2(proposed.x, current.y)
		var y_only : Vector2 = Vector2(current.x, proposed.y)
		if _maze_point_valid(x_only):
			resolved = x_only
		elif _maze_point_valid(y_only):
			resolved = y_only
		else:
			_on_blocked(idx)

	btn.position = resolved - btn.pivot_offset
	# Re-anchor every frame (not just when blocked) so the anchor always
	# reflects exactly where the image is right now — recovery from a
	# blocked moment is then immediate and precise on the very next frame.
	_drag_anchor_pointer = pos
	_drag_anchor_target  = resolved

	# Track which cell the drag actually occupies now, so the NEXT frame's
	# _maze_point_valid() check compares against the correct starting cell.
	# Skip this once inside the exit zone — points out there aren't a real
	# maze cell, and the drag is past needing this check anyway.
	if not _maze_exit_zone().has_point(resolved):
		_maze_current_cell = _maze.cell_at(resolved)
		# Arrived at the goal cell for the first time this attempt — the exit
		# hand's job ("here's where to head") is done; actually pulling the
		# image out through the exit is the remaining action.
		if _maze_current_cell == _maze.goal_cell:
			_hide_exit_hand()

	var goal_rect  : Rect2 = _maze.cell_rect(_maze.goal_cell)
	var boundary_x : float = goal_rect.position.x + goal_rect.size.x
	if resolved.x >= boundary_x + EXIT_SUCCESS_THRESHOLD and _maze_exit_zone().has_point(resolved):
		_succeed_attempt(idx)


func _maze_exit_zone() -> Rect2:
	var goal_rect  : Rect2 = _maze.cell_rect(_maze.goal_cell)
	var boundary_x : float = goal_rect.position.x + goal_rect.size.x
	return Rect2(
		boundary_x, goal_rect.position.y - EXIT_ZONE_Y_TOLERANCE,
		EXIT_ZONE_DEPTH, goal_rect.size.y + EXIT_ZONE_Y_TOLERANCE * 2.0)


# Cell-based, not rect-union: adjacent cells' rects always touch regardless
# of wall state, so a plain "is this point inside a visited cell" test can't
# tell a real dead end (freely explorable) apart from crossing a genuinely
# closed wall (must block). Instead, only allow moving from the cell the
# drag currently occupies (_maze_current_cell) into an adjacent cell when
# that specific connecting wall is actually open. Wandering into a dead end
# is real exploration, not a wall — only an actually closed wall segment
# should ever block the drag. The maze challenge is navigation, not
# punishment.
func _maze_point_valid(p: Vector2) -> bool:
	if _maze_exit_zone().has_point(p):
		return true
	var cell : Vector2i = _maze.cell_at(p)
	return _maze.can_move_between(_maze_current_cell, cell)


# Debounced so it doesn't spam while genuinely pinned in a corner (blocked
# on both axes at once) — a gentle bounce, nothing punishing, no reset.
func _on_blocked(idx: int) -> void:
	var now : float = Time.get_ticks_msec() / 1000.0
	if now - _last_blocked_time < BLOCKED_FEEDBACK_COOLDOWN:
		return
	_last_blocked_time = now

	var slot : Dictionary = _slots[idx]
	var btn  : TextureButton = slot["node"]
	var bump := create_tween()
	bump.tween_property(btn, "scale", Vector2(0.85, 0.85), 0.08)
	bump.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)


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


# Crossing the bobbing boundary — this attempt's maze reshapes immediately
# (_reshape_maze()), so the child can see the destination the moment they
# start dragging. Each attempt (this image's first try, a retry after a
# fail, or the next image's turn) gets its own fresh maze — but the maze
# itself, once a round has started, is never actually hidden; it just keeps
# swapping shape.
func _enter_approach_mode(index: int, drag_pos: Vector2) -> void:
	var slot : Dictionary = _slots[index]
	_stop_bob(index)
	slot["state"] = ST_DRAG_APPROACH
	_slots[index] = slot

	# The child is actually underway now — the entry hand's job is done.
	_hide_entry_hand()

	# Stays full size for the whole free drag toward the maze — no rush, and
	# the word stays fully recognizable while it's still just finding its
	# way to the entrance. Only shrinks once it actually enters the maze,
	# see _enter_maze_from_approach().
	var btn : TextureButton = slot["node"]
	btn.position = drag_pos - btn.pivot_offset

	_reshape_maze()

	_start_word_audio(index)


# The image has been dragged to the maze entry — lock into maze navigation,
# shrinking now so it fits the corridor without blanketing it.
func _enter_maze_from_approach(index: int, drag_pos: Vector2) -> void:
	var slot : Dictionary = _slots[index]
	slot["state"] = ST_DRAG_MAZE
	_slots[index] = slot

	var btn : TextureButton = slot["node"]
	btn.size         = Vector2(MAZE_DRAG_IMAGE_SIZE, MAZE_DRAG_IMAGE_SIZE)
	btn.pivot_offset = btn.size / 2.0

	# Anchor the image to the maze's actual start cell rather than the raw
	# arrival point — see _update_maze_drag(), which maps further pointer
	# motion relative to this anchor.
	_drag_anchor_pointer = drag_pos
	_drag_anchor_target  = _maze.start_pos()
	_maze_current_cell   = _maze.start_cell

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

	# No goal marker drawn — the exit hand itself points to the target now,
	# so a separate amber square would be redundant clutter right next to it.

	# The exit hand reappears fresh with every new maze, regardless of
	# whether the previous attempt's hand had already been hidden on
	# arrival — a new attempt means a new (possibly relocated) exit to find.
	_show_exit_hand()


func _make_hand_sprite(rotation_deg: float) -> Sprite2D:
	var hand := Sprite2D.new()
	if ResourceLoader.exists(HAND_TEXTURE_PATH):
		hand.texture = load(HAND_TEXTURE_PATH)
	hand.scale             = HAND_SCALE
	hand.rotation_degrees  = rotation_deg
	hand.z_index           = 5
	hand.visible           = false
	return hand


# Midpoint of the actual missing wall segment (the door), not the cell
# center, so the hand points at the real opening.
func _entry_gap_pos() -> Vector2:
	return Vector2(_maze.cell_center(_maze.start_cell).x, _maze.origin.y)


func _exit_gap_pos() -> Vector2:
	return Vector2(_maze.origin.x + _maze.cols * _maze.cell_size, _maze.cell_center(_maze.goal_cell).y)


func _show_entry_hand() -> void:
	if _maze == null:
		return
	_entry_hand.position = _entry_gap_pos() + ENTRY_HAND_OFFSET
	_entry_hand.visible  = true


func _hide_entry_hand() -> void:
	_entry_hand.visible = false


func _show_exit_hand() -> void:
	if _maze == null:
		return
	_exit_hand.position = _exit_gap_pos() + EXIT_HAND_OFFSET
	_exit_hand.visible  = true


func _hide_exit_hand() -> void:
	_exit_hand.visible = false


# Generates a fresh maze layout and shows it immediately. Called once per
# attempt, right when that attempt's approach path also reveals
# (_enter_approach_mode()) — every attempt (a fresh word, a retry, or the
# next image's turn) gets its own maze, matching "every attempt generates
# a new maze."
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
	# No "oops try again" cue — this is a discovery activity, not an
	# assessment. The maze itself is left showing its current shape rather
	# than hidden — it never disappears once a round has started. The next
	# selection (a retry of this same image, or a different one) reshapes it
	# fresh via _enter_approach_mode()'s _reshape_maze() call.
	var slot : Dictionary = _slots[index]
	slot["state"] = ST_BOBBING
	_slots[index] = slot
	_snap_back(index)
	if _dragging_slot_index == index:
		_dragging_slot_index = -1
	# Back to idle — the entry hand's guidance is relevant again.
	_show_entry_hand()


func _succeed_attempt(index: int) -> void:
	_stop_word_audio()
	_success_player.play()
	# Same as _fail_attempt() — the maze stays visible in its current shape;
	# the next selection reshapes it.
	if _dragging_slot_index == index:
		_dragging_slot_index = -1

	var slot : Dictionary = _slots[index]
	var btn  : TextureButton = slot["node"]
	slot["state"] = ST_EMPTY
	slot["word"]  = {}
	slot["node"]  = null
	_slots[index] = slot

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

	# Only reshow if the round is still going — if this was the round's last
	# image, leave it hidden rather than flashing it briefly before the
	# round-complete beat/transition takes over.
	if not _all_slots_empty():
		_show_entry_hand()

	_check_round_complete()


func _clear_maze() -> void:
	_maze = null
	for c in _maze_container.get_children():
		c.queue_free()
	_hide_entry_hand()
	_hide_exit_hand()


# ─── Quest Transition — decorative only ─────────────────────────────────────
# The Play Button character hops through its own independent maze between
# Quests 1->2->3->4. This maze is never played by the child and never shares
# state with the gameplay maze/collision above — it exists purely so the
# child sees the Play Button "finish" something each time a Quest ends, same
# spirit as the cube-dance beat between Prep sub-sets.
#
# Six beats, in order:
#   1. Play Button appears large/noticeable at the top of the screen, bobs
#      in place (QT_TOP_BOB_DUR).
#   2. Traces the maze's outline down to its entrance (QT_DESCEND_DUR
#      total): 2 clean jumps (see _qt_dramatic_hop()) land it above the
#      roof then clear of the corner, then it WALKS the rest of the way in
#      (see _qt_walk()) — straight down along the outside of the west
#      wall first, then straight across into the entrance, never
#      diagonally, and no more hopping once it's past the corner. Shrinks
#      to corridor size right as it arrives. Position-only throughout (no
#      swirl or squash/stretch) so it never visually clips through a
#      nearby wall or loses its shape.
#   3/4. Wanders the maze like a kid exploring — ducking into a dead-end
#      branch here and there, occasionally banging into a wall and bouncing
#      back (see _qt_bump()), not a beeline — before finally landing on the
#      real path through to the goal (QT_WANDER_DUR total; see
#      _build_wander_sequence()).
#   5. One hop carries it out past the exit boundary (QT_EXIT_DUR).
#   6. Grows back to full size, bobs again (QT_END_BOB_DUR), then fades out
#      gently rather than disappearing abruptly (QT_FADE_DUR).

# Wide/rectangular grid (5x2, not square) rather than a compact one — more
# lateral room for the wander to actually move around in, and per direct
# feedback, more visually interesting than a boxy square. STYLE_WINDING
# (more turns than the default curve style) means more decision points for
# the wander phase to explore and bump against.
const QT_MAZE_COLS   : int   = 5
const QT_MAZE_ROWS   : int   = 2
const QT_CELL_SIZE   : float = 160.0
const QT_MAZE_STYLE  : String = MazeGenerator.STYLE_WINDING
# West-edge entry, east-edge exit — generate() was previously called with no
# start_cell/goal_col at all, defaulting to start (0,0) (a CORNER, cutting
# two boundary walls at once instead of one clean door) and an unconstrained
# goal (an arbitrary interior cell essentially never on the boundary, so no
# exit door was ever cut for it — the "no exit" bug). Row 1 (not row 0) for
# the entry avoids that same corner problem on this side.
const QT_START_CELL  : Vector2i = Vector2i(0, 1)
const QT_GOAL_COL    : int      = QT_MAZE_COLS - 1

const QT_TOP_SIZE   : float   = 300.0                 # noticeable size while on display up top
const QT_MAZE_SIZE  : float   = 150.0                 # shrunk just enough to clear the corridor
const QT_TOP_POS    : Vector2 = Vector2(640, 180)
const QT_MAZE_CENTER: Vector2 = Vector2(640, 470)     # nudged up from the maze's first pass

const QT_TOP_BOB_DUR   : float = 3.0
const QT_DESCEND_DUR   : float = 4.0    # split across 2 jumps + 2 straight walks
const QT_WANDER_DUR    : float = 8.0
const QT_EXIT_DUR      : float = 2.0
const QT_END_BOB_DUR   : float = 3.0
const QT_FADE_DUR      : float = 1.0
const QT_RESIZE_DUR    : float = 0.2
const QT_BUMP_CHANCE   : float = 0.4    # per wander step, odds of a wall-bang struggle beat
const QT_BUMP_DUR      : float = 0.35

func _play_quest_transition() -> void:
	_busy = true
	_start_music()

	var maze_size : Vector2 = Vector2(QT_MAZE_COLS, QT_MAZE_ROWS) * QT_CELL_SIZE
	var origin    : Vector2 = QT_MAZE_CENTER - maze_size / 2.0
	# goal_col forces the exit onto the east edge, but the row within that
	# column is picked at random — if it lands on the bottom row (the
	# south-east CORNER), wall_segments() cuts both its east and south walls
	# at once instead of one clean door. Retry until it lands somewhere
	# else on that edge; a handful of tries is always enough in practice.
	var deco_maze = null
	for _attempt in range(20):
		deco_maze = MazeGenerator.generate(QT_MAZE_COLS, QT_MAZE_ROWS, QT_CELL_SIZE, origin,
			QT_MAZE_STYLE, QT_START_CELL, QT_GOAL_COL)
		if deco_maze.goal_cell.y != QT_MAZE_ROWS - 1:
			break

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
	play_button.size                = Vector2(QT_TOP_SIZE, QT_TOP_SIZE)
	play_button.pivot_offset        = play_button.size / 2.0
	play_button.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	# Explicit z_index so it always draws above the wall Line2Ds regardless
	# of add-child order — same convention as the entry/exit hand sprites
	# in the real gameplay maze, which need this same "always on top of the
	# walls" guarantee.
	play_button.z_index = 5
	if ResourceLoader.exists("res://UI_assets/playbutton.png"):
		play_button.texture_normal = load("res://UI_assets/playbutton.png")
	play_button.position   = QT_TOP_POS - play_button.pivot_offset
	play_button.modulate.a = 0.0
	deco_container.add_child(play_button)

	var enter := create_tween()
	enter.tween_property(play_button, "modulate:a", 1.0, 0.3)
	await enter.finished

	# 1. Bob at the top, big and noticeable, before anything else happens.
	await _qt_bob(play_button, QT_TOP_BOB_DUR)

	# 2. Traces the maze's own outline rather than cutting a diagonal
	# straight at the entrance (which sits on the WEST edge, not below the
	# top display): 2 jumps land it above the roof then clear of the
	# corner, then it WALKS the rest of the way in — straight down along
	# the outside of the west wall first, then straight across into the
	# entrance, never diagonally.
	var entrance_center : Vector2 = deco_maze.start_pos()
	var entrance_target  : Vector2 = entrance_center - play_button.pivot_offset
	var above_roof : Vector2 = Vector2(QT_MAZE_CENTER.x, origin.y - 60) - play_button.pivot_offset
	# Cleared past the corner, not just nudged past it (a small offset still
	# visually read as clipping/walking along the wall at this size) — but
	# dialed back some from the first pass, which flew out further than needed.
	var corner_center : Vector2 = Vector2(origin.x - 100, origin.y - 40)
	var corner_pt      : Vector2 = corner_center - play_button.pivot_offset
	# Straight down first (same x as the corner, outside the west wall),
	# THEN straight across into the entrance — an L-shaped walk, not a
	# diagonal cut across both axes at once.
	var below_corner_pt : Vector2 = Vector2(corner_center.x, entrance_center.y) - play_button.pivot_offset

	var descend_seg_dur : float = QT_DESCEND_DUR / 4.0
	await _qt_dramatic_hop(play_button, above_roof, descend_seg_dur)
	await _qt_dramatic_hop(play_button, corner_pt, descend_seg_dur)
	await _qt_walk(play_button, below_corner_pt, descend_seg_dur)
	await _qt_walk(play_button, entrance_target, descend_seg_dur)

	# Shrink to corridor size right as it enters — same "full size until it
	# actually enters, then shrinks" idea as the real gameplay maze.
	await _qt_resize(play_button, QT_MAZE_SIZE)

	# 3/4. Wander like a kid exploring, not a straight line to the goal —
	# occasionally banging into a wall and bouncing back before the actual
	# hop, for visible struggle.
	var seq   : Array = _build_wander_sequence(deco_maze)
	var bumps : Array = []
	for i in range(seq.size()):
		bumps.append(randf() < QT_BUMP_CHANCE)
	var bump_count : int = 0
	for b in bumps:
		if b:
			bump_count += 1
	var wander_hop_dur : float = max(0.15, (QT_WANDER_DUR - bump_count * QT_BUMP_DUR) / float(seq.size()))
	for i in range(seq.size()):
		if bumps[i]:
			await _qt_bump(play_button)
		var target : Vector2 = deco_maze.cell_center(seq[i]) - play_button.pivot_offset
		await _qt_hop(play_button, target, wander_hop_dur)

	# 5. Carry it out past the exit boundary.
	var exit_target : Vector2 = deco_maze.goal_pos() + Vector2(QT_CELL_SIZE, 0) - play_button.pivot_offset
	await _qt_hop(play_button, exit_target, QT_EXIT_DUR)

	# 6. Back to full size, bob once more, then fade out gently.
	await _qt_resize(play_button, QT_TOP_SIZE)
	await _qt_bob(play_button, QT_END_BOB_DUR)

	var ext := create_tween()
	ext.set_parallel(true)
	ext.tween_property(play_button, "modulate:a", 0.0, QT_FADE_DUR)
	ext.tween_property(deco_container, "modulate:a", 0.0, QT_FADE_DUR)
	await ext.finished

	deco_container.queue_free()
	await _stop_music()
	_busy = false
	_start_quest()


# A clean vertical jump-arc straight toward `target` — rises then falls,
# reading clearly as "a jump" without any sideways swirl (which risked
# visually clipping through nearby maze walls given how large the Play
# Button still is at this point) and without any squash/stretch or spin
# (which distorted its round, recognizable shape). Position only.
func _qt_dramatic_hop(node: Control, target: Vector2, duration: float) -> void:
	var start : Vector2 = node.position
	var peak  : Vector2 = start.lerp(target, 0.5) + Vector2(0, -90)

	var tw := create_tween()
	tw.tween_property(node, "position", peak, duration * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", target, duration * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished


# A smooth glide straight to `target`, no arc — reads as walking rather
# than hopping. No scale/rotation change either, same "don't distort the
# shape" reasoning as _qt_dramatic_hop().
func _qt_walk(node: Control, target: Vector2, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "position", target, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


# A quick "bang into a wall and bounce back" beat — a directional nudge and
# recoil, purely cosmetic (the actual path is decided by
# _build_wander_sequence(), this never changes where it ends up), reads as
# a moment of struggle before the real hop that follows it.
func _qt_bump(node: Control) -> void:
	var start_pos : Vector2 = node.position
	var nudge : Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * 20.0
	var bump := create_tween()
	bump.set_parallel(true)
	bump.tween_property(node, "position", start_pos + nudge, QT_BUMP_DUR * 0.35).set_ease(Tween.EASE_OUT)
	bump.tween_property(node, "scale", Vector2(0.85, 0.85), QT_BUMP_DUR * 0.3)
	await bump.finished
	var recoil := create_tween()
	recoil.set_parallel(true)
	recoil.tween_property(node, "position", start_pos, QT_BUMP_DUR * 0.65).set_ease(Tween.EASE_IN)
	recoil.tween_property(node, "scale", Vector2(1.0, 1.0), QT_BUMP_DUR * 0.55)
	await recoil.finished


# Gentle up/down bob in place for roughly `duration` seconds (whole cycles
# only, so it never cuts off mid-motion) — same relative position:y idiom
# already used for the old goal-bounce beat.
func _qt_bob(node: Control, duration: float) -> void:
	const CYCLE : float = 0.6
	var cycles : int = int(round(duration / CYCLE))
	for _c in range(cycles):
		var up := create_tween()
		up.tween_property(node, "position:y", node.position.y - 14.0, CYCLE * 0.5).set_ease(Tween.EASE_OUT)
		await up.finished
		var down := create_tween()
		down.tween_property(node, "position:y", node.position.y + 14.0, CYCLE * 0.5).set_ease(Tween.EASE_IN)
		await down.finished


# One hop to `target`, taking exactly `duration` seconds total. Scale pulse
# is uniform (not a squash/stretch) so the round shape never distorts.
func _qt_hop(node: Control, target: Vector2, duration: float) -> void:
	var hop := create_tween()
	hop.set_parallel(true)
	hop.tween_property(node, "position", target, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop.tween_property(node, "scale", Vector2(1.08, 1.08), duration * 0.5)
	await hop.finished
	var settle := create_tween()
	settle.tween_property(node, "scale", Vector2(1.0, 1.0), duration * 0.5)
	await settle.finished


# Grows/shrinks to `new_size` while holding the visual CENTER point fixed —
# size, pivot_offset, and position all tween together from/to matching
# center values, so the resize never makes it jump sideways.
func _qt_resize(node: Control, new_size: float) -> void:
	var center     : Vector2 = node.position + node.pivot_offset
	var new_pivot  : Vector2 = Vector2(new_size, new_size) / 2.0
	var new_pos    : Vector2 = center - new_pivot
	var resize := create_tween()
	resize.set_parallel(true)
	resize.tween_property(node, "size", Vector2(new_size, new_size), QT_RESIZE_DUR)
	resize.tween_property(node, "pivot_offset", new_pivot, QT_RESIZE_DUR)
	resize.tween_property(node, "position", new_pos, QT_RESIZE_DUR)
	await resize.finished


# Builds a hop sequence that visits the maze's real start->goal path but
# occasionally ducks into a dead-end branch and backs out first — reads as
# a kid exploring rather than a beeline to the exit. When there's no branch
# to duck into at a given step (small mazes can have the true path cover
# every cell, leaving nothing spare to wander into), falls back to a step
# back along the path itself and forward again — still reads as "pausing to
# reconsider" rather than a silent no-op.
func _build_wander_sequence(maze) -> Array:
	var path : Array = maze.path_cells
	var on_path : Dictionary = {}
	for c in path:
		on_path[c] = true

	var seq : Array = [path[0]]
	for i in range(1, path.size()):
		var prev : Vector2i = path[i - 1]
		if randf() < 0.6:
			var detour : Vector2i = _qt_find_dead_end(maze, prev, on_path)
			if detour != Vector2i(-1, -1):
				seq.append(detour)
				seq.append(prev)
			elif i >= 2:
				seq.append(path[i - 2])
				seq.append(prev)
		seq.append(path[i])
	return seq


func _qt_find_dead_end(maze, cell: Vector2i, on_path: Dictionary) -> Vector2i:
	var open : int = maze.passages[cell.y][cell.x]
	var candidates : Array = []
	if open & 1 != 0: candidates.append(Vector2i(cell.x, cell.y - 1))
	if open & 2 != 0: candidates.append(Vector2i(cell.x, cell.y + 1))
	if open & 4 != 0: candidates.append(Vector2i(cell.x + 1, cell.y))
	if open & 8 != 0: candidates.append(Vector2i(cell.x - 1, cell.y))
	var branches : Array = []
	for c in candidates:
		if not on_path.has(c):
			branches.append(c)
	if branches.is_empty():
		return Vector2i(-1, -1)
	return branches[randi() % branches.size()]


# ─── Group complete — hand back to normal Prep progression ─────────────────
# Mirrors prep_transition.gd's _continue_to_next_set() exactly (has_next()
# BEFORE advance() — CLAUDE.md locked rule #3). Duplicated locally rather than
# calling into prep_transition.gd since that logic lives on a scene this
# scene doesn't instance; SoundQuestState intentionally carries no such
# helper either, per the plan's "no new SaveManager fields" persistence note.
func _on_all_quests_complete() -> void:
	_busy = true
	await _stop_music()
	if ReviewState.active:
		ReviewState.active = false
		SaveManager.increment_review_count(ReviewState.set_key)
		get_tree().change_scene_to_file("res://gnb_where_am_i.tscn")
		return
	if PrepLevelProgress.has_next():
		PrepLevelProgress.advance()
		get_tree().change_scene_to_file("res://prep_game.tscn")
	else:
		SaveManager.set_prep_completed()
		PrepLevelProgress.reset()
		LevelTransition.next_level_id = "level1"
		LevelTransition.level_name    = "Level 1"
		get_tree().change_scene_to_file("res://level_transition.tscn")
