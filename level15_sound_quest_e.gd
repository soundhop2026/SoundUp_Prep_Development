extends Node2D

# ─── Level 1.5 Sound Quest — Quest E (Build the Word) ──────────────────────
# Drag phoneme branches onto a ladder, bottom-to-top, to spell out the
# target word's own sound sequence. Unlike A/B/C/D, there is no
# "initial"/"final" split and no floor/ceiling on the pool — every one of
# the 130 words (all 4 structures, CVC through CCVCC) is fair game, and the
# correct branches are literally the target word's own ordered phonemes[].
#
# Layout (cube keyboard, redesigned 2026-11): target image top; a column of
# white rounded-rectangle "piano keys" on the left (one per phoneme, 2.5 px
# apart, no contour line) built from the existing cube artwork; bobbing pool
# of small white keys on the right (phonemes told apart only by tap-to-hear
# audio). Order is enforced live — only the current next-needed phoneme is
# ever accepted, dropped anywhere else (even a later-needed correct phoneme)
# bounces back, same idiom as Quest A/B's wrong-drop.
#
# Placement: a dragged key carries a soft shadow (white on white stays
# visible). When it lands on its slot (t = 0) the next Gayageum note of the
# five-note rising scale plays and, over 0.20 s, the key turns Emerald Mint and
# grows into the full-size key; its soft mint glow then stays on.
#
# Completion (no Play Button): once every key is placed, the phonemes play
# automatically bottom to top — the playing key's glow intensifies, the others
# stay softly lit, no Gayageum notes — then the whole word plays once while the
# whole keyboard glows brighter. Keys, glow, picture and the leftover pool keys
# then fade together (ROUND_FADE_DUR) and the next round starts.
# ─────────────────────────────────────────────────────────────────────────

const WORD_IMAGE_DIR : String = "res://SoundUp_level1.5_word_images/"
const WORD_AUDIO_DIR : String = "res://BGM&effect/SoundUp_level1.5_word_sounds/"
const CUBE_TEXTURE_PATH : String = "res://UI_assets/preplevel_set_counting_cube_empty.png"
# Quest E's own five rising Gayageum notes (E5 F#5 G#5 A5 B5), cut from the
# shared gayageum_correct.wav (which stays untouched for the other quests).
const NOTE_PATHS : Array[String] = [
	"res://BGM&effect/SoundUp_feedback/quest_e_gayageum_1_E5.wav",
	"res://BGM&effect/SoundUp_feedback/quest_e_gayageum_2_Fsharp5.wav",
	"res://BGM&effect/SoundUp_feedback/quest_e_gayageum_3_Gsharp5.wav",
	"res://BGM&effect/SoundUp_feedback/quest_e_gayageum_4_A5.wav",
	"res://BGM&effect/SoundUp_feedback/quest_e_gayageum_5_B5.wav",
]

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
var _branch_pool      : Array = []   # Array[Control], this round's bobbing pool keys
var _glow_layer       : Node2D = null  # soft glow copies, behind every key
var _key_layer        : Node2D = null  # the keyboard (one key per phoneme)
var _slot_keys        : Array = []   # Array[Control], keyboard keys, index 0 = bottom
var _slot_glows       : Array = []   # Array[Control], one glow group per key
var _glow_strength    : Array = []   # Array[float], current glow strength per key
var _glow_tweens      : Array = []   # Array[Tween], the running glow tween per key
var _cube_tex         : Texture2D = null

var _dragging     : bool = false
var _drag_branch  : Control = null
var _drag_offset  : Vector2 = Vector2.ZERO
var _drag_pos     : Vector2 = Vector2.ZERO
var _busy         : bool = false
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
	TARGET_POS.x  += _center_offset
	LADDER_X      += _center_offset
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

	_all_words = Level15SoundQuestState.load_words()
	_pool = Level15SoundQuestState.build_pool_e(_all_words)
	_all_phonemes = Level15SoundQuestState.load_phonemes()
	_schedule = Level15SoundQuestState.build_word_schedule(_pool, TOTAL_ROUNDS)

	_round_index = 0
	_start_round()


