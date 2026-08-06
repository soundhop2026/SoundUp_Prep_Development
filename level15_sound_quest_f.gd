extends Node2D

# ─── Level 1.5 Sound Quest — Quest F (Sound Count) ─────────────────────────
# Drag word images sharing the target's phoneme COUNT (not identity) onto
# Play Button, who eats matches and rejects mismatches. Unlike every other
# Level 1.5 Sound Quest type, the target is a NUMBER (3, 4, or 5 phonemes),
# not a specific phoneme or word — matching is "does this word have the
# same sound-count," judged by the whole word's own audio, not a single
# phoneme in isolation.
#
# Growth: Play Button grows 30% of its original size per correct word eaten
# (cumulative, resets each round — never shrinks WITHIN a round). Exit tier
# (hop hop / waddle / roll, all the way off the viewport) scales with how
# many were eaten this round.
# ─────────────────────────────────────────────────────────────────────────

const WORD_IMAGE_DIR : String = "res://SoundUp_level1.5_word_images/"
const WORD_AUDIO_DIR : String = "res://BGM&effect/SoundUp_level1.5_word_sounds/"
const PLAYBUTTON_TEXTURE_PATH : String = "res://UI_assets/playbutton.png"
const DROP_ZONE_TEXTURE_PATH  : String = "res://soundquest/assets/drop_zone_level15_soundquest_F.png"
const NOM_PATH  : String = "res://soundquest/assets/playbutton_level15_soundquest_F_nom.wav"
const BLEH_PATH : String = "res://soundquest/assets/playbutton_level15_soundquest_F_bleh.wav"

const BG_COLOR : Color = Color(0.827, 0.929, 0.827, 1.0)

var _all_words : Dictionary = {}
var _buckets   : Dictionary = {}   # {phoneme_count: [word_key, ...]}
var _schedule  : Array      = []   # target phoneme counts, one per round
var _round_index : int      = 0

var _target_count  : int   = 0
var _correct_pool  : Array = []   # word keys still needing collection this round
var _eaten_count   : int   = 0

var _playbutton_rect : TextureRect = null
var _drop_zone_rect  : TextureRect = null
var _word_pool        : Array = []   # Array[TextureRect], this round's correct+distractor images

var _dragging    : bool = false
var _drag_word   : TextureRect = null
var _drag_offset : Vector2 = Vector2.ZERO
var _drag_pos    : Vector2 = Vector2.ZERO
var _busy        : bool = false

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
	_buckets = Level15SoundQuestState.f_bucket_by_count(_all_words)
	_schedule = Level15SoundQuestState.f_build_count_schedule()

	_round_index = 0
	_start_round()


func _start_round() -> void:
	_busy = true
	_clear_round()

	_target_count = _schedule[_round_index]
	_correct_pool = Level15SoundQuestState.f_correct_pool(_buckets[_target_count], _target_count)
	_eaten_count = 0

	_spawn_playbutton()
	_spawn_drop_zone()
	_spawn_word_pool()
	_busy = false


func _clear_round() -> void:
	_dragging = false
	_drag_word = null
	if _playbutton_rect != null:
		_playbutton_rect.queue_free()
		_playbutton_rect = null
	if _drop_zone_rect != null:
		_drop_zone_rect.queue_free()
		_drop_zone_rect = null
	for w in _word_pool:
		var t : Tween = w.get_meta("bob_tween", null)
		if t != null and t.is_valid():
			t.kill()
		w.queue_free()
	_word_pool.clear()


# ─── Play Button (grows 30% per eaten word, cumulative, resets each round) ──

const PLAYBUTTON_BASE_SIZE : Vector2 = Vector2(150, 72)
const PLAYBUTTON_CENTER    : Vector2 = Vector2(640, 160)
const GROWTH_PER_EATEN     : float   = 0.3

func _spawn_playbutton() -> void:
	var tex : Texture2D = load(PLAYBUTTON_TEXTURE_PATH)
	_playbutton_rect = TextureRect.new()
	_playbutton_rect.texture = tex
	_playbutton_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_playbutton_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_playbutton_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playbutton_rect.size = PLAYBUTTON_BASE_SIZE
	_playbutton_rect.pivot_offset = PLAYBUTTON_BASE_SIZE / 2.0
	_playbutton_rect.position = PLAYBUTTON_CENTER - _playbutton_rect.pivot_offset
	_playbutton_rect.scale = Vector2.ONE
	add_child(_playbutton_rect)


