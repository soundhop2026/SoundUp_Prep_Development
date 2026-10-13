extends Node2D

# ─── Level 1.5 Sound Quest — Quest A / Quest B ─────────────────────────────
# One shared implementation for both Initial Identification (Quest A) and
# Final Identification (Quest B) — identical mechanic, differing only in
# which word field drives the target ("initial" vs "final") and the total
# round count. Set via Level15SoundQuestABState before this scene loads.
#
# Round (redesigned 2026-10-13 after Galaxy QA — the old hidden target picture
# with covering tiles gave the child no way to hear the target sound or see
# where to drop): the Game 1 PlayButton sits at top centre. Tapping it plays the
# round's isolated target phoneme (the first sound in Quest A, the last sound in
# Quest B). Tapping a floating word picture plays its whole word. The child drags
# the pictures whose word has that sound onto the PlayButton: a correct drop
# plays the existing chime and the PlayButton reacts (Quest A: small vertical
# bounce, Quest B: small horizontal sway); a wrong drop resists and bounces back
# silently, same idiom as Level 1 Sound Quest. The round ends when every matching
# picture has been delivered. No progress counter.
#
# The round's target WORD is still picked internally (it decides the target
# phoneme and the correct/distractor pools exactly as before and is excluded from
# its own correct pool), but it is never shown.
# ─────────────────────────────────────────────────────────────────────────

const WORD_IMAGE_DIR : String = "res://SoundUp_level1.5_word_images/"
const WORD_AUDIO_DIR : String = "res://BGM&effect/SoundUp_level1.5_word_sounds/"
const GAYAGEUM_CORRECT_PATH : String = "res://BGM&effect/SoundUp_feedback/gayageum_correct.wav"

const BG_COLOR : Color = Color(0.431, 0.710, 1.0, 1.0)

var _all_words : Dictionary = {}
var _pool      : Array      = []   # the shared 117-word A/B/C/D pool
var _position  : String     = "initial"
var _schedule  : Array      = []
var _round_index : int      = 0

var _target_word    : String = ""
var _target_phoneme : String = ""
var _correct_pool   : Array  = []   # word keys still needing collection this round
var _collected      : int    = 0

var _all_phonemes   : Dictionary = {}   # data/phonemes.json — isolated-phoneme audio per phoneme
var _playbutton_rect : TextureRect = null   # the PlayButton: tap = target phoneme, drop target
var _pb_tween        : Tween = null          # the PlayButton's current bounce / sway
var _pool_faces    : Array = []   # Array[TextureRect], this round's word images (correct+distractor)

var _dragging    : bool = false
var _drag_face   : TextureRect = null
var _drag_offset : Vector2 = Vector2.ZERO
var _drag_pos    : Vector2 = Vector2.ZERO
var _busy        : bool = false
var _play_counted : bool = false   # true once this scene instance's real-play count
									# increment has fired (see _start_round)

var _transitions : Level15SoundQuestTransitions = null


var _entitlement_interrupted : bool = false   # confirmed entitlement loss already handled


# Confirmed entitlement loss during premium gameplay: stop now, write nothing
# (no completion, no full-attempt count, cursor and records untouched), and go
# to the subscription flow. Called by EntitlementService via PremiumGameplay.GROUP.
func interrupt_for_entitlement_loss() -> void:
	if _entitlement_interrupted:
		return
	_entitlement_interrupted = true
	_busy = true
	PremiumGameplay.stop_audio(self)
	PremiumGameplay.refuse(self)


func _ready() -> void:
	if not PremiumGameplay.level_scene_admitted():
		PremiumGameplay.refuse(self)
		return
	PremiumGameplay.join(self)
	var _center_offset : float = SceneBackground.center_offset()
	PLAYBUTTON_POS.x += _center_offset
	POOL_CENTER.x += _center_offset
	SceneBackground.set_color(BG_COLOR)
	var bg := ColorRect.new()
	bg.color        = BG_COLOR
	bg.size         = get_viewport_rect().size
	bg.position     = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_create_gnb_flag()
	_transitions = Level15SoundQuestTransitions.new()
	add_child(_transitions)

	_position = Level15SoundQuestABState.position
	_all_words = Level15SoundQuestState.load_words()
	_all_phonemes = Level15SoundQuestState.load_phonemes()
	_spawn_playbutton()
	_pool = Level15SoundQuestState.build_pool_abcd(_all_words)
	var eligible : Dictionary = Level15SoundQuestState.eligible_target_phonemes(_all_words, _pool, _position)
	_schedule = Level15SoundQuestState.build_target_schedule(eligible, Level15SoundQuestABState.total_rounds)

	_round_index = 0
	_start_round()