func _start_round() -> void:
	if not _play_counted:
		_play_counted = true
		if DebugConfig.debug_launch:
			DebugConfig.debug_launch = false
		else:
			SaveManager.increment_review_count("level15_soundquest_E")
	_busy = true
	_clear_round()

	_target_word = _schedule[_round_index]
	_target_phonemes = _all_words[_target_word]["phonemes"]
	_filled_count = 0

	_spawn_target_image()
	_spawn_keyboard()
	_spawn_branch_pool()
	_busy = false


func _clear_round() -> void:
	_dragging = false
	_drag_branch = null
	if _target_rect != null:
		_target_rect.queue_free()
		_target_rect = null
	for t in _glow_tweens:
		if t != null and t.is_valid():
			t.kill()
	_glow_tweens.clear()
	_slot_keys.clear()
	_slot_glows.clear()
	_glow_strength.clear()
	if _glow_layer != null:
		_glow_layer.queue_free()
		_glow_layer = null
	if _key_layer != null:
		_key_layer.queue_free()
		_key_layer = null
	for b in _branch_pool:
		var t : Tween = b.get_meta("bob_tween", null)
		if t != null and t.is_valid():
			t.kill()
		b.queue_free()
	_branch_pool.clear()


# ─── Target image ─────────────────────────────────────────────────────────

var TARGET_POS  : Vector2 = Vector2(560, 20)   # mobile-alignment fix — recentered in _ready()
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


# ─── Cube keyboard (replaces the old ladder rails + rung bars) ─────────────
# One white rounded-rectangle key per phoneme, stacked bottom to top on the
# same slot positions the ladder used (SLOT_HEIGHT pitch, so keys sit 2.5 px
# apart like piano keys), drawn from the existing cube artwork with a 9-slice
# so the corner radius stays round at any width. No contour line anywhere.

var LADDER_X          : float = 170.0   # mobile-alignment fix — recentered in _ready()
const SLOT_HEIGHT       : float = 76.0    # vertical space per key level
const LADDER_BASE_Y     : float = 580.0   # bottom edge of the keyboard

const KEY_SIZE      : Vector2 = Vector2(165.0, 73.5)    # 2.24 : 1, leaves a 2.5 px gap at the 76 px pitch
const KEY_EMPTY     : Color   = Color(1.0, 1.0, 1.0, 1.0)             # empty keys: pure white
const KEY_MINT      : Color   = Color("#20BFA9")                      # Emerald Mint
const GLOW_COLOR    : Color   = Color(0.58, 0.93, 0.85, 1.0)          # soft, lighter mint
# [extra px beyond the key edge, alpha at strength 1.0]: stacked low-alpha copies of the key shape
const GLOW_STEPS    : Array   = [[4.0, 0.20], [9.0, 0.16], [15.0, 0.12], [22.0, 0.085], [30.0, 0.055], [39.0, 0.03]]
const SHADOW_COLOR  : Color   = Color(0.30, 0.22, 0.10, 1.0)
const SHADOW_STEPS  : Array   = [[2.0, 0.10], [5.0, 0.075], [9.0, 0.05], [14.0, 0.03]]
const SHADOW_OFFSET : Vector2 = Vector2(0.0, 5.0)

const MERGE_DUR      : float = 0.20   # landed key -> full-size mint key
const GLOW_RAMP_DUR  : float = 0.20   # a key's glow stepping between strengths
const GLOW_SOFT      : float = 0.80   # every completed key
const GLOW_PLAYING   : float = 1.70   # the key whose phoneme is playing
const GLOW_WORD      : float = 1.25   # whole keyboard while the word plays

# The visible rounded square inside the 1254 px cube canvas (it is not centred in it).
const CUBE_SRC_RECT   : Rect2 = Rect2(185, 173, 872, 884)
const CUBE_SRC_MARGIN : int   = 160


# One rounded rectangle. The returned holder is an ordinary Control whose size/position are the VISIBLE
# rectangle, so hit-tests and tweens can use size and position as for any other Control; its single child
# draws the (scaled) 9-slice. center is in the parent's coordinates.
func _rrect(parent: Node, center: Vector2, w: float, h: float, color: Color) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := NinePatchRect.new()
	n.texture = _cube_tex
	n.region_rect = CUBE_SRC_RECT
	n.patch_margin_left = CUBE_SRC_MARGIN
	n.patch_margin_right = CUBE_SRC_MARGIN
	n.patch_margin_top = CUBE_SRC_MARGIN
	n.patch_margin_bottom = CUBE_SRC_MARGIN
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.modulate = color
	holder.add_child(n)
	parent.add_child(holder)
	_rrect_set(holder, center, w, h)
	return holder


