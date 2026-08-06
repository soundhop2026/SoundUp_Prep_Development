extends Node2D

# ─── Level 1.5 Sound Quest — Quest C / Quest D ─────────────────────────────
# One shared implementation for both Initial Isolation (Quest C) and Final
# Isolation (Quest D) — identical mechanic, differing only in which word
# field drives the target ("initial" vs "final") and the phoneme-frequency
# scaling. Set via Level15SoundQuestCDState before this scene loads.
#
# Round: 20 phoneme bubbles continuously rise from the bottom of the screen,
# looping back to the bottom if uncollected — a single reusable bubble
# texture, phonemes told apart only by tap-to-hear audio (locked "no
# letters" rule, same as Level 1's bins and Quest A/B's word-audio pattern).
# Drag a bubble matching the round's target phoneme onto Play Button to
# collect it; a wrong drag silently bumps away and keeps rising, never
# destroyed. Round ends once target_count matching bubbles are collected.
# ─────────────────────────────────────────────────────────────────────────

const BUBBLE_TEXTURE_PATH     : String = "res://soundquest/assets/bubble_level15_soundquest_C_D.png"
const PLAYBUTTON_TEXTURE_PATH : String = "res://UI_assets/playbutton.png"
const GAYAGEUM_CORRECT_PATH   : String = "res://BGM&effect/SoundUp_feedback/gayageum_correct.wav"

const BG_COLOR : Color = Color(0.545, 0.816, 0.882, 1.0)

var _all_words     : Dictionary = {}
var _pool          : Array      = []   # the shared 117-word A/B/C/D pool
var _all_phonemes  : Dictionary = {}
var _position      : String     = "initial"
var _schedule      : Array      = []
var _round_index   : int        = 0
var _freqs         : Dictionary = {}   # {phoneme: word_count} for this position
var _min_freq      : int        = 0
var _max_freq      : int        = 0

var _target_phoneme : String = ""
var _target_count   : int    = 0
var _collected      : int    = 0

var _bubbles         : Array = []   # Array[TextureRect], this round's rising bubbles
var _playbutton_rect  : TextureRect = null

var _dragging    : bool = false
var _drag_bubble : TextureRect = null
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

	_spawn_playbutton()

	_position = Level15SoundQuestCDState.position
	_all_words = Level15SoundQuestState.load_words()
	_pool = Level15SoundQuestState.build_pool_abcd(_all_words)
	_all_phonemes = Level15SoundQuestState.load_phonemes()
	_freqs = Level15SoundQuestState.phoneme_frequencies(_all_words, _pool, _position)
	var freq_vals : Array = _freqs.values()
	_min_freq = freq_vals.min()
	_max_freq = freq_vals.max()
	_schedule = Level15SoundQuestState.build_target_schedule(_freqs, Level15SoundQuestCDState.total_rounds)

	_round_index = 0
	_start_round()


func _start_round() -> void:
	_busy = true
	_clear_round()

	_target_phoneme = _schedule[_round_index]
	_target_count = Level15SoundQuestState.cd_target_bubble_count(_freqs[_target_phoneme], _min_freq, _max_freq)
	_collected = 0

	_spawn_bubbles()
	_busy = false


func _clear_round() -> void:
	_dragging = false
	_drag_bubble = null
	for b in _bubbles:
		b.queue_free()
	_bubbles.clear()


# ─── Play Button (fixed collection target, spawned once) ────────────────────

const PLAYBUTTON_POS  : Vector2 = Vector2(1080, 300)
const PLAYBUTTON_SIZE : Vector2 = Vector2(150, 72)

func _spawn_playbutton() -> void:
	var tex : Texture2D = load(PLAYBUTTON_TEXTURE_PATH)
	_playbutton_rect = TextureRect.new()
	_playbutton_rect.texture = tex
	_playbutton_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_playbutton_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_playbutton_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playbutton_rect.size = PLAYBUTTON_SIZE
	_playbutton_rect.position = PLAYBUTTON_POS
	add_child(_playbutton_rect)


# ─── Rising bubble field ──────────────────────────────────────────────────

const BUBBLE_SIZE     : Vector2 = Vector2(70, 60)
const BUBBLE_COUNT    : int     = 20
const FIELD_X_MIN     : float   = 60.0
const FIELD_X_MAX     : float   = 950.0
const FIELD_TOP_Y     : float   = 20.0
const FIELD_BOTTOM_Y  : float   = 700.0
const RISE_SPEED      : float   = 35.0   # px/sec

func _spawn_bubbles() -> void:
	var distractor_count : int = BUBBLE_COUNT - _target_count
	var distractor_phonemes : Array = Level15SoundQuestState.cd_build_distractor_phonemes(
		_all_phonemes, _target_phoneme, distractor_count)

	var entries : Array = []
	for _i in range(_target_count):
		entries.append(_target_phoneme)
	for ph in distractor_phonemes:
		entries.append(ph)
	entries.shuffle()

	var tex : Texture2D = load(BUBBLE_TEXTURE_PATH)
	for ph in entries:
		var b := TextureRect.new()
		b.texture = tex
		b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.size = BUBBLE_SIZE
		b.pivot_offset = BUBBLE_SIZE / 2.0
		var center : Vector2 = Vector2(randf_range(FIELD_X_MIN, FIELD_X_MAX), randf_range(FIELD_TOP_Y, FIELD_BOTTOM_Y))
		b.position = center - b.pivot_offset
		b.set_meta("phoneme", ph)
		b.set_meta("correct", ph == _target_phoneme)
		add_child(b)
		_bubbles.append(b)