func _start_round() -> void:
	if not _play_counted:
		_play_counted = true
		if DebugConfig.debug_launch:
			DebugConfig.debug_launch = false
		else:
			var letter : String = "A" if _position == "initial" else "B"
			SaveManager.increment_review_count("level15_soundquest_" + letter)
	_busy = true
	_clear_round()

	_target_phoneme = _schedule[_round_index]
	var candidates : Array = Level15SoundQuestState.words_for_phoneme(_all_words, _pool, _position, _target_phoneme)
	_target_word = candidates[randi() % candidates.size()]
	_correct_pool = Level15SoundQuestState.build_correct_pool(_all_words, _pool, _position, _target_word)
	_collected = 0

	_spawn_word_pool()
	_busy = false


func _clear_round() -> void:
	_dragging = false
	_drag_face = null
	for f in _pool_faces:
		var t : Tween = f.get_meta("bob_tween", null)
		if t != null and t.is_valid():
			t.kill()
		f.queue_free()
	_pool_faces.clear()


# ─── PlayButton (top centre) ─────────────────────────────────────────────────
# The Game 1 PlayButton artwork, drawn the same way Quest C/D draws it, only
# larger so it reads clearly as the target. Taps hit-test PLAYBUTTON_POS /
# PLAYBUTTON_SIZE (never the node's animated position), and a drop counts when
# the dragged picture's centre lands inside the same rectangle grown by
# DROP_MARGIN. Sizes and the reaction amounts are the approved starting values,
# to be verified with a real finger on the Galaxy.

const PLAYBUTTON_TEXTURE_PATH : String = "res://UI_assets/playbutton.png"
const PLAYBUTTON_SIZE : Vector2 = Vector2(340, 164)
var PLAYBUTTON_POS  : Vector2 = Vector2(470, 22)   # recentred in _ready() like every other scene
const DROP_MARGIN : float = 24.0
const PB_REACT_AMOUNT : float = 14.0   # px, small bounce / sway
const PB_REACT_STEP   : float = 0.11   # seconds per leg


func _spawn_playbutton() -> void:
	_playbutton_rect = TextureRect.new()
	_playbutton_rect.texture = load(PLAYBUTTON_TEXTURE_PATH)
	_playbutton_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_playbutton_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_playbutton_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE   # hit-testing is manual
	_playbutton_rect.size = PLAYBUTTON_SIZE
	_playbutton_rect.pivot_offset = PLAYBUTTON_SIZE / 2.0
	_playbutton_rect.position = PLAYBUTTON_POS
	add_child(_playbutton_rect)


func _drop_zone() -> Rect2:
	return Rect2(PLAYBUTTON_POS - Vector2(DROP_MARGIN, DROP_MARGIN), PLAYBUTTON_SIZE + Vector2(DROP_MARGIN, DROP_MARGIN) * 2.0)


# Tapping the PlayButton plays this round's target phoneme in isolation.
func _play_target_audio() -> void:
	if _all_phonemes.has(_target_phoneme):
		_play_sfx(String(_all_phonemes[_target_phoneme]["audio"]))