func _rrect_set(holder: Control, center: Vector2, w: float, h: float) -> void:
	var n := holder.get_child(0) as NinePatchRect
	var k : float = h / CUBE_SRC_RECT.size.y
	holder.size = Vector2(w, h)
	holder.position = center - Vector2(w, h) / 2.0
	n.scale = Vector2(k, k)
	n.size = Vector2(w / k, CUBE_SRC_RECT.size.y)


func _rrect_color(holder: Control, color: Color) -> void:
	(holder.get_child(0) as CanvasItem).modulate = color


# Center position of the level-i key slot (0 = bottom).
func _rung_slot_center(level: int) -> Vector2:
	var y : float = LADDER_BASE_Y - (level + 0.5) * SLOT_HEIGHT
	return Vector2(LADDER_X, y)


func _spawn_keyboard() -> void:
	if _cube_tex == null:
		_cube_tex = load(CUBE_TEXTURE_PATH)
	_glow_layer = Node2D.new()
	_glow_layer.z_index = 1
	add_child(_glow_layer)
	_key_layer = Node2D.new()
	_key_layer.z_index = 2
	add_child(_key_layer)
	for i in range(_target_phonemes.size()):
		var center : Vector2 = _rung_slot_center(i)
		_slot_keys.append(_rrect(_key_layer, center, KEY_SIZE.x, KEY_SIZE.y, KEY_EMPTY))
		# the glow group exists from the start (invisible at strength 0), drawn behind all keys
		var g := Control.new()
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glow_layer.add_child(g)
		for s in GLOW_STEPS:
			var c : Color = GLOW_COLOR
			c.a = 0.0
			_rrect(g, center, KEY_SIZE.x + 2.0 * s[0], KEY_SIZE.y + 2.0 * s[0], c)
		_slot_glows.append(g)
		_glow_strength.append(0.0)
		_glow_tweens.append(null)


func _set_glow(i: int, strength: float) -> void:
	if i >= _slot_glows.size() or not is_instance_valid(_slot_glows[i]):
		return
	_glow_strength[i] = strength
	var g : Control = _slot_glows[i]
	for j in range(GLOW_STEPS.size()):
		var c : Color = GLOW_COLOR
		c.a = GLOW_STEPS[j][1] * strength
		_rrect_color(g.get_child(j), c)


# Ramp key i's glow to `target`; any ramp already running on that key is replaced.
func _tween_glow(i: int, target: float) -> void:
	if i >= _glow_tweens.size():
		return
	var old : Tween = _glow_tweens[i]
	if old != null and old.is_valid():
		old.kill()
	var tw := create_tween()
	_glow_tweens[i] = tw
	tw.tween_method(func(s: float) -> void: _set_glow(i, s), float(_glow_strength[i]), target, GLOW_RAMP_DUR)


# Soft drop shadow that makes the white dragged key visible over the white keyboard.
# A child of the key (drawn behind it), laid out in the key's own coordinates.
func _add_shadow(piece: Control) -> void:
	if piece.has_meta("shadow"):
		return
	var g := Control.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.show_behind_parent = true
	piece.add_child(g)
	for s in SHADOW_STEPS:
		_rrect(g, Vector2.ZERO, 1.0, 1.0, Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, 0.0))
	piece.set_meta("shadow", g)
	_layout_shadow(piece, 1.0)


func _layout_shadow(piece: Control, strength: float) -> void:
	var g : Control = piece.get_meta("shadow", null)
	if g == null or not is_instance_valid(g):
		return
	var center : Vector2 = piece.size / 2.0 + SHADOW_OFFSET
	for j in range(SHADOW_STEPS.size()):
		var grow : float = SHADOW_STEPS[j][0]
		var holder : Control = g.get_child(j)
		_rrect_set(holder, center, piece.size.x + 2.0 * grow, piece.size.y + 2.0 * grow)
		_rrect_color(holder, Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, SHADOW_STEPS[j][1] * strength))


