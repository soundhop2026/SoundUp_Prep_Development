extends Node2D

# ─── Level 1.5 Sound Quest — Quest C / Quest D ─────────────────────────────
# One shared implementation for both Initial Isolation (Quest C) and Final
# Isolation (Quest D) — identical mechanic, differing only in which word
# field drives the target ("initial" vs "final") and the phoneme-frequency
# scaling. Set via Level15SoundQuestCDState before this scene loads.
#
# Round: a target image (top) shows a word whose initial/final sound is this
# round's target phoneme — tap it anytime to hear the word. Play Button sits
# below it — tap anytime to hear the target phoneme in isolation (resolves
# the initial-vs-final ambiguity a raw word can't). Below both, 20 phoneme
# bubbles continuously rise from the bottom of the gameplay field and loop
# back before ever reaching Play Button — a single reusable bubble texture,
# phonemes told apart only by tap-to-hear audio (locked "no letters" rule,
# same as Level 1's bins and Quest A/B's word-audio pattern). Drag a bubble
# matching the target phoneme onto Play Button to pop it — the phoneme's own
# audio is the correct-feedback, no separate chime — and a fresh bubble rises
# from below to keep the field populated. A wrong drag silently bumps away
# and keeps rising, never destroyed. Round ends once target_count matching
# bubbles have been popped, then Quest C/D's own signature ending plays:
# both breathe together, Play Button suddenly hops onto the target image's
# head, the image gives a tiny surprised squash and recovers, then happily
# carries Play Button off in a waddling walk — deliberately its own gag,
# distinct from Quest F's rolling exit.
# ─────────────────────────────────────────────────────────────────────────

const BUBBLE_TEXTURE_PATH     : String = "res://soundquest/assets/bubble_level15_soundquest_C_D.png"
const PLAYBUTTON_TEXTURE_PATH : String = "res://UI_assets/playbutton.png"
const WORD_IMAGE_DIR          : String = "res://SoundUp_level1.5_word_images/"
const WORD_AUDIO_DIR          : String = "res://BGM&effect/SoundUp_level1.5_word_sounds/"

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
var _target_word     : String = ""
var _target_count   : int    = 0
var _collected      : int    = 0

var _target_rect      : TextureRect = null
var _tip_landing_pos  : Vector2 = Vector2.ZERO   # this round's image-specific landing spot for the celebration jump
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

	var candidates : Array = Level15SoundQuestState.words_for_phoneme(_all_words, _pool, _position, _target_phoneme)
	_target_word = candidates[randi() % candidates.size()]

	_spawn_target_image()
	_spawn_playbutton()
	_spawn_bubbles()
	_busy = false


func _clear_round() -> void:
	_dragging = false
	_drag_bubble = null
	if _target_rect != null:
		_target_rect.queue_free()
		_target_rect = null
	if _playbutton_rect != null:
		_playbutton_rect.queue_free()
		_playbutton_rect = null
	for b in _bubbles:
		b.queue_free()
	_bubbles.clear()


# ─── Target image (top) — tap anytime to hear the target word ──────────────

const TARGET_POS  : Vector2 = Vector2(565, 50)   # pulled down from y=20 for top breathing room
const TARGET_SIZE : Vector2 = Vector2(150, 120)

func _spawn_target_image() -> void:
	var tex : Texture2D = load(WORD_IMAGE_DIR + _target_word + ".png")
	_target_rect = TextureRect.new()
	_target_rect.texture = tex
	_target_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_rect.size = TARGET_SIZE
	_target_rect.pivot_offset = TARGET_SIZE / 2.0
	_target_rect.position = TARGET_POS
	add_child(_target_rect)

	_tip_landing_pos = _find_tip_landing_pos(tex)


