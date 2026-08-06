extends Node2D

# ─── Level 1.5 Sound Quest — Quest A / Quest B ─────────────────────────────
# One shared implementation for both Initial Identification (Quest A) and
# Final Identification (Quest B) — identical mechanic, differing only in
# which word field drives the target ("initial" vs "final") and the total
# round count. Set via Level15SoundQuestABState before this scene loads.
#
# Round: a faint target image sits at top, revealed one patch at a time as
# the child drags in correct words (sharing the target's phoneme) from a
# scattered pool below that also contains distractors. Wrong drags resist
# and bounce back, same idiom as Level 1 Sound Quest.
#
# PLACEHOLDER PATCH ART: the locked design calls for each target image to
# have its own predefined patch regions (Option A — "fish = head/body/tail/
# fin"), but that art doesn't exist yet and the bespoke-vs-template question
# is still open. This reveals via a plain NxM grid mask sized to the
# correct-pool count instead, swappable later without touching round logic.
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

var _target_rect  : TextureRect = null
var _patch_grid    : Array = []   # Array[ColorRect], one per patch cell
var _pool_faces    : Array = []   # Array[TextureRect], this round's word images (correct+distractor)

var _dragging    : bool = false
var _drag_face   : TextureRect = null
var _drag_offset : Vector2 = Vector2.ZERO
var _drag_pos    : Vector2 = Vector2.ZERO
var _busy        : bool = false


func _ready() -> void:
	SceneBackground.set_color(BG_COLOR)
	var bg := ColorRect.new()
	bg.color        = BG_COLOR
	bg.size         = get_viewport_rect().size
	bg.position     = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_position = Level15SoundQuestABState.position
	_all_words = Level15SoundQuestState.load_words()
	_pool = Level15SoundQuestState.build_pool_abcd(_all_words)
	var eligible : Dictionary = Level15SoundQuestState.eligible_target_phonemes(_all_words, _pool, _position)
	_schedule = Level15SoundQuestState.build_target_schedule(eligible, Level15SoundQuestABState.total_rounds)

	_round_index = 0
	_start_round()


func _start_round() -> void:
	_busy = true
	_clear_round()

	_target_phoneme = _schedule[_round_index]
	var candidates : Array = Level15SoundQuestState.words_for_phoneme(_all_words, _pool, _position, _target_phoneme)
	_target_word = candidates[randi() % candidates.size()]
	_correct_pool = Level15SoundQuestState.build_correct_pool(_all_words, _pool, _position, _target_word)
	_collected = 0

	_spawn_target_image()
	_spawn_patch_grid()
	_spawn_word_pool()
	_busy = false


func _clear_round() -> void:
	_dragging = false
	_drag_face = null
	if _target_rect != null:
		_target_rect.queue_free()
		_target_rect = null
	for p in _patch_grid:
		p.queue_free()
	_patch_grid.clear()
	for f in _pool_faces:
		var t : Tween = f.get_meta("bob_tween", null)
		if t != null and t.is_valid():
			t.kill()
		f.queue_free()
	_pool_faces.clear()


# ─── Target image + patch grid (placeholder reveal) ─────────────────────────

const TARGET_SIZE : Vector2 = Vector2(220, 220)
const TARGET_POS  : Vector2 = Vector2(530, 40)
const TARGET_FAINT_ALPHA : float = 0.12

func _spawn_target_image() -> void:
	var tex : Texture2D = load(WORD_IMAGE_DIR + _target_word + ".png")
	_target_rect = TextureRect.new()
	_target_rect.texture = tex
	_target_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_rect.size = TARGET_SIZE
	_target_rect.position = TARGET_POS
	_target_rect.modulate.a = TARGET_FAINT_ALPHA
	add_child(_target_rect)


# Placeholder: nearest-rectangle grid sized to correct_pool.size(). Real
# implementation swaps this for per-image predefined regions once that art
# exists — nothing else in this file depends on the grid shape.
func _spawn_patch_grid() -> void:
	var n : int = _correct_pool.size()
	var cols : int = ceili(sqrt(float(n)))
	var rows : int = ceili(float(n) / float(cols))
	var cell : Vector2 = Vector2(TARGET_SIZE.x / cols, TARGET_SIZE.y / rows)
	for i in range(n):
		var r : int = i / cols
		var c : int = i % cols
		var patch := ColorRect.new()
		patch.color = BG_COLOR
		patch.size = cell - Vector2(2, 2)
		patch.position = TARGET_POS + Vector2(c * cell.x, r * cell.y) + Vector2(1, 1)
		patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(patch)
		_patch_grid.append(patch)


func _reveal_patch() -> void:
	if _collected - 1 < _patch_grid.size():
		var patch : ColorRect = _patch_grid[_collected - 1]
		var t := create_tween()
		t.tween_property(patch, "modulate:a", 0.0, 0.3)


# ─── Word pool (correct + distractors) ──────────────────────────────────────

const POOL_CENTER       : Vector2 = Vector2(640, 480)
const POOL_HALF_EXTENTS : Vector2 = Vector2(580, 190)
const FACE_SCALE  : Vector2 = Vector2(80, 80)
const MIN_SPACING : float = 90.0
const MAX_ATTEMPTS : int = 30
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
	var target_rect2 : Rect2 = Rect2(TARGET_POS, TARGET_SIZE)
	if target_rect2.has_point(face_center):
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

	var land_pos : Vector2 = TARGET_POS + TARGET_SIZE / 2.0 - f.size / 2.0
	var hop := create_tween()
	hop.tween_property(f, "position", land_pos, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop.tween_property(f, "modulate:a", 0.0, 0.15)
	await hop.finished
	f.queue_free()

	_collected += 1
	_reveal_patch()

	if _collected >= _correct_pool.size():
		_busy = false
		_on_round_complete()
	else:
		_busy = false


func _on_wrong_drop(f: TextureRect) -> void:
	_busy = true
	var start_pos : Vector2 = f.position
	var target_center : Vector2 = TARGET_POS + TARGET_SIZE / 2.0
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


func _on_round_complete() -> void:
	_target_rect.modulate.a = 1.0
	print("Level 1.5 Sound Quest round complete: ", _target_word, " (", _position, "=", _target_phoneme, ")")
	# Round-to-round advance / Quest Transition handoff not wired yet —
	# next build pass, mirroring Level 1 Sound Quest's own incremental order.


func _play_sfx(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
