extends Node2D

# ─── Level 1 Sound Quest ────────────────────────────────────────────────────
# Two phases in one scene, mirroring how Prep's sound_quest.gd holds both its
# round gameplay and its own Quest Transition in a single script:
#
#   ROUNDS phase: a Word Cloud of generic Louis faces (every word looks
#   identical — louisfaces/happylouis3-Photoroom.png; a word's identity is
#   sound-only, no letters, no per-word picture) gets sorted by drag into 4
#   rotating phoneme Bins (phoneme_bin_level1_soundquest.png, also generic —
#   told apart only by tapping to hear the phoneme). A Group's word pool,
#   once bigger than ~60 words, splits into phoneme-balanced chunks
#   (SoundQuestState.split_pool_by_phoneme_balanced) so no single Word Cloud
#   ever shows an unmanageable number of faces — see
#   Level1SoundQuestState.QUEST_COUNTS_BY_GROUP for the per-Group
#   chunk-count/Quest-count mapping this produces.
#
#   TRANSITION phase (already built, reused as-is): a "find the Play Button"
#   hidden-object hunt among decoy Louis faces — plays after every Quest's
#   14th Round, per the flow: Sound Quest -> Transition -> next Quest (or
#   next Group, after the Group's last Quest).
#
# Reachable via DEBUG -> Demo Shortcuts: one shortcut launches the full
# Rounds-from-scratch flow for Group A, another plays the standalone
# Transition only (isolated preview).
# ─────────────────────────────────────────────────────────────────────────

const FONT_PATH : String = "res://UI_assets/210 연필스케치R.ttf"
const BG_COLOR  : Color  = Color(0.431, 0.710, 1.0, 1.0)   # sky blue — matches Level 1's game.gd, not Prep's green

const LOUIS_TEXTURE_PATH : String = "res://louisfaces/happylouis3-Photoroom.png"
const REAL_TEXTURE_PATH  : String = "res://UI_assets/playbutton.png"
const BIN_TEXTURE_PATH   : String = "res://soundquest/assets/phoneme_bin_level1_soundquest.png.png"
const MUSIC_PATH          : String = "res://soundquest/assets/quest_level1_bgm.mp3"
const GAYAGEUM_CORRECT_PATH : String = "res://BGM&effect/SoundUp_feedback/gayageum_correct.wav"

var _font : Font = null


# ═══════════════════════════════════════════════════════════════════════════
# ROUNDS PHASE
# ═══════════════════════════════════════════════════════════════════════════

const POOL_PAD_TARGET   : int = 56   # Groups smaller than this get padded up
const CHUNK_SIZE_TARGET : int = 60   # Groups bigger than this split into chunks this size or smaller
const ROUNDS_PER_QUEST  : int = 14
const BINS_PER_ROUND    : int = 4

# ─── Word Cloud layout ──────────────────────────────────────────────────────
const CLOUD_CENTER       : Vector2 = Vector2(640, 280)
const CLOUD_HALF_EXTENTS : Vector2 = Vector2(600, 190)   # leaves room below for the Bin row
const CLOUD_FACE_SCALE   : Vector2 = Vector2(0.085, 0.085)   # smaller than the Transition's decoys — up to 178 faces need to fit at once
const CLOUD_MIN_SPACING  : float = 42.0
const CLOUD_MAX_ATTEMPTS : int = 30

const CLOUD_BOB_AMPLITUDE : float = 6.0
const CLOUD_BOB_HALF_DUR  : float = 0.3

# ─── Bin layout ─────────────────────────────────────────────────────────────
# The bin PNG's drawn cup only fills a small part of its canvas (content
# ~495x410px out of a 1536x1024 canvas — the same kind of padding we hit
# with playbutton.png earlier this session), so a naive scale bump barely
# moves the VISIBLE size even though the bounding box grows a lot. Scaled
# so the visible cup itself is genuinely ~2x its previous size.
const BIN_ROW_Y        : float = 615.0
const BIN_SCALE        : Vector2 = Vector2(0.4, 0.4)
const BIN_X_POSITIONS  : Array[float] = [220.0, 520.0, 800.0, 1100.0]

