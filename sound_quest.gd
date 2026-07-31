extends Node2D

# ─── Sound Quest ────────────────────────────────────────────────────────────
# Mastery activity (not a teaching activity) shown once per Prep Group, right
# after that Group's last sub-set finishes (see prep_transition.gd's
# is_main_set_boundary() branch). Reached via SoundQuestState's handoff.
#
# 4 words visible at once, each bobbing in its own fixed area. Tap = hear the
# phoneme (unlimited, exploration only). Press-and-drag past the bobbing
# area's boundary starts a maze attempt: a fresh maze is generated, the full
# word loops while dragging, a hard wall means instant fail, reaching the
# goal marks the word mastered. Failed words stay in the same visible slot
# for immediate retry — never requeued. 4 Quests per Group; Quest Transition
# is a purely decorative Play-Button-walks-a-maze celebration between them.
# After Quest 4, hands back to normal Prep progression exactly like
# prep_transition.gd's _continue_to_next_set().
# ─────────────────────────────────────────────────────────────────────────────

const FONT_PATH : String = "res://UI_assets/210 연필스케치R.ttf"
const MUSIC_PATH : String = "res://soundquest/assets/quest_preplevel_bgm.mp3"

const BG_COLOR     : Color = Color("#A8E063")   # same baby-green as Prep
const PURPLE       : Color = Color("#4B0082")
const AMBER        : Color = Color("#FFB703")
const WHITE        : Color = Color("#FFFFFF")
const WALL_COLOR   : Color = Color("#2E2E2E")   # thick hand-drawn-style wall lines
const ROUTE_COLOR  : Color = Color("#4B0082")   # hidden route, once revealed — brand purple

# 4 fixed slot centers — same quadrant layout game.gd uses for 4-choice rounds.
const SLOT_POSITIONS : Array[Vector2] = [
	Vector2(370, 270),
	Vector2(810, 270),
	Vector2(370, 490),
	Vector2(810, 490),
]

const IMAGE_BOX     : float = 150.0    # word image fits within this box
const BOB_AREA_SIZE : Vector2 = Vector2(190, 190)   # boundary the drag must cross
const BOB_AMPLITUDE : float = 8.0
const BOB_HALF_DUR  : float = 0.9

const TAP_MOVE_THRESHOLD : float = 14.0   # px — below this, a release counts as a tap

# One shared maze box for every Group — difficulty is carried by route STYLE
# (see STYLE_WEIGHTS_BY_GROUP below), not by growing the box. Sized from the
# real slot layout: only one maze is ever active at a time (the drag state
# machine allows just one slot in ST_DRAG_MAZE), so it only has to clear the
# other 3 idle bobbing images (190x190 each) and the screen edges — measured
# clearance around any of the 4 slots is ~325px horizontally but only
# ~115-125px vertically, so the box is landscape rather than square.
const MAZE_COLS       : int   = 8
const MAZE_ROWS        : int   = 4
const MAZE_CELL_SIZE   : float = 50.0
const MAZE_WALL_WIDTH  : float = 6.0
const ROUTE_WIDTH      : float = 5.0
const GOAL_MARKER_R    : float = 14.0

const MOVE_STOP_DELAY : float = 0.18   # no drag-motion event within this window = "stopped"

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
const ST_DRAG_MAZE     : String = "drag_maze"


var _font : Font = null

var _group_letter : String = "A"
var _quests        : Array = []   # Array[Array[Dictionary]] — 4 quests of {image, word_audio, phoneme_audio}
var _quest_index    : int   = 0
var _quest_remaining : Array = []  # words in the current Quest not yet placed in a slot
var _quest_total_words : int = 0
var _quest_done_words  : int = 0

var _slots : Array = []   # per-slot Dictionary, see _make_slot()

var _dragging_slot_index : int = -1
var _drag_press_pos      : Vector2 = Vector2.ZERO
var _drag_moved_far      : bool    = false
var _drag_anchor_pointer : Vector2 = Vector2.ZERO   # pointer pos at the moment maze mode was entered
var _drag_anchor_target  : Vector2 = Vector2.ZERO   # image center pos at that same moment (== maze start)

