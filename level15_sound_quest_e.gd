extends Node2D

# ─── Level 1.5 Sound Quest — Quest E (Build the Word) ──────────────────────
# Drag phoneme branches onto a ladder, bottom-to-top, to spell out the
# target word's own sound sequence. Unlike A/B/C/D, there is no
# "initial"/"final" split and no floor/ceiling on the pool — every one of
# the 130 words (all 4 structures, CVC through CCVCC) is fair game, and the
# correct branches are literally the target word's own ordered phonemes[].
#
# Layout: target image top; ladder (stacked reusable frame segments) on the
# left with Play Button waiting below it; bobbing branch pool (single
# reusable rung texture, phonemes told apart only by tap-to-hear audio) on
# the right. Order is enforced live — only the current next-needed phoneme
# is ever accepted, dropped anywhere else (even a later-needed correct
# phoneme) bounces back, same idiom as Quest A/B's wrong-drop.
#
# Completion: once every rung is placed, Play Button climbs the ladder rung
# by rung, touches the target image (word audio plays once), hops to the
# image's right side, then both walk off together — Play Button's size
# matches the target image's size for the ENTIRE round, no scaling at any
# point (locked: it's visually paired with the image once they walk off).
# ─────────────────────────────────────────────────────────────────────────

const WORD_IMAGE_DIR : String = "res://SoundUp_level1.5_word_images/"
const WORD_AUDIO_DIR : String = "res://BGM&effect/SoundUp_level1.5_word_sounds/"
const LADDER_FRAME_PATH : String = "res://soundquest/assets/ladder_frame_level15_soundquest_E.png"
const LADDER_RUNG_PATH  : String = "res://soundquest/assets/ladder_rung_level15_soundquest_E.png"
const PLAYBUTTON_TEXTURE_PATH : String = "res://UI_assets/playbutton.png"
const GAYAGEUM_CORRECT_PATH   : String = "res://BGM&effect/SoundUp_feedback/gayageum_correct.wav"

const BG_COLOR : Color = Color(0.996, 0.918, 0.729, 1.0)

var _all_words     : Dictionary = {}
var _pool          : Array      = []   # all 130 words, all 4 structures
var _all_phonemes  : Dictionary = {}
var _schedule      : Array      = []   # word keys, one per round
var _round_index   : int        = 0

var _target_word      : String = ""
var _target_phonemes  : Array  = []   # ordered, e.g. ["f","r","short_o","s","t"]
var _filled_count     : int    = 0

var _target_rect     : TextureRect = null
var _frame_segments   : Array = []   # Array[TextureRect], static ladder scaffold
var _placed_rungs     : Array = []   # Array[TextureRect], rungs placed on the ladder so far
var _branch_pool      : Array = []   # Array[TextureRect], this round's bobbing branches
var _playbutton_rect  : TextureRect = null

var _dragging     : bool = false
var _drag_branch  : TextureRect = null
var _drag_offset  : Vector2 = Vector2.ZERO
var _drag_pos     : Vector2 = Vector2.ZERO
var _busy         : bool = false

var _transitions : Level15SoundQuestTransitions = null


func _ready() -> void:
	SceneBackground.set_color(BG_COLOR)
	var bg := ColorRect.new()
	bg.color        = BG_COLOR
	bg.size         = get_viewport_rect().size
	bg.position     = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_transitions = Level15SoundQuestTransitions.new()
	add_child(_transitions)

	_all_words = Level15SoundQuestState.load_words()
	_pool = Level15SoundQuestState.build_pool_e(_all_words)
	_all_phonemes = Level15SoundQuestState.load_phonemes()
	_schedule = Level15SoundQuestState.build_word_schedule(_pool, TOTAL_ROUNDS)

	_round_index = 0
	_start_round()


func _start_round() -> void:
	_busy = true
	_clear_round()

	_target_word = _schedule[_round_index]
	_target_phonemes = _all_words[_target_word]["phonemes"]
	_filled_count = 0

	_spawn_target_image()
	_spawn_ladder()
	_spawn_playbutton()
	_spawn_branch_pool()
	_busy = false


func _clear_round() -> void:
	_dragging = false
	_drag_branch = null
	if _target_rect != null:
		_target_rect.queue_free()
		_target_rect = null
	for f in _frame_segments:
		f.queue_free()
	_frame_segments.clear()
	for r in _placed_rungs:
		r.queue_free()
	_placed_rungs.clear()
	for b in _branch_pool:
		var t : Tween = b.get_meta("bob_tween", null)
		if t != null and t.is_valid():
			t.kill()
		b.queue_free()
	_branch_pool.clear()
	if _playbutton_rect != null:
		_playbutton_rect.queue_free()
		_playbutton_rect = null