# Scans the actual loaded image for its topmost non-transparent pixels (e.g.
# a mop's handle tip, not just its bounding-box center) so the celebration
# landing spot fits whatever this round's word image actually looks like,
# rather than one fixed spot that only suits roundish/centered images. Falls
# back to bounding-box center-top if the texture's pixel data isn't readable.
const TIP_ROW_SAMPLE_HEIGHT : int   = 6      # average x across this many rows below the topmost hit, for a stable center rather than one stray pixel
const ALPHA_THRESHOLD       : float = 0.05

func _find_tip_landing_pos(tex: Texture2D) -> Vector2:
	var fallback : Vector2 = Vector2(TARGET_POS.x + TARGET_SIZE.x / 2.0, TARGET_POS.y)

	var img : Image = tex.get_image()
	if img == null:
		return fallback
	img.convert(Image.FORMAT_RGBA8)
	var tw : int = img.get_width()
	var th : int = img.get_height()

	var top_row : int = -1
	for y in range(th):
		for x in range(tw):
			if img.get_pixel(x, y).a > ALPHA_THRESHOLD:
				top_row = y
				break
		if top_row != -1:
			break
	if top_row == -1:
		return fallback

	var xs : Array = []
	var bottom_sample_row : int = mini(top_row + TIP_ROW_SAMPLE_HEIGHT, th - 1)
	for y in range(top_row, bottom_sample_row + 1):
		for x in range(tw):
			if img.get_pixel(x, y).a > ALPHA_THRESHOLD:
				xs.append(x)
	var tip_px_x : float = 0.0
	for x in xs:
		tip_px_x += x
	tip_px_x /= xs.size()

	# Map the source-pixel tip through STRETCH_KEEP_ASPECT_CENTERED's own
	# scale + letterbox math to find where it actually renders inside TARGET_SIZE.
	var scale : float = min(TARGET_SIZE.x / float(tw), TARGET_SIZE.y / float(th))
	var rendered_size : Vector2 = Vector2(tw, th) * scale
	var letterbox_offset : Vector2 = (TARGET_SIZE - rendered_size) / 2.0
	var local_tip : Vector2 = letterbox_offset + Vector2(tip_px_x, top_row) * scale
	return TARGET_POS + local_tip


# ─── Play Button (below target image) — tap anytime to hear the phoneme ────

const PLAYBUTTON_POS  : Vector2 = Vector2(565, 180)   # shifted down with TARGET_POS, same 10px gap preserved
const PLAYBUTTON_SIZE : Vector2 = Vector2(150, 72)

func _spawn_playbutton() -> void:
	var tex : Texture2D = load(PLAYBUTTON_TEXTURE_PATH)
	_playbutton_rect = TextureRect.new()
	_playbutton_rect.texture = tex
	_playbutton_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_playbutton_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_playbutton_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playbutton_rect.size = PLAYBUTTON_SIZE
	_playbutton_rect.pivot_offset = PLAYBUTTON_SIZE / 2.0
	_playbutton_rect.position = PLAYBUTTON_POS
	add_child(_playbutton_rect)


# ─── Rising bubble field ──────────────────────────────────────────────────

const BUBBLE_SIZE     : Vector2 = Vector2(70, 60)
const BUBBLE_COUNT    : int     = 20
const FIELD_X_MIN     : float   = 60.0
const FIELD_X_MAX     : float   = 950.0
const FIELD_TOP_Y     : float   = 330.0   # below Play Button's bottom edge (180+72=252) with the same 78px safety buffer
const FIELD_BOTTOM_Y  : float   = 700.0
const RISE_SPEED      : float   = 20.0   # px/sec

func _make_bubble(phoneme: String) -> TextureRect:
	var tex : Texture2D = load(BUBBLE_TEXTURE_PATH)
	var b := TextureRect.new()
	b.texture = tex
	b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.size = BUBBLE_SIZE
	b.pivot_offset = BUBBLE_SIZE / 2.0
	b.set_meta("phoneme", phoneme)
	b.set_meta("correct", phoneme == _target_phoneme)
	return b


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

	for ph in entries:
		var b := _make_bubble(ph)
		var center : Vector2 = Vector2(randf_range(FIELD_X_MIN, FIELD_X_MAX), randf_range(FIELD_TOP_Y, FIELD_BOTTOM_Y))
		b.position = center - b.pivot_offset
		add_child(b)
		_bubbles.append(b)