var _maze          = null   # MazeGenerator.MazeData
var _maze_container : Node2D = null

var _phoneme_player : AudioStreamPlayer = null
var _word_player     : AudioStreamPlayer = null
var _success_player  : AudioStreamPlayer = null
var _fail_player     : AudioStreamPlayer = null
var _music_player     : AudioStreamPlayer = null

var _word_audio_active : bool = false   # guards the manual play->finished->replay loop
var _move_timer : Timer = null   # word audio pauses when no drag-motion arrives within MOVE_STOP_DELAY

var _header_label : Label = null
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

	_group_letter = PrepLevelProgress.set_labels[SoundQuestState.group_start_index][0]

	_build_audio_players()
	_start_music()
	_build_header()
	_maze_container = Node2D.new()
	add_child(_maze_container)

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
# Loops for the whole Sound Quest scene lifetime — same manual loop-on-finished
# idiom as level_transition.gd's _start_music()/_on_music_finished(). Keeps
# playing straight through Quest Transitions (no scene change happens between
# Quests), fades out once before handing control back to Prep progression.
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


func _build_header() -> void:
	_header_label = Label.new()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_header_label.position = Vector2(0, 16)
	_header_label.size     = Vector2(1280, 44)
	_header_label.add_theme_font_size_override("font_size", 28)
	_header_label.add_theme_color_override("font_color", PURPLE)
	if _font:
		_header_label.add_theme_font_override("font", _font)
	add_child(_header_label)
	_update_header()


func _update_header() -> void:
	if _header_label:
		_header_label.text = "Group %s · Sound Quest %d of %d" % [
			_group_letter, _quest_index + 1, QUEST_COUNT]


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
	_update_header()

	for slot in _slots:
		if slot.get("node") != null:
			slot["node"].queue_free()
	_slots.clear()
	for i in range(SLOT_POSITIONS.size()):
		_slots.append(_make_slot(i))

	_fill_slots()


func _make_slot(index: int) -> Dictionary:
	var base_pos : Vector2 = SLOT_POSITIONS[index]
	var btn := TextureButton.new()
	btn.ignore_texture_size = true
	btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.size                = Vector2(IMAGE_BOX, IMAGE_BOX)
	btn.pivot_offset        = Vector2(IMAGE_BOX, IMAGE_BOX) / 2.0
	btn.position             = base_pos - btn.pivot_offset
	btn.visible              = false
	btn.mouse_filter         = Control.MOUSE_FILTER_STOP
	add_child(btn)

	return {
		"node"      : btn,
		"base_pos"  : base_pos,
		"word"      : {},
		"state"     : ST_EMPTY,
		"bob_tween" : null,
	}


func _fill_slots() -> void:
	for i in range(_slots.size()):
		var slot : Dictionary = _slots[i]
		if slot["state"] != ST_EMPTY:
			continue
		if _quest_remaining.is_empty():
			continue
		var word : Dictionary = _quest_remaining.pop_front()
		_place_word_in_slot(i, word)
	_check_quest_complete()


func _place_word_in_slot(index: int, word: Dictionary) -> void:
	var slot : Dictionary = _slots[index]
	var btn  : TextureButton = slot["node"]
	slot["word"]  = word
	slot["state"] = ST_BOBBING
	_slots[index] = slot

	var tex : Texture2D = null
	if word.get("image", "") != "" and ResourceLoader.exists(word["image"]):
		tex = load(word["image"]) as Texture2D
	btn.texture_normal = tex
	btn.position        = slot["base_pos"] - btn.pivot_offset
	btn.modulate.a      = 0.0
	btn.visible         = true

	var fade := create_tween()
	fade.tween_property(btn, "modulate:a", 1.0, 0.25)

	_start_bob(index)