# ─── Target image ─────────────────────────────────────────────────────────

const TARGET_POS  : Vector2 = Vector2(560, 20)
const TARGET_SIZE : Vector2 = Vector2(140, 110)

func _spawn_target_image() -> void:
	var tex : Texture2D = load(WORD_IMAGE_DIR + _target_word + ".png")
	_target_rect = TextureRect.new()
	_target_rect.texture = tex
	_target_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_rect.size = TARGET_SIZE
	_target_rect.position = TARGET_POS
	add_child(_target_rect)


# ─── Ladder (two vertical rails, stretched to match the word's phoneme ─────
# ─── count; rungs get placed crossing between them as they're collected) ───
# ladder_frame_level15_soundquest_E.png is a single straight vertical bar —
# the ladder is TWO of them side by side (the two rails), each stretched to
# the needed height, not N copies stacked into one line.

const LADDER_X          : float = 170.0
const LADDER_RAIL_WIDTH : float = 10.0
const LADDER_RAIL_GAP   : float = 70.0    # distance between the two rails
const SLOT_HEIGHT       : float = 76.0    # vertical space per rung level
const LADDER_BASE_Y     : float = 580.0   # bottom edge of the ladder

func _spawn_ladder() -> void:
	var tex : Texture2D = load(LADDER_FRAME_PATH)
	var n : int = _target_phonemes.size()
	var ladder_height : float = n * SLOT_HEIGHT
	for side in [-1.0, 1.0]:
		var rail := TextureRect.new()
		rail.texture = tex
		rail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rail.stretch_mode = TextureRect.STRETCH_SCALE
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rail.size = Vector2(LADDER_RAIL_WIDTH, ladder_height)
		rail.position = Vector2(
			LADDER_X + side * LADDER_RAIL_GAP / 2.0 - LADDER_RAIL_WIDTH / 2.0,
			LADDER_BASE_Y - ladder_height)
		add_child(rail)
		_frame_segments.append(rail)


# Center position of the level-i rung slot (0 = bottom).
func _rung_slot_center(level: int) -> Vector2:
	var y : float = LADDER_BASE_Y - (level + 0.5) * SLOT_HEIGHT
	return Vector2(LADDER_X, y)


# ─── Play Button (fixed size == TARGET_SIZE for the whole round, no scaling) ─

const PLAYBUTTON_SIZE : Vector2 = TARGET_SIZE

func _spawn_playbutton() -> void:
	var tex : Texture2D = load(PLAYBUTTON_TEXTURE_PATH)
	_playbutton_rect = TextureRect.new()
	_playbutton_rect.texture = tex
	_playbutton_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_playbutton_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_playbutton_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playbutton_rect.size = PLAYBUTTON_SIZE
	_playbutton_rect.pivot_offset = PLAYBUTTON_SIZE / 2.0
	var wait_center : Vector2 = Vector2(LADDER_X, LADDER_BASE_Y + 80.0)
	_playbutton_rect.position = wait_center - _playbutton_rect.pivot_offset
	add_child(_playbutton_rect)


# ─── Branch pool (correct rungs, one per target phoneme occurrence, + ───────
# ─── distractors, 12 total per round) ───────────────────────────────────────

const RUNG_SIZE     : Vector2 = Vector2(90, 34)
const BRANCH_TOTAL  : int     = 12
const POOL_CENTER       : Vector2 = Vector2(870, 420)
const POOL_HALF_EXTENTS : Vector2 = Vector2(330, 230)
const MIN_SPACING  : float = 60.0
const MAX_ATTEMPTS : int   = 30

func _spawn_branch_pool() -> void:
	var correct_count : int = _target_phonemes.size()
	var distractor_count : int = BRANCH_TOTAL - correct_count
	var distractor_phonemes : Array = Level15SoundQuestState.e_build_distractor_phonemes(
		_all_phonemes, _target_phonemes, distractor_count)

	var entries : Array = []
	for ph in _target_phonemes:
		entries.append({"phoneme": ph, "correct": true})
	for ph in distractor_phonemes:
		entries.append({"phoneme": ph, "correct": false})
	entries.shuffle()

	var tex : Texture2D = load(LADDER_RUNG_PATH)
	var placed : Array = []
	for entry in entries:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size = RUNG_SIZE
		r.pivot_offset = RUNG_SIZE / 2.0

		var center : Vector2 = _pick_pool_center(placed)
		placed.append(center)
		r.position = center - r.pivot_offset
		r.set_meta("base_pos", r.position)
		r.set_meta("phoneme", entry["phoneme"])
		r.set_meta("correct", entry["correct"])

		add_child(r)
		_branch_pool.append(r)
		_start_bob(r)