# A popped correct bubble is replaced by a fresh distractor rising from the
# bottom, so the field stays visually populated without ever exceeding the
# round's target_count of collectible bubbles.
func _spawn_replacement_bubble() -> void:
	var phoneme : String = Level15SoundQuestState.cd_build_distractor_phonemes(_all_phonemes, _target_phoneme, 1)[0]
	var b := _make_bubble(phoneme)
	var center : Vector2 = Vector2(randf_range(FIELD_X_MIN, FIELD_X_MAX), FIELD_BOTTOM_Y)
	b.position = center - b.pivot_offset
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
	if Rect2(TARGET_POS, TARGET_SIZE).has_point(pos):
		_play_sfx(WORD_AUDIO_DIR + _target_word + ".wav")
		return
	if Rect2(PLAYBUTTON_POS, PLAYBUTTON_SIZE).has_point(pos):
		_play_target_audio()
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


const POP_DUR   : float = 0.14
const POP_SCALE : float = 1.35

# Correct drop: the bubble pops (quick scale + fade) right where it landed —
# the target phoneme's own audio IS the success feedback, no separate chime.
# It's removed and replaced by a fresh distractor rising from the bottom, so
# the field never visibly thins out over the round.
func _on_correct_drop(b: TextureRect) -> void:
	_busy = true
	_bubbles.erase(b)

	_play_target_audio()

	var pop := create_tween()
	pop.set_parallel(true)
	pop.tween_property(b, "scale", Vector2.ONE * POP_SCALE, POP_DUR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop.tween_property(b, "modulate:a", 0.0, POP_DUR)
	await pop.finished
	b.queue_free()

	_collected += 1

	if _collected >= _target_count:
		_busy = false
		_on_round_complete()
	else:
		_spawn_replacement_bubble()
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
const WALK_OFF_X          : float = 1450.0   # reuses Quest F's exit-off-viewport value

# Reuses Level 1 Sound Quest's exact Bin-breathing values.
const BREATHE_SCALE          : Vector2 = Vector2(1.08, 1.08)
const BREATHE_DUR            : float   = 0.6
const CELEBRATE_BREATHE_COUNT : int    = 3

# Quest C/D's own signature ending (deliberately distinct from Quest F's
# rolling exit): Play Button hops onto the target image's head, the image
# reacts with a tiny squash, then carries Play Button off with a happy waddle.
const JUMP_UP_DUR    : float = 0.6    # slowed from 0.35 — landing hop shouldn't be a blink-and-miss-it flash
const SQUASH_DUR         : float   = 0.12
const SQUASH_SCALE       : Vector2 = Vector2(1.08, 0.85)
const SQUASH_RECOVER_DUR : float   = 0.18
const WADDLE_DUR         : float   = 2.4    # slowed from 1.3 (Quest F's original waddle pace) — a slower exit reads better here
const WADDLE_SWAY        : float   = 14.0   # reused from Quest F's waddle-exit tier

# Locked 2026-08-06: Quest C/D = 4 Sets x 14 rounds = 56 rounds each.
const ROUNDS_PER_SET : int = 14

func _on_round_complete() -> void:
	_busy = true

	await get_tree().create_timer(ROUND_COMPLETE_HOLD).timeout
	await _breathe_both(CELEBRATE_BREATHE_COUNT)
	await _playbutton_jump_onto_target()
	await _target_squash_bounce()
	await _ride_off_together()
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


# 1. Target image + Play Button breathe together, celebrating — same scale
# idiom as Level 1 Sound Quest's Bin breathing (BREATHE_SCALE/DUR reused).
func _breathe_both(times: int) -> void:
	for _i in range(times):
		var up := create_tween()
		up.set_parallel(true)
		up.tween_property(_target_rect, "scale", BREATHE_SCALE, BREATHE_DUR) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		up.tween_property(_playbutton_rect, "scale", BREATHE_SCALE, BREATHE_DUR) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await up.finished

		var down := create_tween()
		down.set_parallel(true)
		down.tween_property(_target_rect, "scale", Vector2.ONE, BREATHE_DUR) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		down.tween_property(_playbutton_rect, "scale", Vector2.ONE, BREATHE_DUR) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await down.finished
	_target_rect.scale = Vector2.ONE
	_playbutton_rect.scale = Vector2.ONE


# 2. Without warning, Play Button hops up and lands on the target image's
# actual topmost point (this round's _tip_landing_pos — a mop's handle tip,
# a pump's spout, etc.), with playbutton.png's own *visible face content*
# bottom-anchored there (not its padded bounding box — measured headlessly:
# the face content stops at 350/437 = 80.1% of the texture's height, ~20%
# transparent padding below it, same padding quirk already known from this
# asset's Word Cloud/decoy-matching work).
const PLAYBUTTON_CONTENT_BOTTOM_FRAC : float = 350.0 / 437.0
const TIP_SIT_OVERLAP                : float = 6.0   # halfway between 0 (balanced at the edge) and 12 (too deep) — sits on the tip without swallowing it

func _playbutton_jump_onto_target() -> void:
	var content_bottom_offset : float = PLAYBUTTON_SIZE.y * PLAYBUTTON_CONTENT_BOTTOM_FRAC
	var land_pos : Vector2 = _tip_landing_pos - Vector2(PLAYBUTTON_SIZE.x / 2.0, content_bottom_offset)
	land_pos.y += TIP_SIT_OVERLAP
	land_pos.y = max(land_pos.y, 0.0)   # stay clear of the canvas top edge, same safety net as before
	var jump := create_tween()
	jump.tween_property(_playbutton_rect, "position", land_pos, JUMP_UP_DUR) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await jump.finished


# 3. Target image reacts to the landing — a tiny squash, then it recovers,
# playful rather than strained (it's happy to give the ride).
func _target_squash_bounce() -> void:
	var squash := create_tween()
	squash.tween_property(_target_rect, "scale", SQUASH_SCALE, SQUASH_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	squash.tween_property(_target_rect, "scale", Vector2.ONE, SQUASH_RECOVER_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await squash.finished


# 4. Play Button rides along — reparented onto the target image so it moves
# as part of the image's own transform, staying visually attached — and the
# pair waddles off together (same WADDLE_SWAY/DUR idiom as Quest F's waddle
# tier, applied to the carrying image).
func _ride_off_together() -> void:
	var local_offset : Vector2 = _playbutton_rect.position - _target_rect.position
	remove_child(_playbutton_rect)
	_target_rect.add_child(_playbutton_rect)
	_playbutton_rect.position = local_offset

	var walk := create_tween()
	walk.tween_property(_target_rect, "position:x", WALK_OFF_X, WADDLE_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	var sway := create_tween()
	sway.set_loops(6)
	sway.tween_property(_target_rect, "rotation_degrees", WADDLE_SWAY, WADDLE_DUR / 12.0)
	sway.tween_property(_target_rect, "rotation_degrees", -WADDLE_SWAY, WADDLE_DUR / 6.0)
	sway.tween_property(_target_rect, "rotation_degrees", 0.0, WADDLE_DUR / 12.0)

	await walk.finished
	sway.kill()
	_target_rect.rotation_degrees = 0.0


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


func _play_target_audio() -> void:
	_play_sfx(String(_all_phonemes[_target_phoneme]["audio"]))


func _play_sfx(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