func _check_quest_complete() -> void:
	if not _quest_remaining.is_empty():
		return
	for slot in _slots:
		if slot["state"] != ST_EMPTY:
			return
	# All words in this Quest are done and no slot is occupied.
	_quest_index += 1
	_play_quest_transition()


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
	btn.position = slot["base_pos"] - btn.pivot_offset
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
		# Crossed the boundary — lock into maze gameplay.
		_enter_maze_mode(idx, pos)
		return

	if slot["state"] == ST_DRAG_MAZE:
		# The maze is generated centered on the slot, not on wherever the
		# finger happened to cross the bobbing-area boundary, so the image
		# tracks pointer movement relative to the anchor set in
		# _enter_maze_mode() rather than jumping straight to the raw pointer
		# position — that keeps it inside the corridor's start cell and keeps
		# the maze fully on-screen regardless of which edge was crossed.
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
	elif slot["state"] == ST_DRAG_MAZE:
		# Released mid-maze, before reaching the goal.
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


func _enter_maze_mode(index: int, drag_pos: Vector2) -> void:
	var slot : Dictionary = _slots[index]
	_stop_bob(index)
	slot["state"] = ST_DRAG_MAZE
	_slots[index] = slot

	var maze_size : Vector2 = Vector2(MAZE_COLS, MAZE_ROWS) * MAZE_CELL_SIZE
	var origin    : Vector2 = slot["base_pos"] - maze_size / 2.0
	_maze = MazeGenerator.generate(MAZE_COLS, MAZE_ROWS, MAZE_CELL_SIZE, origin, _pick_style())
	_render_maze()

	# Anchor the image to the maze's actual start cell rather than the raw
	# crossing point — see _update_drag()'s ST_DRAG_MAZE branch, which maps
	# further pointer motion relative to this anchor.
	_drag_anchor_pointer = drag_pos
	_drag_anchor_target  = _maze.start_pos()

	var btn : TextureButton = slot["node"]
	btn.position = _drag_anchor_target - btn.pivot_offset

	_start_word_audio(index)


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

	# The hidden route becomes visible the instant the maze itself does — both
	# share the same trigger (crossing the bobbing-area boundary) — so it's
	# drawn right alongside the walls, no separate reveal-on-movement state.
	# A fresh attempt after a fail calls _clear_maze() first, which frees this
	# along with everything else, so it starts hidden again next time.
	var route := Line2D.new()
	route.width           = ROUTE_WIDTH
	route.default_color   = ROUTE_COLOR
	route.begin_cap_mode  = Line2D.LINE_CAP_ROUND
	route.end_cap_mode    = Line2D.LINE_CAP_ROUND
	route.joint_mode      = Line2D.LINE_JOINT_ROUND
	for cell in _maze.path_cells:
		route.add_point(_maze.cell_center(cell))
	_maze_container.add_child(route)

	var goal := ColorRect.new()
	goal.color    = AMBER
	goal.size     = Vector2(GOAL_MARKER_R, GOAL_MARKER_R) * 2.0
	goal.position = _maze.goal_pos() - goal.size / 2.0
	goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_maze_container.add_child(goal)


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
	_clear_maze()
	var slot : Dictionary = _slots[index]
	slot["state"] = ST_BOBBING
	_slots[index] = slot
	_snap_back(index)
	if _dragging_slot_index == index:
		_dragging_slot_index = -1


func _succeed_attempt(index: int) -> void:
	_stop_word_audio()
	_success_player.play()
	_clear_maze()
	if _dragging_slot_index == index:
		_dragging_slot_index = -1

	var slot : Dictionary = _slots[index]
	var btn  : TextureButton = slot["node"]
	slot["state"] = ST_EMPTY
	slot["word"]  = {}
	_slots[index] = slot
	_quest_done_words += 1

	var fade := create_tween()
	fade.tween_property(btn, "modulate:a", 0.0, 0.2)
	fade.tween_callback(func():
		btn.visible = false
		_fill_slots()
	)


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