func _grow_playbutton() -> void:
	var target_scale : float = 1.0 + GROWTH_PER_EATEN * _eaten_count
	var t := create_tween()
	t.tween_property(_playbutton_rect, "scale", Vector2(target_scale, target_scale), 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ─── Drop zone (fixed, in front of Play Button) ─────────────────────────────

const DROP_ZONE_SIZE : Vector2 = Vector2(300, 63)
const DROP_ZONE_POS  : Vector2 = Vector2(490, 260)

func _spawn_drop_zone() -> void:
	var tex : Texture2D = load(DROP_ZONE_TEXTURE_PATH)
	_drop_zone_rect = TextureRect.new()
	_drop_zone_rect.texture = tex
	_drop_zone_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drop_zone_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drop_zone_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone_rect.size = DROP_ZONE_SIZE
	_drop_zone_rect.position = DROP_ZONE_POS
	add_child(_drop_zone_rect)


# ─── Word pool (correct + distractors) ──────────────────────────────────────

const WORD_SIZE     : Vector2 = Vector2(90, 90)
const POOL_CENTER       : Vector2 = Vector2(640, 500)
const POOL_HALF_EXTENTS : Vector2 = Vector2(600, 180)
const MIN_SPACING  : float = 100.0
const MAX_ATTEMPTS : int   = 30
const ROUND_POOL_TOTAL : int = 20

func _spawn_word_pool() -> void:
	var distractor_count : int = ROUND_POOL_TOTAL - _correct_pool.size()
	var distractors : Array = Level15SoundQuestState.f_build_distractors(
		_buckets, _target_count, _correct_pool, distractor_count)

	var entries : Array = []
	for w in _correct_pool:
		entries.append({"word": w, "correct": true})
	for w in distractors:
		entries.append({"word": w, "correct": false})
	entries.shuffle()

	var placed : Array = []
	for entry in entries:
		var tex : Texture2D = load(WORD_IMAGE_DIR + entry["word"] + ".png")
		var w := TextureRect.new()
		w.texture = tex
		w.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		w.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w.size = WORD_SIZE
		w.pivot_offset = WORD_SIZE / 2.0

		var center : Vector2 = _pick_pool_center(placed)
		placed.append(center)
		w.position = center - w.pivot_offset
		w.set_meta("base_pos", w.position)
		w.set_meta("word", entry["word"])
		w.set_meta("correct", entry["correct"])

		add_child(w)
		_word_pool.append(w)
		_start_bob(w)


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

func _process(_delta: float) -> void:
	if _dragging and _drag_word != null and is_instance_valid(_drag_word):
		_drag_word.position = _drag_pos + _drag_offset


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
	for i in range(_word_pool.size() - 1, -1, -1):
		var w : TextureRect = _word_pool[i]
		if not is_instance_valid(w):
			continue
		if Rect2(w.position, w.size).has_point(pos):
			_dragging = true
			_drag_word = w
			_drag_offset = w.position - pos
			_drag_pos = pos
			var t : Tween = w.get_meta("bob_tween", null)
			if t != null and t.is_valid():
				t.pause()
			move_child(w, get_child_count() - 1)
			_play_sfx(WORD_AUDIO_DIR + String(w.get_meta("word")) + ".wav")
			return


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	var w : TextureRect = _drag_word
	_drag_word = null
	if w == null or not is_instance_valid(w):
		return

	var word_center : Vector2 = w.position + w.size / 2.0
	var zone_rect : Rect2 = Rect2(DROP_ZONE_POS, DROP_ZONE_SIZE)
	if zone_rect.has_point(word_center):
		if w.get_meta("correct"):
			_on_eaten(w)
		else:
			_on_rejected(w)
	else:
		_on_drop_empty_space(w)


func _on_eaten(w: TextureRect) -> void:
	_busy = true
	_word_pool.erase(w)
	var old_bob : Tween = w.get_meta("bob_tween", null)
	if old_bob != null and old_bob.is_valid():
		old_bob.kill()

	_play_sfx(NOM_PATH)

	var into_pb := create_tween()
	into_pb.tween_property(w, "position", PLAYBUTTON_CENTER - w.size / 2.0, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	into_pb.tween_property(w, "modulate:a", 0.0, 0.12)
	await into_pb.finished
	w.queue_free()

	_eaten_count += 1
	_grow_playbutton()

	if _eaten_count >= _correct_pool.size():
		_busy = false
		await _on_round_complete_exit()
	else:
		_busy = false


func _on_rejected(w: TextureRect) -> void:
	_busy = true
	_play_sfx(BLEH_PATH)

	var start_pos : Vector2 = w.position
	var zone_center : Vector2 = DROP_ZONE_POS + DROP_ZONE_SIZE / 2.0
	var away : Vector2 = (start_pos + w.size / 2.0) - zone_center
	if away == Vector2.ZERO:
		away = Vector2.UP
	away = away.normalized() * 18.0

	var resist := create_tween()
	for _i in range(2):
		resist.tween_property(w, "position", start_pos + away, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		resist.tween_property(w, "position", start_pos, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await resist.finished

	var base_pos : Vector2 = w.get_meta("base_pos")
	var bounce := create_tween()
	bounce.tween_property(w, "position", base_pos, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await bounce.finished

	_resume_bob(w)
	_busy = false


func _on_drop_empty_space(w: TextureRect) -> void:
	_busy = true
	var base_pos : Vector2 = w.get_meta("base_pos")
	var glide := create_tween()
	glide.tween_property(w, "position", base_pos, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await glide.finished
	_resume_bob(w)
	_busy = false


func _resume_bob(w: TextureRect) -> void:
	var t : Tween = w.get_meta("bob_tween", null)
	if t != null and t.is_valid():
		t.play()


# ─── Round complete: exit tier by how many were eaten ───────────────────────
# Locked tiers: 1-4 = hop hop, 5-6 = waddle, 8+ = roll. The design didn't
# specify 7 explicitly — treated as the top of the waddle tier (5-7) here,
# the most conservative reading that leaves no count without an animation.

const EXIT_X   : float = 1450.0
const HOP_DUR      : float = 0.25
const HOP_HEIGHT   : float = 30.0
const HOP_COUNT    : int   = 6
const WADDLE_DUR    : float = 1.3
const WADDLE_SWAY   : float = 14.0
const ROLL_DUR      : float = 1.0

func _on_round_complete_exit() -> void:
	_busy = true

	if _eaten_count <= 4:
		await _exit_hop()
	elif _eaten_count <= 7:
		await _exit_waddle()
	else:
		await _exit_roll()

	_on_round_complete()


func _exit_hop() -> void:
	var t := create_tween()
	var base_y : float = _playbutton_rect.position.y
	for _i in range(HOP_COUNT):
		t.tween_property(_playbutton_rect, "position:y", base_y - HOP_HEIGHT, HOP_DUR / 2.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(_playbutton_rect, "position:y", base_y, HOP_DUR / 2.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(_playbutton_rect, "position:x", EXIT_X, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished


func _exit_waddle() -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_playbutton_rect, "position:x", EXIT_X, WADDLE_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var sway := create_tween()
	sway.set_loops(6)
	sway.tween_property(_playbutton_rect, "rotation_degrees", WADDLE_SWAY, WADDLE_DUR / 12.0)
	sway.tween_property(_playbutton_rect, "rotation_degrees", -WADDLE_SWAY, WADDLE_DUR / 6.0)
	sway.tween_property(_playbutton_rect, "rotation_degrees", 0.0, WADDLE_DUR / 12.0)
	await t.finished
	sway.kill()
	_playbutton_rect.rotation_degrees = 0.0


func _exit_roll() -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_playbutton_rect, "position:x", EXIT_X, ROLL_DUR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(_playbutton_rect, "rotation_degrees", 720.0, ROLL_DUR).set_trans(Tween.TRANS_LINEAR)
	await t.finished


const ROUND_FADE_DUR : float = 0.3

# Locked: Quest F = 10 Sets x 10 rounds = 100 rounds.
const ROUNDS_PER_SET : int = 10

func _on_round_complete() -> void:
	var t := create_tween()
	t.set_parallel(true)
	for w in _word_pool:
		if is_instance_valid(w):
			t.tween_property(w, "modulate:a", 0.0, ROUND_FADE_DUR)
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
	print("Level 1.5 Sound Quest — Quest F complete. Level 1.5 Sound Quest (A-F) fully done.")
	# Handoff back into game15.gd / Level15Progress not wired yet — same open
	# item as every other quest type this session.


func _play_sfx(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