# A correct picture has arrived. Quest A: one small vertical bounce. Quest B: one small
# horizontal sway. Always ends exactly on PLAYBUTTON_POS; a quick second drop restarts it.
func _playbutton_react() -> void:
	if _playbutton_rect == null or not is_instance_valid(_playbutton_rect):
		return
	if _pb_tween != null and _pb_tween.is_valid():
		_pb_tween.kill()
	_playbutton_rect.position = PLAYBUTTON_POS
	_pb_tween = create_tween()
	if _position == "initial":
		_pb_tween.tween_property(_playbutton_rect, "position:y", PLAYBUTTON_POS.y - PB_REACT_AMOUNT, PB_REACT_STEP).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_pb_tween.tween_property(_playbutton_rect, "position:y", PLAYBUTTON_POS.y, PB_REACT_STEP * 1.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		_pb_tween.tween_property(_playbutton_rect, "position:x", PLAYBUTTON_POS.x - PB_REACT_AMOUNT, PB_REACT_STEP).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_pb_tween.tween_property(_playbutton_rect, "position:x", PLAYBUTTON_POS.x + PB_REACT_AMOUNT, PB_REACT_STEP * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pb_tween.tween_property(_playbutton_rect, "position:x", PLAYBUTTON_POS.x, PB_REACT_STEP).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# ─── Word pool (correct + distractors) ──────────────────────────────────────

var POOL_CENTER       : Vector2 = Vector2(640, 455)   # mobile-alignment fix — recentered in _ready()
const POOL_HALF_EXTENTS : Vector2 = Vector2(585, 185)   # picture centres span y 270-640: clear of the drop zone (ends y=210), the flag and the screen bottom; about the same area as before the redesign so spacing stays as easy to tap
const FACE_SCALE  : Vector2 = Vector2(80, 80)
const MIN_SPACING : float = 90.0
# 120 rather than 30: with 26 pictures in the zone, 30 tries occasionally gave up and left two pictures
# almost on top of each other (about 3% of crowded rounds, measured over 6,000 simulated rounds), which is hard to tap.
const MAX_ATTEMPTS : int = 120
const DISTRACTOR_COUNT : int = 16

func _spawn_word_pool() -> void:
	var distractors : Array = Level15SoundQuestState.build_distractors(
		_all_words, _pool, _position, _target_word, _correct_pool, DISTRACTOR_COUNT)

	var all_faces : Array = []
	for w in _correct_pool:
		all_faces.append({"word": w, "correct": true})
	for w in distractors:
		all_faces.append({"word": w, "correct": false})
	all_faces.shuffle()

	var placed : Array = []
	for entry in all_faces:
		var tex : Texture2D = load(WORD_IMAGE_DIR + entry["word"] + ".png")
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.size = FACE_SCALE
		rect.pivot_offset = FACE_SCALE / 2.0

		var center : Vector2 = _pick_pool_center(placed)
		placed.append(center)
		rect.position = center - rect.pivot_offset
		rect.set_meta("base_pos", rect.position)
		rect.set_meta("word", entry["word"])
		rect.set_meta("correct", entry["correct"])

		add_child(rect)
		_pool_faces.append(rect)
		_start_bob(rect)


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
	if _dragging and _drag_face != null and is_instance_valid(_drag_face):
		_drag_face.position = _drag_pos + _drag_offset


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
	if Rect2(PLAYBUTTON_POS, PLAYBUTTON_SIZE).has_point(pos):
		_play_target_audio()
		return
	for i in range(_pool_faces.size() - 1, -1, -1):
		var f : TextureRect = _pool_faces[i]
		if not is_instance_valid(f):
			continue
		if Rect2(f.position, f.size).has_point(pos):
			_dragging = true
			_drag_face = f
			_drag_offset = f.position - pos
			_drag_pos = pos
			var t : Tween = f.get_meta("bob_tween", null)
			if t != null and t.is_valid():
				t.pause()
			move_child(f, get_child_count() - 1)
			_play_sfx(WORD_AUDIO_DIR + String(f.get_meta("word")) + ".wav")
			return


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	var f : TextureRect = _drag_face
	_drag_face = null
	if f == null or not is_instance_valid(f):
		return

	var face_center : Vector2 = f.position + f.size / 2.0
	if _drop_zone().has_point(face_center):
		if f.get_meta("correct"):
			_on_correct_drop(f)
		else:
			_on_wrong_drop(f)
	else:
		_on_drop_empty_space(f)


func _on_correct_drop(f: TextureRect) -> void:
	_busy = true
	_pool_faces.erase(f)
	var old_bob : Tween = f.get_meta("bob_tween", null)
	if old_bob != null and old_bob.is_valid():
		old_bob.kill()

	_play_sfx(GAYAGEUM_CORRECT_PATH)

	var land_pos : Vector2 = PLAYBUTTON_POS + PLAYBUTTON_SIZE / 2.0 - f.size / 2.0
	var hop := create_tween()
	hop.tween_property(f, "position", land_pos, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop.tween_callback(_playbutton_react)   # the PlayButton reacts the moment the picture reaches it
	hop.tween_property(f, "modulate:a", 0.0, 0.15)
	await hop.finished
	f.queue_free()

	_collected += 1

	if _collected >= _correct_pool.size():
		_busy = false
		_on_round_complete()
	else:
		_busy = false


func _on_wrong_drop(f: TextureRect) -> void:
	_busy = true
	var start_pos : Vector2 = f.position
	var target_center : Vector2 = PLAYBUTTON_POS + PLAYBUTTON_SIZE / 2.0
	var away : Vector2 = (start_pos + f.size / 2.0) - target_center
	if away == Vector2.ZERO:
		away = Vector2.UP
	away = away.normalized() * 18.0

	var resist := create_tween()
	for _i in range(2):
		resist.tween_property(f, "position", start_pos + away, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		resist.tween_property(f, "position", start_pos, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await resist.finished

	var base_pos : Vector2 = f.get_meta("base_pos")
	var bounce := create_tween()
	bounce.tween_property(f, "position", base_pos, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await bounce.finished

	_resume_bob(f)
	_busy = false


func _on_drop_empty_space(f: TextureRect) -> void:
	_busy = true
	var base_pos : Vector2 = f.get_meta("base_pos")
	var glide := create_tween()
	glide.tween_property(f, "position", base_pos, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await glide.finished
	_resume_bob(f)
	_busy = false


func _resume_bob(f: TextureRect) -> void:
	var t : Tween = f.get_meta("bob_tween", null)
	if t != null and t.is_valid():
		t.play()


const ROUND_COMPLETE_HOLD : float = 0.5
const ROUND_FADE_DUR      : float = 0.3

# A "Sound Quest Set" is one 8-round chunk (locked 2026-08-06: Quest A = 4
# Sets x 8 = 32 rounds, Quest B = 5 Sets x 8 = 40 rounds — both divide evenly,
# no partial Set).
#
# Two-tier Transition rule (corrected 2026-08-06 follow-up — the original
# session draft had this backwards, treating the Long Transition as a
# one-time first-entry moment; it is NOT):
#   - Short Transition: every Set boundary WITHIN a Quest (e.g. A1->A2,
#     A2->A3, A3->A4).
#   - Long Story Transition: a Quest's FINAL Set boundary only (e.g. A4's
#     completion) — the Short Transition does NOT also play there. Plays once
#     per Quest type (A-F), 6 times total across all of Level 1.5 Sound Quest.
const ROUNDS_PER_SET : int = 8

func _on_round_complete() -> void:
	_busy = true

	await get_tree().create_timer(ROUND_COMPLETE_HOLD, false).timeout
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
	# The PlayButton fades with the round, so the Short / Long Transition's own Play Button
	# never shares the screen with it.
	if _playbutton_rect != null and is_instance_valid(_playbutton_rect):
		t.tween_property(_playbutton_rect, "modulate:a", 0.0, ROUND_FADE_DUR)
	for f in _pool_faces:
		if is_instance_valid(f):
			t.tween_property(f, "modulate:a", 0.0, ROUND_FADE_DUR)
	await t.finished


# _start_round() has just run — _pool_faces are the NEW round's nodes. Snap them
# (and the PlayButton, which faded out with the last round) to 0 alpha and tween up,
# rather than touching _start_round() itself, so the tested spawn logic stays untouched.
func _fade_in_round() -> void:
	if _playbutton_rect != null and is_instance_valid(_playbutton_rect):
		_playbutton_rect.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(_playbutton_rect, "modulate:a", 1.0, ROUND_FADE_DUR)

	var t2 := create_tween()
	t2.set_parallel(true)
	for f in _pool_faces:
		if is_instance_valid(f):
			f.modulate.a = 0.0
			t2.tween_property(f, "modulate:a", 1.0, ROUND_FADE_DUR)


const QUEST_B_ROUNDS : int = 40

func _on_quest_complete() -> void:
	if _position == "initial":
		# Quest A (initial identification) finished -> hand off straight into
		# Quest B (final identification). Same scene, same handoff mechanism
		# already used to boot Quest A in the first place: set the state,
		# reload, let _ready() rebuild everything from scratch.
		Level15SoundQuestABState.position = "final"
		Level15SoundQuestABState.total_rounds = QUEST_B_ROUNDS
		get_tree().reload_current_scene()
		return

	_busy = false
	# Sound Quest is optional bonus content — Quest B's completion has no
	# effect on any progression. Returns to Where Am I; the player picks
	# another Sound Quest from there rather than auto-chaining into Quest C.
	ReviewState.active = false   # Where Am I sets it again on the next replay pick
	get_tree().change_scene_to_file("res://gnb_where_am_i.tscn")


# ─── GNB / Where Am I — standard resumable overlay ─────────────────────────
# Same flag button and overlay as game.gd / game15.gd (position, scale and
# margin from SceneBackground so it can never drift from the other scenes).
# Aligned 2026-09-17 — replaced the old Sound-Quest-only variant (hardcoded
# (20, 20) corner, no scale, full change_scene_to_file() that abandoned the
# Quest and, worse, never cleared ReviewState.active — which then misrouted
# the next real Level 1.5 set completion into Where Am I instead of the Set
# Transition).
#
# Resume model: a Sound Quest round carries real mid-round state (revealed
# patches / collected bubbles / filled rungs / eaten words, bob tweens, an
# in-flight Set Transition), so unlike game15.gd this does NOT restart the
# round on close. Instead the whole scene tree is paused while the overlay
# (PROCESS_MODE_ALWAYS) is up — tweens, timers, coroutines, audio and
# _input() all freeze exactly where they are and pick up on close. The one
# thing not preserved is an in-progress drag: the pointer-release would be
# swallowed by the overlay, so the held item is dropped in place (the
# empty-space path) before pausing. Any exit that leaves this scene while
# paused (Where Am I's replay picks) is covered by _exit_tree() unpausing.
var _gnb_btn : Button = null

func _create_gnb_flag() -> void:
	var BTN_W : float = SceneBackground.GNB_BTN_SIZE.x
	var BTN_H : float = SceneBackground.GNB_BTN_SIZE.y

	_gnb_btn              = Button.new()
	_gnb_btn.text         = ""
	_gnb_btn.size         = Vector2(BTN_W, BTN_H)
	_gnb_btn.position     = SceneBackground.gnb_button_position()
	_gnb_btn.z_index      = 10
	_gnb_btn.pivot_offset = Vector2(BTN_W * 0.5, BTN_H * 0.5)
	_gnb_btn.scale        = Vector2.ONE * SceneBackground.GNB_BTN_SCALE

	var blank := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		_gnb_btn.add_theme_stylebox_override(s, blank)

	var pill := Panel.new()
	pill.size         = Vector2(50.0, 52.0)
	pill.position     = (Vector2(BTN_W, BTN_H) - pill.size) / 2.0
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	var pill_color := Color("#4B0082")
	pill_color.a                  = 0.4
	ps.bg_color                   = pill_color
	ps.corner_radius_top_left     = 14
	ps.corner_radius_top_right    = 14
	ps.corner_radius_bottom_left  = 14
	ps.corner_radius_bottom_right = 14
	pill.add_theme_stylebox_override("panel", ps)
	_gnb_btn.add_child(pill)

	var flag_icon := TextureRect.new()
	flag_icon.texture      = load("res://UI_assets/flag.png") as Texture2D
	flag_icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	flag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flag_icon.size         = Vector2(42, 47)
	flag_icon.position     = (Vector2(BTN_W, BTN_H) - flag_icon.size) / 2.0
	_gnb_btn.add_child(flag_icon)

	_gnb_btn.pressed.connect(_on_gnb_flag_pressed)
	add_child(_gnb_btn)


func _cancel_drag() -> void:
	if _dragging and _drag_face != null and is_instance_valid(_drag_face):
		var f : TextureRect = _drag_face
		_dragging  = false
		_drag_face = null
		_on_drop_empty_space(f)
	else:
		_dragging  = false
		_drag_face = null


func _on_gnb_flag_pressed() -> void:
	if get_node_or_null("GNBOverlay") != null:
		return
	_cancel_drag()
	var overlay := CanvasLayer.new()
	overlay.layer        = 100
	overlay.name         = "GNBOverlay"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the tree is paused
	var wai : Node = load("res://gnb_where_am_i.tscn").instantiate()
	wai.set("is_overlay", true)
	wai.connect("close_requested", func():
		overlay.queue_free()
		get_tree().paused = false   # everything resumes exactly where it froze
	)
	overlay.add_child(wai)
	add_child(overlay)
	get_tree().paused = true


func _exit_tree() -> void:
	# Leaving while paused (a replay pick inside the overlay) must never hand
	# a paused tree to the next scene.
	get_tree().paused = false


func _play_sfx(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