func _remove_shadow(piece: Control) -> void:
	var g : Control = piece.get_meta("shadow", null)
	if g != null and is_instance_valid(g):
		g.queue_free()
	piece.remove_meta("shadow")


# ─── Branch pool (correct keys, one per target phoneme occurrence, + ────────
# ─── distractors, 12 total per round) ───────────────────────────────────────

const PIECE_SIZE    : Vector2 = Vector2(108, 48)   # small white key, same proportions as the keyboard keys
const BRANCH_TOTAL  : int     = 12
var POOL_CENTER       : Vector2 = Vector2(870, 420)   # mobile-alignment fix — recentered in _ready()
const POOL_HALF_EXTENTS : Vector2 = Vector2(330, 230)
const MIN_GAP_X    : float = 14.0   # keys are wider than tall, so spacing is checked per axis, not by distance
const MIN_GAP_Y    : float = 22.0   # (includes the +-5 px bob)
const MAX_ATTEMPTS : int   = 200

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

	if _cube_tex == null:
		_cube_tex = load(CUBE_TEXTURE_PATH)
	var placed : Array = []
	for entry in entries:
		var center : Vector2 = _pick_pool_center(placed)
		placed.append(center)
		var r : Control = _rrect(self, center, PIECE_SIZE.x, PIECE_SIZE.y, KEY_EMPTY)
		r.z_index = 3                       # above the keyboard (and its glow)
		r.set_meta("base_pos", r.position)
		r.set_meta("phoneme", entry["phoneme"])
		r.set_meta("correct", entry["correct"])
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
			if absf(candidate.x - p.x) < PIECE_SIZE.x + MIN_GAP_X and absf(candidate.y - p.y) < PIECE_SIZE.y + MIN_GAP_Y:
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

# Generous vertical strip covering the keyboard (at any of its 3-5 keys) —
# dropping anywhere in it counts as "placing on the keyboard."
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
		var b : Control = _branch_pool[i]
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
			_add_shadow(b)
			var ph : String = String(b.get_meta("phoneme"))
			_play_sfx(String(_all_phonemes[ph]["audio"]))
			return


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	var b : Control = _drag_branch
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


func _on_correct_drop(b: Control) -> void:
	_busy = true
	_branch_pool.erase(b)
	var old_bob : Tween = b.get_meta("bob_tween", null)
	if old_bob != null and old_bob.is_valid():
		old_bob.kill()

	var slot_index : int = _filled_count
	var slot_center : Vector2 = _rung_slot_center(slot_index)
	var hop := create_tween()
	hop.tween_property(b, "position", slot_center - b.size / 2.0, 0.25) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await hop.finished

	# t = 0: the key has landed on its slot. The next note of the rising scale
	# plays now and the key merges into the keyboard.
	var note : AudioStreamPlayer = _play_sfx(NOTE_PATHS[mini(slot_index, NOTE_PATHS.size() - 1)])
	_filled_count += 1
	var merge : Tween = _merge_key(b, slot_index)

	if _filled_count >= _target_phonemes.size():
		await merge.finished
		await _on_round_complete_sequence(note)
	else:
		_busy = false


# Landed key -> full-size Emerald Mint key over MERGE_DUR: the colour change, the
# growth (ease-out cubic) and the glow (building to its soft level) all start at t = 0,
# and the drag shadow lifts away. The keyboard key underneath takes over at the end.
func _merge_key(piece: Control, slot_index: int) -> Tween:
	var center : Vector2 = _rung_slot_center(slot_index)
	var start_size : Vector2 = piece.size
	var tw := create_tween()
	tw.tween_method(func(e: float) -> void:
		if not is_instance_valid(piece):
			return
		var grown : float = 1.0 - pow(1.0 - e, 3.0)       # ease-out cubic
		var tint : float = 1.0 - pow(1.0 - e, 2.0)        # white -> mint, starting exactly at t = 0
		var sz : Vector2 = start_size.lerp(KEY_SIZE, grown)
		_rrect_set(piece, center, sz.x, sz.y)
		_rrect_color(piece, KEY_EMPTY.lerp(KEY_MINT, tint))
		_layout_shadow(piece, 1.0 - e)
		_set_glow(slot_index, GLOW_SOFT * grown * grown),
		0.0, 1.0, MERGE_DUR)
	tw.tween_callback(func() -> void:
		if slot_index < _slot_keys.size() and is_instance_valid(_slot_keys[slot_index]):
			_rrect_color(_slot_keys[slot_index], KEY_MINT)
		_set_glow(slot_index, GLOW_SOFT)
		if is_instance_valid(piece):
			piece.queue_free())
	return tw