var _group_number   : int   = 0
var _group_chunks   : Array = []   # Array[Array] — each chunk is a pool (Array of word dicts)
var _quest_count    : int   = 4
var _quest_index    : int   = 0
var _quest_pool     : Array = []
var _quest_phonemes : Array = []
var _round_schedule : Array = []
var _round_index    : int   = 0

var _cloud_faces : Array = []   # Array[TextureRect], this round's Word Cloud
var _bins        : Array = []   # Array[Dictionary] {node: TextureRect, phoneme, phoneme_audio, collected, target_count, breathing}
var _busy        : bool  = false   # guards input during round-complete fade / drag resolution


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

	_setup_group()
	_quest_index = 0
	if Level1SoundQuestState.debug_skip_to_transition:
		Level1SoundQuestState.debug_skip_to_transition = false
		_play_quest_transition()
	else:
		_start_quest()


# Builds this Group's complete word pool (once), pads it up if it's small,
# and splits it into phoneme-balanced chunks if it's big — see
# sound_quest_state.gd's split_pool_by_phoneme_balanced() for why chunks
# are split by whole phoneme, never mid-phoneme.
func _setup_group() -> void:
	_group_number = 0
	for i in range(LevelProgress.MAIN_SET_BOUNDARIES.size()):
		if Level1SoundQuestState.group_start_index <= LevelProgress.MAIN_SET_BOUNDARIES[i]:
			_group_number = i
			break

	var json_paths : Array = LevelProgress.sets.slice(
		Level1SoundQuestState.group_start_index, Level1SoundQuestState.group_end_index + 1)
	var raw_pool    : Array = SoundQuestState.build_word_pool(json_paths)
	var padded_pool : Array = SoundQuestState.pad_pool_to_size(raw_pool, POOL_PAD_TARGET)
	_group_chunks = SoundQuestState.split_pool_by_phoneme_balanced(padded_pool, CHUNK_SIZE_TARGET)
	_quest_count  = Level1SoundQuestState.quest_count_for_group(_group_number)


# Quest N uses chunk (N mod chunk_count) — cycles back to the first chunk
# once every chunk has had a turn (e.g. Group D: 2 chunks x 4 replays each
# = 8 Quests; Group F: 3 chunks x 1 turn each = 3 Quests).
func _start_quest() -> void:
	if _quest_index >= _quest_count:
		_on_all_quests_complete()
		return

	_quest_pool     = _group_chunks[_quest_index % _group_chunks.size()]
	_quest_phonemes = SoundQuestState.phonemes_in_pool(_quest_pool)
	_round_schedule = SoundQuestState.build_round_schedule(_quest_phonemes, ROUNDS_PER_QUEST, BINS_PER_ROUND)
	_round_index    = 0
	_start_round()


const ROUND_FADE_DUR : float = 0.5

# Fully self-contained: nothing carries over from the previous Round. Fresh
# Word Cloud (every word in this Quest's pool) + fresh 4 Bins (this Round's
# active phonemes from the schedule) every time, fading in — a plain fade,
# no sound, so a fresh Round never reads as a jump-cut glitch.
func _start_round() -> void:
	_busy = true
	_clear_round()
	_spawn_word_cloud()
	_spawn_bins(_round_schedule[_round_index])

	for f in _cloud_faces:
		f.modulate.a = 0.0
	for b in _bins:
		b["node"].modulate.a = 0.0

	var fade := create_tween()
	fade.set_parallel(true)
	for f in _cloud_faces:
		fade.tween_property(f, "modulate:a", 1.0, ROUND_FADE_DUR)
	for b in _bins:
		fade.tween_property(b["node"], "modulate:a", 1.0, ROUND_FADE_DUR)
	await fade.finished
	_busy = false