func _pick_pool_center(placed: Array) -> Vector2:
	var candidate : Vector2 = POOL_CENTER
	for _attempt in range(MAX_ATTEMPTS):
		candidate = POOL_CENTER + Vector2(
			randf_range(-1.0, 1.0) * POOL_HALF_EXTENTS.x,
			randf_range(-1.0, 1.0) * POOL_HALF_EXTENTS.y)
		var far_enough := true
		for p in placed:
			if candidate.distance_to(p) < MIN_SPACING:
				far_enough = false
				break
		if far_enough:
			return candidate
	return candidate


func _start_bob(node: Control) -> void:
	var base : Vector2 = node.position
	var t := create_tween()
	node.set_meta("bob_tween", t)
	t.set_loops()
	t.tween_interval(randf() * 0.6)
	t.tween_property(node, "position:y", base.y - 5.0, 0.3).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "position:y", base.y, 0.3).set_ease(Tween.EASE_IN_OUT)


# ─── Drag & drop ─────────────────────────────────────────────────────────────

# Generous vertical strip covering the ladder (at any of its 3-5 heights)
# and Play Button's waiting spot — dropping anywhere in it counts as
# "placing on the ladder."
const LADDER_DROP_ZONE : Rect2 = Rect2(Vector2(60, 20), Vector2(220, 700))

func _process(_delta: float) -> void:
	if _dragging and _drag_branch != null and is_instance_valid(_drag_branch):
		_drag_branch.position = _drag_pos + _drag_offset


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_try_start_drag(mb.position)
		elif _dragging:
			_drag_pos = mb.position
			_end_drag.call_deferred()
	elif event is InputEventMouseMotion:
		if _dragging:
			_drag_pos = (event as InputEventMouseMotion).position


func _try_start_drag(pos: Vector2) -> void:
	if _busy or _dragging:
		return
	if Rect2(TARGET_POS, TARGET_SIZE).has_point(pos):
		_play_sfx(WORD_AUDIO_DIR + _target_word + ".wav")
		return
	for i in range(_branch_pool.size() - 1, -1, -1):
		var b : TextureRect = _branch_pool[i]
		if not is_instance_valid(b):
			continue
		if Rect2(b.position, b.size).has_point(pos):
			_dragging = true
			_drag_branch = b
			_drag_offset = b.position - pos
			_drag_pos = pos
			var t : Tween = b.get_meta("bob_tween", null)
			if t != null and t.is_valid():
				t.pause()
			move_child(b, get_child_count() - 1)
			var ph : String = String(b.get_meta("phoneme"))
			_play_sfx(String(_all_phonemes[ph]["audio"]))
			return


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	var b : TextureRect = _drag_branch
	_drag_branch = null
	if b == null or not is_instance_valid(b):
		return

	var branch_center : Vector2 = b.position + b.size / 2.0
	if LADDER_DROP_ZONE.has_point(branch_center):
		var needed_phoneme : String = _target_phonemes[_filled_count]
		if b.get_meta("correct") and String(b.get_meta("phoneme")) == needed_phoneme:
			_on_correct_drop(b)
		else:
			_on_wrong_drop(b)
	else:
		_on_drop_empty_space(b)