func _process(delta: float) -> void:
	for b in _bubbles:
		if b == _drag_bubble or not is_instance_valid(b):
			continue
		b.position.y -= RISE_SPEED * delta
		if b.position.y + b.size.y < FIELD_TOP_Y:
			var respawn_center : Vector2 = Vector2(randf_range(FIELD_X_MIN, FIELD_X_MAX), FIELD_BOTTOM_Y)
			b.position = respawn_center - b.pivot_offset

	if _dragging and _drag_bubble != null and is_instance_valid(_drag_bubble):
		_drag_bubble.position = _drag_pos + _drag_offset


# ─── Drag & drop ─────────────────────────────────────────────────────────────

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
	for i in range(_bubbles.size() - 1, -1, -1):
		var b : TextureRect = _bubbles[i]
		if not is_instance_valid(b):
			continue
		if Rect2(b.position, b.size).has_point(pos):
			_dragging = true
			_drag_bubble = b
			_drag_offset = b.position - pos
			_drag_pos = pos
			move_child(b, get_child_count() - 1)
			var ph : String = String(b.get_meta("phoneme"))
			_play_sfx(String(_all_phonemes[ph]["audio"]))
			return


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	var b : TextureRect = _drag_bubble
	_drag_bubble = null
	if b == null or not is_instance_valid(b):
		return

	var bubble_center : Vector2 = b.position + b.size / 2.0
	var target_rect : Rect2 = Rect2(PLAYBUTTON_POS, PLAYBUTTON_SIZE)
	if target_rect.has_point(bubble_center):
		if b.get_meta("correct"):
			_on_correct_drop(b)
		else:
			_on_wrong_drop(b)
	# Dropped in empty space: no special handling needed — _process() already
	# resumes normal rising from wherever it was released, now that
	# _dragging is false.


func _on_correct_drop(b: TextureRect) -> void:
	_busy = true
	_bubbles.erase(b)

	_play_sfx(GAYAGEUM_CORRECT_PATH)

	var land_pos : Vector2 = PLAYBUTTON_POS + PLAYBUTTON_SIZE / 2.0 - b.size / 2.0
	var hop := create_tween()
	hop.tween_property(b, "position", land_pos, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop.tween_property(b, "modulate:a", 0.0, 0.15)
	await hop.finished
	b.queue_free()

	_collected += 1

	if _collected >= _target_count:
		_busy = false
		_on_round_complete()
	else:
		_busy = false


# Silent bump-away, never destroyed — the bubble keeps rising afterward,
# handled automatically by _process() once _dragging is false again.
func _on_wrong_drop(b: TextureRect) -> void:
	_busy = true
	var start_pos : Vector2 = b.position
	var pb_center : Vector2 = PLAYBUTTON_POS + PLAYBUTTON_SIZE / 2.0
	var away : Vector2 = (start_pos + b.size / 2.0) - pb_center
	if away == Vector2.ZERO:
		away = Vector2.UP
	away = away.normalized() * 24.0

	var bump := create_tween()
	bump.tween_property(b, "position", start_pos + away, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await bump.finished
	_busy = false


const ROUND_COMPLETE_HOLD : float = 0.5
const ROUND_FADE_DUR      : float = 0.3

# Locked 2026-08-06: Quest C/D = 4 Sets x 14 rounds = 56 rounds each.
const ROUNDS_PER_SET : int = 14

func _on_round_complete() -> void:
	_busy = true

	await get_tree().create_timer(ROUND_COMPLETE_HOLD).timeout
	await _fade_out_round()

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
	_fade_in_round()
	_busy = false


func _fade_out_round() -> void:
	var t := create_tween()
	t.set_parallel(true)
	for b in _bubbles:
		if is_instance_valid(b):
			t.tween_property(b, "modulate:a", 0.0, ROUND_FADE_DUR)
	await t.finished


func _fade_in_round() -> void:
	var t := create_tween()
	t.set_parallel(true)
	for b in _bubbles:
		if is_instance_valid(b):
			b.modulate.a = 0.0
			t.tween_property(b, "modulate:a", 1.0, ROUND_FADE_DUR)


const QUEST_D_ROUNDS : int = 56

func _on_quest_complete() -> void:
	if _position == "initial":
		# Quest C (initial isolation) finished -> hand off straight into
		# Quest D (final isolation). Same scene, same handoff mechanism as
		# Quest A -> B: set the state, reload, let _ready() rebuild from
		# scratch.
		Level15SoundQuestCDState.position = "final"
		Level15SoundQuestCDState.total_rounds = QUEST_D_ROUNDS
		get_tree().reload_current_scene()
		return

	_busy = false
	print("Level 1.5 Sound Quest — Quest D complete, Group's C/D pair finished.")
	# Handoff back to game15.gd / Level15Progress not wired yet — same open
	# item as Quest A/B, needs its own investigation.


func _play_sfx(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