# Plain fade — no sound, no fanfare — everything from the completed Round
# fades away together before the next one is built.
func _fade_out_round() -> void:
	var fade := create_tween()
	fade.set_parallel(true)
	var any : bool = false
	for f in _cloud_faces:
		if is_instance_valid(f):
			fade.tween_property(f, "modulate:a", 0.0, ROUND_FADE_DUR)
			any = true
	for b in _bins:
		if is_instance_valid(b["node"]):
			fade.tween_property(b["node"], "modulate:a", 0.0, ROUND_FADE_DUR)
			any = true
	if any:
		await fade.finished


func _clear_round() -> void:
	_dragging  = false
	_drag_face = null
	for f in _cloud_faces:
		var t : Tween = f.get_meta("bob_tween", null)
		if t != null and t.is_valid():
			t.kill()
		f.queue_free()
	_cloud_faces.clear()
	for b in _bins:
		var bt : Tween = b["node"].get_meta("breathe_tween", null)
		if bt != null and bt.is_valid():
			bt.kill()
		b["node"].queue_free()
	_bins.clear()


# ─── Word Cloud ──────────────────────────────────────────────────────────────

func _spawn_word_cloud() -> void:
	var louis_tex : Texture2D = load(LOUIS_TEXTURE_PATH)
	var tex_size  : Vector2   = louis_tex.get_size() * CLOUD_FACE_SCALE

	var placed_centers : Array = []
	for w in _quest_pool:
		# Plain TextureRect, not TextureButton — drag needs raw scene-level
		# input handling (same pattern as game15.gd's sound-count drag), so
		# a Button's own click detection would just be redundant/conflicting.
		var rect := TextureRect.new()
		rect.texture      = louis_tex
		rect.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE   # hit-testing is manual Rect2 checks, not GUI dispatch
		rect.size         = tex_size
		rect.pivot_offset = tex_size / 2.0

		var center : Vector2 = _pick_cloud_center(placed_centers)
		placed_centers.append(center)
		rect.position = center - rect.pivot_offset
		rect.set_meta("base_pos", rect.position)
		rect.set_meta("word", w)

		add_child(rect)
		_cloud_faces.append(rect)
		_start_cloud_bob(rect)


# Same rejection-sampled placement proven for the Transition's crowd — not
# a grid, natural overlap is fine and intentional (a lively "wagle-wagle"
# crowd, not evenly spaced), just guards against two faces landing almost
# exactly on top of each other.
func _pick_cloud_center(placed_centers: Array) -> Vector2:
	var candidate : Vector2 = CLOUD_CENTER
	for _attempt in range(CLOUD_MAX_ATTEMPTS):
		candidate = CLOUD_CENTER + Vector2(
			randf_range(-1.0, 1.0) * CLOUD_HALF_EXTENTS.x,
			randf_range(-1.0, 1.0) * CLOUD_HALF_EXTENTS.y
		)
		var far_enough := true
		for p in placed_centers:
			if candidate.distance_to(p) < CLOUD_MIN_SPACING:
				far_enough = false
				break
		if far_enough:
			return candidate
	return candidate


func _start_cloud_bob(node: Control) -> void:
	var base : Vector2 = node.position
	var t := create_tween()
	node.set_meta("bob_tween", t)
	t.set_loops()
	t.tween_interval(randf() * CLOUD_BOB_HALF_DUR * 2.0)
	t.tween_property(node, "position:y", base.y - CLOUD_BOB_AMPLITUDE, CLOUD_BOB_HALF_DUR).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "position:y", base.y, CLOUD_BOB_HALF_DUR).set_ease(Tween.EASE_IN_OUT)


# ─── Drag & drop ─────────────────────────────────────────────────────────────
# Direct-position drag on the real node (not a ghost) — same idiom as
# game15.gd's sound-count drag (_sc_try_start_drag/_sc_end_drag): raw
# scene-level input tracks a single dragged node, moving it every frame in
# _process(), resolved against Bin overlap on release. A "tap" is just a
# press+release that never moved far — word audio plays immediately on
# press either way, so there's no separate tap-vs-drag code path needed.

const HOP_DUR         : float = 0.35   # correct-drop hop into the Bin
const HOP_ARC_HEIGHT  : float = 50.0
const COLLECTED_JITTER : Vector2 = Vector2(60.0, 45.0)   # spread across the Bin's real space — a Bin can hold ~11, too tight a jitter turned a full Bin into an unreadable blob