func _on_correct_drop(b: TextureRect) -> void:
	_busy = true
	_branch_pool.erase(b)
	var old_bob : Tween = b.get_meta("bob_tween", null)
	if old_bob != null and old_bob.is_valid():
		old_bob.kill()

	_play_sfx(GAYAGEUM_CORRECT_PATH)

	var slot_center : Vector2 = _rung_slot_center(_filled_count)
	var hop := create_tween()
	hop.tween_property(b, "position", slot_center - b.size / 2.0, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await hop.finished

	_placed_rungs.append(b)
	_filled_count += 1

	if _filled_count >= _target_phonemes.size():
		_busy = false
		await _on_round_complete_climb()
	else:
		_busy = false


# Same resist-twice-bounce-back idiom as Quest A/B — a mismatch (wrong
# phoneme OR a correct-word phoneme presented out of turn) is rejected
# outright, no partial credit, no destination reached.
func _on_wrong_drop(b: TextureRect) -> void:
	_busy = true
	var start_pos : Vector2 = b.position
	var ladder_center : Vector2 = Vector2(LADDER_X, LADDER_BASE_Y)
	var away : Vector2 = (start_pos + b.size / 2.0) - ladder_center
	if away == Vector2.ZERO:
		away = Vector2.UP
	away = away.normalized() * 18.0

	var resist := create_tween()
	for _i in range(2):
		resist.tween_property(b, "position", start_pos + away, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		resist.tween_property(b, "position", start_pos, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await resist.finished

	var base_pos : Vector2 = b.get_meta("base_pos")
	var bounce := create_tween()
	bounce.tween_property(b, "position", base_pos, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await bounce.finished

	_resume_bob(b)
	_busy = false


func _on_drop_empty_space(b: TextureRect) -> void:
	_busy = true
	var base_pos : Vector2 = b.get_meta("base_pos")
	var glide := create_tween()
	glide.tween_property(b, "position", base_pos, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await glide.finished
	_resume_bob(b)
	_busy = false


func _resume_bob(b: TextureRect) -> void:
	var t : Tween = b.get_meta("bob_tween", null)
	if t != null and t.is_valid():
		t.play()


# ─── Round-complete: climb -> touch image -> hop beside -> walk off ────────

const CLIMB_HOP_DUR   : float = 0.8   # slowed further from 0.55 per feedback
const TOUCH_HOLD      : float = 0.3
const STAGE_HOP_DUR   : float = 0.25
const WALK_OFF_X      : float = 1450.0
const WALK_OFF_DUR    : float = 2.2    # slowed from 1.1 — walking the image off should feel unhurried, not rushed

func _on_round_complete_climb() -> void:
	_busy = true

	for level in range(_target_phonemes.size()):
		var slot_center : Vector2 = _rung_slot_center(level)
		var climb := create_tween()
		climb.tween_property(_playbutton_rect, "position", slot_center - _playbutton_rect.pivot_offset, CLIMB_HOP_DUR) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await climb.finished

	var touch_center : Vector2 = TARGET_POS + TARGET_SIZE / 2.0
	var to_image := create_tween()
	to_image.tween_property(_playbutton_rect, "position", touch_center - _playbutton_rect.pivot_offset, CLIMB_HOP_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await to_image.finished

	_play_sfx(WORD_AUDIO_DIR + _target_word + ".wav")
	await get_tree().create_timer(TOUCH_HOLD).timeout

	var stage_center : Vector2 = TARGET_POS + Vector2(TARGET_SIZE.x + _playbutton_rect.size.x / 2.0 + 10.0, TARGET_SIZE.y / 2.0)
	var to_stage := create_tween()
	to_stage.tween_property(_playbutton_rect, "position", stage_center - _playbutton_rect.pivot_offset, STAGE_HOP_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await to_stage.finished

	var walk := create_tween()
	walk.set_parallel(true)
	walk.tween_property(_playbutton_rect, "position:x", WALK_OFF_X, WALK_OFF_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	walk.tween_property(_target_rect, "position:x", WALK_OFF_X, WALK_OFF_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await walk.finished

	_on_round_complete()


const ROUND_FADE_DUR : float = 0.3

# Locked: Quest E = 10 Sets x 10 rounds = 100 rounds.
const ROUNDS_PER_SET : int = 10
const TOTAL_ROUNDS    : int = 100

func _on_round_complete() -> void:
	# Remaining (unused distractor) branches fade out; the walk-off already
	# carried Play Button + target image away, no separate fade needed for
	# those two.
	var t := create_tween()
	t.set_parallel(true)
	for b in _branch_pool:
		if is_instance_valid(b):
			t.tween_property(b, "modulate:a", 0.0, ROUND_FADE_DUR)
	await t.finished

	var rounds_done : int = _round_index + 1
	_round_index += 1

	var quest_finished : bool = _round_index >= _schedule.size()
	var set_boundary   : bool = rounds_done % ROUNDS_PER_SET == 0

	if set_boundary and not quest_finished:
		await _transitions.play_short()
	elif quest_finished:
		await _transitions.play_long()

	if quest_finished:
		_on_quest_complete()
		return

	_start_round()
	_busy = false


func _on_quest_complete() -> void:
	_busy = false
	print("Level 1.5 Sound Quest — Quest E complete.")
	# Handoff into Quest F not wired yet — Quest F doesn't exist as a scene
	# yet, same incremental order as every other quest type this session.


func _play_sfx(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