# Same resist-twice-bounce-back idiom as Quest A/B — a mismatch (wrong
# phoneme OR a correct-word phoneme presented out of turn) is rejected
# outright, no partial credit, no destination reached.
func _on_wrong_drop(b: Control) -> void:
	_busy = true
	_remove_shadow(b)
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


func _on_drop_empty_space(b: Control) -> void:
	_busy = true
	_remove_shadow(b)
	var base_pos : Vector2 = b.get_meta("base_pos")
	var glide := create_tween()
	glide.tween_property(b, "position", base_pos, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await glide.finished
	_resume_bob(b)
	_busy = false


func _resume_bob(b: Control) -> void:
	var t : Tween = b.get_meta("bob_tween", null)
	if t != null and t.is_valid():
		t.play()


# ─── Round-complete: automatic phoneme playback -> the whole word -> fade ───
# Everything here waits on the sounds themselves (their `finished` signals), never
# on fixed delays. Input stays locked (_busy) for the whole sequence.

# A sound that was stopped (entitlement loss stops all audio) never emits `finished`;
# the scene is leaving anyway, so that coroutine simply never resumes.
func _await_sound(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player) or not player.playing:
		return
	await player.finished


func _sequence_aborted() -> bool:
	return _entitlement_interrupted or not is_inside_tree()


func _on_round_complete_sequence(last_note: AudioStreamPlayer) -> void:
	# 1. let the last key's Gayageum note finish, so the first phoneme never overlaps it
	await _await_sound(last_note)
	if _sequence_aborted():
		return

	# 2. phonemes, bottom key to top key; no Gayageum notes here
	var n : int = _target_phonemes.size()
	for i in range(n):
		_tween_glow(i, GLOW_PLAYING)
		var ph_player : AudioStreamPlayer = _play_sfx(String(_all_phonemes[_target_phonemes[i]]["audio"]))
		await _await_sound(ph_player)
		if _sequence_aborted():
			return
		if i < n - 1:
			_tween_glow(i, GLOW_SOFT)

	# 3. the whole word, once, with the whole keyboard glowing brighter until it ends
	for i in range(n):
		_tween_glow(i, GLOW_WORD)
	var word_player : AudioStreamPlayer = _play_sfx(WORD_AUDIO_DIR + _target_word + ".wav")
	await _await_sound(word_player)
	if _sequence_aborted():
		return

	# 4. fade everything out together and go on to the next round
	await _on_round_complete()


const ROUND_FADE_DUR : float = 0.3

# Locked: Quest E = 10 Sets x 10 rounds = 100 rounds.
const ROUNDS_PER_SET : int = 10
const TOTAL_ROUNDS    : int = 100

func _on_round_complete() -> void:
	# Keyboard, glow, target picture and the leftover pool keys fade out together.
	var t := create_tween()
	t.set_parallel(true)
	for node in [_key_layer, _glow_layer, _target_rect]:
		if node != null and is_instance_valid(node):
			t.tween_property(node, "modulate:a", 0.0, ROUND_FADE_DUR)
	for b in _branch_pool:
		if is_instance_valid(b):
			t.tween_property(b, "modulate:a", 0.0, ROUND_FADE_DUR)
	await t.finished
	if _sequence_aborted():
		return

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
	# Sound Quest is optional bonus content — Quest E's completion has no
	# effect on any progression. Returns to Where Am I; the player picks
	# another Sound Quest from there rather than auto-chaining into Quest F.
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
	if _dragging and _drag_branch != null and is_instance_valid(_drag_branch):
		var b : Control = _drag_branch
		_dragging    = false
		_drag_branch = null
		_on_drop_empty_space(b)
	else:
		_dragging    = false
		_drag_branch = null


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


# Returns the player (null if the file is missing) so callers can await `finished`.
func _play_sfx(path: String) -> AudioStreamPlayer:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player