const BREATHE_SCALE : Vector2 = Vector2(1.08, 1.08)
const BREATHE_DUR   : float = 0.6

const WRONG_RESIST_DIST : float = 18.0
const WRONG_RESIST_DUR  : float = 0.09
const WRONG_BOUNCE_DUR  : float = 0.3

const EMPTY_GLIDE_DUR : float = 0.25

var _dragging      : bool    = false
var _drag_face     : TextureRect = null
var _drag_offset   : Vector2 = Vector2.ZERO
var _drag_pos      : Vector2 = Vector2.ZERO


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
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_try_start_drag(st.position)
		elif _dragging:
			_drag_pos = st.position
			_end_drag.call_deferred()
	elif event is InputEventScreenDrag:
		if _dragging:
			_drag_pos = (event as InputEventScreenDrag).position


# A press either taps a Bin (plays its phoneme audio, no drag) or starts
# dragging the topmost (last-drawn) Word Cloud face under the point —
# reversed iteration so an overlapping face drawn on top wins, same
# "child order resolves overlap" behavior confirmed for the Transition's
# crowd earlier this session. Bins are checked first via their tight
# visible-content rect, not their padded bounding box — the bounding boxes
# of neighboring Bins actually overlap each other (and dip into the Word
# Cloud's own area), which was causing a Cloud face tap near a Bin to also
# fire that Bin's phoneme audio.
func _try_start_drag(pos: Vector2) -> void:
	if _busy or _dragging:
		return
	for i in range(_bins.size()):
		var node : TextureRect = _bins[i]["node"]
		if _bin_visible_rect(node).has_point(pos):
			_play_sfx(_bins[i].get("phoneme_audio", ""))
			return
	for i in range(_cloud_faces.size() - 1, -1, -1):
		var f : TextureRect = _cloud_faces[i]
		if not is_instance_valid(f):
			continue
		if Rect2(f.position, f.size).has_point(pos):
			_dragging     = true
			_drag_face    = f
			_drag_offset  = f.position - pos
			_drag_pos     = pos

			var t : Tween = f.get_meta("bob_tween", null)
			if t != null and t.is_valid():
				t.pause()
			move_child(f, get_child_count() - 1)   # draw on top while held

			var w : Dictionary = f.get_meta("word")
			_play_sfx(w.get("word_audio", ""))
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
	var bin_index : int = _find_bin_at(face_center)

	if bin_index >= 0:
		var w : Dictionary = f.get_meta("word")
		var word_phoneme : String = String(w.get("phoneme_audio", "")).get_file().get_basename()
		if word_phoneme == _bins[bin_index]["phoneme"]:
			_on_correct_drop(f, bin_index)
		else:
			_on_wrong_drop_on_bin(f, bin_index)
	else:
		_on_drop_empty_space(f)


# The bin PNG's drawn cup only fills a fraction of its own canvas — content
# bbox measured at (473,286)-(968,696) out of a 1536x1024 canvas, i.e.
# roughly x:[0.308,0.630] y:[0.279,0.680] as fractions of the full texture.
# Bin bounding boxes are deliberately much bigger than that (so the visible
# cup itself can render bigger), so neighboring bins' full boxes actually
# overlap — using the padded box here let a drag land in the wrong
# neighboring Bin, or made the Word Cloud's audio and a Bin's phoneme audio
# both fire off one tap. Landing detection uses this tighter rect instead.
const BIN_CONTENT_FRACTION : Rect2 = Rect2(0.308, 0.279, 0.322, 0.401)

func _bin_visible_rect(node: Control) -> Rect2:
	return Rect2(
		node.position + BIN_CONTENT_FRACTION.position * node.size,
		BIN_CONTENT_FRACTION.size * node.size)


func _bin_visible_center(node: Control) -> Vector2:
	return _bin_visible_rect(node).get_center()


func _find_bin_at(point: Vector2) -> int:
	for i in range(_bins.size()):
		var node : TextureRect = _bins[i]["node"]
		if _bin_visible_rect(node).has_point(point):
			return i
	return -1


# ─── Correct drop ───────────────────────────────────────────────────────────
# Full-size hop (a real two-segment arc, not a straight-line slide) into the
# Bin, lands, then settles into the same gentle bob it had in the cloud —
# stays full size, since the Bins are now big enough to hold it comfortably.
func _on_correct_drop(f: TextureRect, bin_index: int) -> void:
	_busy = true
	_cloud_faces.erase(f)

	_play_sfx(GAYAGEUM_CORRECT_PATH)

	var bin : Dictionary = _bins[bin_index]
	var bin_node : TextureRect = bin["node"]
	var land_pos : Vector2 = _pick_bin_landing_pos(bin, bin_node) - f.size / 2.0

	var start_pos : Vector2 = f.position
	var mid_pos   : Vector2 = (start_pos + land_pos) / 2.0 - Vector2(0, HOP_ARC_HEIGHT)

	var hop := create_tween()
	hop.tween_property(f, "position", mid_pos, HOP_DUR * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop.tween_property(f, "position", land_pos, HOP_DUR * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await hop.finished

	move_child(f, get_child_count() - 1)   # settle visually in front of the Bin
	_start_cloud_bob(f)   # same gentle bob, now anchored at its landed spot inside the Bin

	var w : Dictionary = f.get_meta("word")
	bin["collected"].append(w)
	_check_bin_breathing(bin_index)
	_busy = false
	_check_round_complete()


# Rejection-sampled, same idea as the Word Cloud's own placement — spreads
# collected Louis across the Bin's real visible space instead of piling
# them all near-exactly on top of each other, while still allowing natural
# closeness/overlap once a Bin gets crowded (never a forced grid).
const COLLECTED_MIN_SPACING  : float = 34.0
const COLLECTED_MAX_ATTEMPTS : int = 20

func _pick_bin_landing_pos(bin: Dictionary, bin_node: Control) -> Vector2:
	var center : Vector2 = _bin_visible_center(bin_node)
	var placed : Array = bin["collected_positions"]
	var candidate : Vector2 = center
	for _attempt in range(COLLECTED_MAX_ATTEMPTS):
		candidate = center + Vector2(
			randf_range(-COLLECTED_JITTER.x, COLLECTED_JITTER.x),
			randf_range(-COLLECTED_JITTER.y, COLLECTED_JITTER.y))
		var far_enough := true
		for p in placed:
			if candidate.distance_to(p) < COLLECTED_MIN_SPACING:
				far_enough = false
				break
		if far_enough:
			break
	placed.append(candidate)
	return candidate


func _check_bin_breathing(bin_index: int) -> void:
	var bin : Dictionary = _bins[bin_index]
	if bin["breathing"] or bin["collected"].size() < bin["target_count"]:
		return
	bin["breathing"] = true
	var t := create_tween()
	bin["node"].set_meta("breathe_tween", t)
	t.set_loops()
	t.tween_property(bin["node"], "scale", BREATHE_SCALE, BREATHE_DUR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(bin["node"], "scale", Vector2(1.0, 1.0), BREATHE_DUR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _check_round_complete() -> void:
	for b in _bins:
		if not b["breathing"]:
			return
	_finish_round()


# ─── Wrong drop ─────────────────────────────────────────────────────────────
# On a wrong Bin: Louis visibly resists twice — pushes against the Bin,
# doesn't slide in — then bounces back to the Word Cloud. No sound, no
# voice, never actually enters the Bin. In empty space (no Bin at all):
# just a plain glide back, no resistance choreography.
func _on_wrong_drop_on_bin(f: TextureRect, bin_index: int) -> void:
	_busy = true
	var start_pos : Vector2 = f.position
	var bin_node  : TextureRect = _bins[bin_index]["node"]
	var bin_center : Vector2 = _bin_visible_center(bin_node)

	var away : Vector2 = (start_pos + f.size / 2.0) - bin_center
	if away == Vector2.ZERO:
		away = Vector2.UP
	away = away.normalized() * WRONG_RESIST_DIST

	var resist := create_tween()
	for _i in range(2):
		resist.tween_property(f, "position", start_pos + away, WRONG_RESIST_DUR) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		resist.tween_property(f, "position", start_pos, WRONG_RESIST_DUR) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await resist.finished

	var base_pos : Vector2 = f.get_meta("base_pos")
	var bounce := create_tween()
	bounce.tween_property(f, "position", base_pos, WRONG_BOUNCE_DUR) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await bounce.finished

	_resume_face_bob(f)
	_busy = false


func _on_drop_empty_space(f: TextureRect) -> void:
	_busy = true
	var base_pos : Vector2 = f.get_meta("base_pos")
	var glide := create_tween()
	glide.tween_property(f, "position", base_pos, EMPTY_GLIDE_DUR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await glide.finished
	_resume_face_bob(f)
	_busy = false


func _resume_face_bob(f: TextureRect) -> void:
	var t : Tween = f.get_meta("bob_tween", null)
	if t != null and t.is_valid():
		t.play()


# ─── Bins ───────────────────────────────────────────────────────────────────

func _spawn_bins(phonemes: Array) -> void:
	var bin_tex  : Texture2D = load(BIN_TEXTURE_PATH)
	var tex_size : Vector2   = bin_tex.get_size() * BIN_SCALE

	for i in range(phonemes.size()):
		# Plain TextureRect, same reasoning as the Word Cloud faces — hit-
		# testing is manual (via _bin_visible_rect() in _try_start_drag()),
		# not a Button's own click detection, so the bin's much-bigger-than-
		# its-visible-cup bounding box never gets treated as clickable.
		var rect := TextureRect.new()
		rect.texture      = bin_tex
		rect.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		rect.size         = tex_size
		rect.pivot_offset = tex_size / 2.0
		rect.position     = Vector2(BIN_X_POSITIONS[i], BIN_ROW_Y) - rect.pivot_offset
		add_child(rect)

		var phoneme : String = phonemes[i]
		var phoneme_audio : String = ""
		var target_count  : int    = 0
		for w in _quest_pool:
			if String(w.get("phoneme_audio", "")).get_file().get_basename() == phoneme:
				target_count += 1
				if phoneme_audio == "":
					phoneme_audio = w.get("phoneme_audio", "")

		_bins.append({
			"node": rect,
			"phoneme": phoneme,
			"phoneme_audio": phoneme_audio,
			"collected": [],
			"collected_positions": [],
			"target_count": target_count,
			"breathing": false,
		})


# ─── Shared audio helper ─────────────────────────────────────────────────────
# Ephemeral one-shot player per tap so overlapping taps (word audio, phoneme
# audio, gayageum correct) never cut each other off.
func _play_sfx(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


# ─── Round -> Quest -> Group completion (wired, exercised once drag/drop lands) ──

func _finish_round() -> void:
	_busy = true
	await _fade_out_round()
	if _round_index + 1 < ROUNDS_PER_QUEST:
		_round_index += 1
		_start_round()
	else:
		_clear_round()
		_play_quest_transition()


func _on_all_quests_complete() -> void:
	if LevelProgress.has_next():
		LevelProgress.advance()
		SaveManager.set_level1_set_index(LevelProgress.current_index)
		get_tree().change_scene_to_file("res://game.tscn")
	else:
		SaveManager.set_level1_completed()
		LevelProgress.reset()
		LevelTransition.next_level_id = "level15"
		LevelTransition.level_name    = "Level 1.5"
		get_tree().change_scene_to_file("res://level_transition.tscn")


# ═══════════════════════════════════════════════════════════════════════════
# TRANSITION PHASE — "Find the Play Button" hidden-object hunt
# Already built and playtested standalone this session; now a callable phase
# instead of the file's _ready() entry point. At its end, resumes the Rounds
# phase for the next Quest (or the next Group, via _on_all_quests_complete).
# ═══════════════════════════════════════════════════════════════════════════

const DECOY_COUNT : int = 65
const FACE_SCALE  : Vector2 = Vector2(0.135, 0.135)

# playbutton.png's drawn face only fills a small part of its canvas (content
# ~372x263px out of a 907x437 canvas) while Louis's fills nearly the whole
# canvas (~782x727 out of 907x798) — the same FACE_SCALE on both renders the
# real face visibly smaller than every decoy. Scaled up by the measured
# content-size ratio (782/372) so the real face reads as the same size as a
# Louis face, not a giveaway-by-being-tiny.
const REAL_FACE_SCALE : Vector2 = Vector2(0.2838, 0.2838)

const QT_CLUSTER_CENTER       : Vector2 = Vector2(640, 340)
const QT_CLUSTER_HALF_EXTENTS : Vector2 = Vector2(500, 260)

const QT_MIN_FACE_SPACING : float = 55.0
const QT_MAX_PLACEMENT_ATTEMPTS : int = 30

const QT_NESTLE_MIN_DIST : float = 15.0
const QT_NESTLE_MAX_DIST : float = 45.0

const QT_BOB_AMPLITUDE : float = 8.0
const QT_BOB_HALF_DUR  : float = 0.3

const QT_FREEZE_DURATION : float = 0.5

const QT_GROW_SCALE_MULT : float = 2.4
const QT_GROW_DUR   : float = 0.4
const QT_DANCE_DUR  : float = 1.2
const QT_FADE_DUR   : float = 0.8

var _qt_faces : Array = []
var _qt_bob_tweens : Array = []
var _qt_real_index : int  = -1
var _qt_frozen    : bool  = false
var _qt_resolved  : bool  = false
var _qt_music_player : AudioStreamPlayer = null


func _play_quest_transition() -> void:
	_qt_faces.clear()
	_qt_bob_tweens.clear()
	_qt_resolved = false
	_qt_frozen   = false

	_qt_start_music()
	_qt_spawn_faces()
	for i in range(_qt_faces.size()):
		_qt_start_bob(i)


func _qt_start_music() -> void:
	if not ResourceLoader.exists(MUSIC_PATH):
		return
	_qt_music_player           = AudioStreamPlayer.new()
	_qt_music_player.stream    = load(MUSIC_PATH)
	_qt_music_player.volume_db = 0.0
	_qt_music_player.finished.connect(_qt_on_music_finished)
	add_child(_qt_music_player)
	_qt_music_player.play()


func _qt_on_music_finished() -> void:
	if _qt_music_player != null:
		_qt_music_player.play()


func _qt_stop_music() -> void:
	if _qt_music_player == null:
		return
	if _qt_music_player.playing:
		var fade := create_tween()
		fade.tween_property(_qt_music_player, "volume_db", -40.0, 1.0)
		await fade.finished
	_qt_music_player.stop()
	_qt_music_player.queue_free()
	_qt_music_player = null


func _qt_spawn_faces() -> void:
	_qt_real_index = DECOY_COUNT

	var decoy_tex : Texture2D = load(LOUIS_TEXTURE_PATH)
	var real_tex  : Texture2D = load(REAL_TEXTURE_PATH)

	var placed_centers : Array = []
	for i in range(DECOY_COUNT):
		var btn := TextureButton.new()
		btn.texture_normal      = decoy_tex
		btn.ignore_texture_size = true
		btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var tex_size : Vector2 = decoy_tex.get_size() * FACE_SCALE
		btn.size         = tex_size
		btn.pivot_offset = tex_size / 2.0

		var center : Vector2 = _qt_pick_face_center(placed_centers)
		placed_centers.append(center)
		btn.position = center - btn.pivot_offset
		btn.set_meta("base_pos", btn.position)

		btn.pressed.connect(_qt_on_face_pressed.bind(i))
		add_child(btn)
		_qt_faces.append(btn)
		_qt_bob_tweens.append(null)

	var real_btn := TextureButton.new()
	real_btn.texture_normal      = real_tex
	real_btn.ignore_texture_size = true
	real_btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	var real_size : Vector2 = real_tex.get_size() * REAL_FACE_SCALE
	real_btn.size         = real_size
	real_btn.pivot_offset = real_size / 2.0

	var real_center : Vector2 = _qt_pick_nestled_center(placed_centers)
	real_btn.position = real_center - real_btn.pivot_offset
	real_btn.set_meta("base_pos", real_btn.position)

	real_btn.pressed.connect(_qt_on_face_pressed.bind(_qt_real_index))
	add_child(real_btn)
	_qt_faces.append(real_btn)
	_qt_bob_tweens.append(null)


func _qt_pick_face_center(placed_centers: Array) -> Vector2:
	var candidate : Vector2 = QT_CLUSTER_CENTER
	for _attempt in range(QT_MAX_PLACEMENT_ATTEMPTS):
		candidate = QT_CLUSTER_CENTER + Vector2(
			randf_range(-1.0, 1.0) * QT_CLUSTER_HALF_EXTENTS.x,
			randf_range(-1.0, 1.0) * QT_CLUSTER_HALF_EXTENTS.y
		)
		var far_enough := true
		for p in placed_centers:
			if candidate.distance_to(p) < QT_MIN_FACE_SPACING:
				far_enough = false
				break
		if far_enough:
			return candidate
	return candidate


func _qt_pick_nestled_center(placed_centers: Array) -> Vector2:
	var anchor : Vector2 = placed_centers[randi() % placed_centers.size()]
	var angle : float = randf_range(0.0, TAU)
	var dist  : float = randf_range(QT_NESTLE_MIN_DIST, QT_NESTLE_MAX_DIST)
	return anchor + Vector2(cos(angle), sin(angle)) * dist


func _qt_start_bob(i: int) -> void:
	var btn  : TextureButton = _qt_faces[i]
	var base : Vector2 = btn.get_meta("base_pos")
	var t := create_tween()
	_qt_bob_tweens[i] = t
	t.set_loops()
	t.tween_interval(randf() * QT_BOB_HALF_DUR * 2.0)
	t.tween_property(btn, "position:y", base.y - QT_BOB_AMPLITUDE, QT_BOB_HALF_DUR).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(btn, "position:y", base.y, QT_BOB_HALF_DUR).set_ease(Tween.EASE_IN_OUT)


func _qt_on_face_pressed(i: int) -> void:
	if _qt_resolved:
		return
	if i == _qt_real_index:
		_qt_on_found_real(i)
	else:
		_qt_on_wrong_tap()


func _qt_on_wrong_tap() -> void:
	if _qt_frozen:
		return
	_qt_frozen = true
	for t in _qt_bob_tweens:
		if t != null and t.is_valid():
			t.pause()
	await get_tree().create_timer(QT_FREEZE_DURATION).timeout
	for t in _qt_bob_tweens:
		if t != null and t.is_valid():
			t.play()
	_qt_frozen = false


func _qt_on_found_real(i: int) -> void:
	_qt_resolved = true
	for t in _qt_bob_tweens:
		if t != null and t.is_valid():
			t.kill()

	var real_btn : TextureButton = _qt_faces[i]
	real_btn.scale = Vector2(1.0, 1.0)

	var grow := create_tween()
	grow.tween_property(real_btn, "scale", Vector2(QT_GROW_SCALE_MULT, QT_GROW_SCALE_MULT), QT_GROW_DUR) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await grow.finished

	# 3 loops x 3 segments = 9 segments total, so each is QT_DANCE_DUR/9.
	var dance := create_tween()
	dance.set_loops(3)
	dance.tween_property(real_btn, "rotation_degrees", 8.0, QT_DANCE_DUR / 9.0)
	dance.tween_property(real_btn, "rotation_degrees", -8.0, QT_DANCE_DUR / 9.0)
	dance.tween_property(real_btn, "rotation_degrees", 0.0, QT_DANCE_DUR / 9.0)
	await dance.finished

	var fade := create_tween()
	fade.set_parallel(true)
	for f in _qt_faces:
		fade.tween_property(f, "modulate:a", 0.0, QT_FADE_DUR)
	await fade.finished

	await _qt_stop_music()
	for f in _qt_faces:
		f.queue_free()
	_qt_faces.clear()
	_qt_bob_tweens.clear()

	_quest_index += 1
	_start_quest()
