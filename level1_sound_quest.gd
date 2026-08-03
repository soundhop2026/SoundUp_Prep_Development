extends Node2D

# ─── Level 1 Sound Quest — Quest Transition ("Find the Play Button") ───────
# Mirrors Prep Sound Quest's Quest Transition (a decorative celebration
# between Sets/Quests), but the mechanic here is a hidden-object search
# instead of a maze-hop: 45 decoy Louis faces plus one real Play Button
# hiding among them, all bobbing continuously — the ONLY way to tell them
# apart is by tapping.
#
#   - Wrong tap: every face freezes in place for a beat, no sound, no
#     penalty — just a wordless "not that one" — then resumes bobbing.
#   - Correct tap (the real Play Button): its texture swaps from the Louis
#     face to playbutton.png (a genuine "surprise, it was me!" reveal),
#     then it grows, does a little celebratory dance, and every face
#     fades out together.
#
# Decoys use louisfaces/happylouis3-Photoroom.png — Louis is a real,
# separate character asset (not a modified Play Button). All 46 faces show
# this SAME Louis texture during the search, so there is genuinely zero
# visual difference between them — the real one only reveals itself once
# tapped, rather than needing any masking trick on a shared texture.
#
# NOTE: this file currently implements ONLY the transition. The actual
# Level 1 Sound Quest gameplay (a word-cloud sorting activity — dragging
# words into phoneme-labeled cubes) is being built separately and isn't
# wired in yet. Reachable standalone via DEBUG -> Demo Shortcuts -> "Test
# Level 1 Sound Quest Transition" for isolated preview/testing.
# ─────────────────────────────────────────────────────────────────────────

const FONT_PATH          : String = "res://UI_assets/210 연필스케치R.ttf"
const DECOY_TEXTURE_PATH : String = "res://louisfaces/happylouis3-Photoroom.png"
const REAL_TEXTURE_PATH  : String = "res://UI_assets/playbutton.png"
const MUSIC_PATH         : String = "res://soundquest/assets/quest_level1_bgm.mp3"
const BG_COLOR           : Color  = Color(0.431, 0.710, 1.0, 1.0)   # sky blue — matches Level 1's game.gd, not Prep's green

const DECOY_COUNT : int    = 45   # up from 25 — plenty of empty canvas space with the smaller count
const FACE_SCALE  : Vector2 = Vector2(0.135, 0.135)

const CLUSTER_CENTER       : Vector2 = Vector2(640, 340)
const CLUSTER_HALF_EXTENTS : Vector2 = Vector2(500, 260)   # widened alongside the face-count bump

# Minimum center-to-center distance between any two faces — generous partial
# overlap is fine (and matches the reference crowd look), but pure random
# placement occasionally landed two faces almost exactly on top of each
# other, reading as one blob rather than a crowd.
const MIN_FACE_SPACING : float = 55.0
const MAX_PLACEMENT_ATTEMPTS : int = 30

const BOB_AMPLITUDE : float = 8.0
const BOB_HALF_DUR  : float = 0.3   # one bob = up then down, each half this long

const FREEZE_DURATION : float = 0.5   # how long ALL faces hold still after a wrong tap

# If nothing's been found after this long, the real face starts a subtle
# scale pulse on top of its normal bob — not an instant giveaway (still
# needs real attention amid 46 nearly-identical faces), but enough that a
# genuinely stuck search doesn't turn into an endless dead end.
const HINT_DELAY      : float = 7.0
const HINT_PULSE_SCALE : float = 1.15
const HINT_PULSE_DUR   : float = 0.6

const GROW_SCALE_MULT : float = 2.4
const GROW_DUR   : float = 0.4
const DANCE_DUR  : float = 1.2
const FADE_DUR   : float = 0.8

var _font  : Font = null
var _faces : Array = []   # Array[TextureButton]
var _bob_tweens : Array = []   # Array[Tween], parallel to _faces
var _real_index : int  = -1
var _frozen    : bool  = false
var _resolved  : bool  = false   # true once the real one's been found, ignore further taps
var _music_player : AudioStreamPlayer = null
var _hint_tween  : Tween = null
var _hint_active : bool  = false


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

	_start_music()
	_spawn_faces()
	for i in range(_faces.size()):
		_start_bob(i)
	_start_hint_timer()


# If still unresolved after HINT_DELAY, the real face starts a subtle scale
# pulse layered on top of its normal bob — a genuine but non-obvious clue,
# so a stuck search never becomes an endless dead end.
func _start_hint_timer() -> void:
	await get_tree().create_timer(HINT_DELAY).timeout
	if _resolved:
		return
	_hint_active = true
	var real_btn : TextureButton = _faces[_real_index]
	_hint_tween = create_tween()
	_hint_tween.set_loops()
	_hint_tween.tween_property(real_btn, "scale", Vector2(HINT_PULSE_SCALE, HINT_PULSE_SCALE), HINT_PULSE_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hint_tween.tween_property(real_btn, "scale", Vector2(1.0, 1.0), HINT_PULSE_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Manual loop-on-finished — same idiom as sound_quest.gd's _start_music()/
# _on_music_finished() for Prep's Quest Transition BGM.
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


# ─── Face spawning ──────────────────────────────────────────────────────────

func _spawn_faces() -> void:
	var total : int = DECOY_COUNT + 1
	_real_index = randi() % total

	# Every face shows the Louis texture during the search — genuinely one
	# shared asset, not a modified Play Button — so there is nothing to
	# distinguish the real one from a decoy until it's actually tapped.
	var decoy_tex : Texture2D = load(DECOY_TEXTURE_PATH)

	var placed_centers : Array = []
	for i in range(total):
		var btn := TextureButton.new()
		btn.texture_normal      = decoy_tex
		btn.ignore_texture_size = true
		btn.stretch_mode        = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var tex_size : Vector2 = decoy_tex.get_size() * FACE_SCALE
		btn.size         = tex_size
		btn.pivot_offset = tex_size / 2.0

		var center : Vector2 = _pick_face_center(placed_centers)
		placed_centers.append(center)
		btn.position = center - btn.pivot_offset
		btn.set_meta("base_pos", btn.position)

		btn.pressed.connect(_on_face_pressed.bind(i))
		add_child(btn)
		_faces.append(btn)
		_bob_tweens.append(null)

	# The real face must always win any overlap, or a decoy sitting on top
	# of it can steal clicks meant for it — making it feel unfindable even
	# when tapped directly at its own center. z_index does NOT control this:
	# confirmed via simulated-click testing that GUI input hit-testing among
	# overlapping Controls here resolves by scene-tree child order (last
	# child wins), regardless of z_index. So the real face is explicitly
	# moved to be the LAST child after all 46 are spawned, guaranteeing it
	# always wins regardless of where its random index happened to land.
	move_child(_faces[_real_index], get_child_count() - 1)


# Rejection-sampled placement: retries a random spot within the cluster
# until it's at least MIN_FACE_SPACING from every already-placed face, or
# gives up after MAX_PLACEMENT_ATTEMPTS and accepts whatever it last tried
# (guarantees this always terminates, even if the cluster gets too full to
# satisfy the spacing everywhere).
func _pick_face_center(placed_centers: Array) -> Vector2:
	var candidate : Vector2 = CLUSTER_CENTER
	for _attempt in range(MAX_PLACEMENT_ATTEMPTS):
		candidate = CLUSTER_CENTER + Vector2(
			randf_range(-1.0, 1.0) * CLUSTER_HALF_EXTENTS.x,
			randf_range(-1.0, 1.0) * CLUSTER_HALF_EXTENTS.y
		)
		var far_enough := true
		for p in placed_centers:
			if candidate.distance_to(p) < MIN_FACE_SPACING:
				far_enough = false
				break
		if far_enough:
			return candidate
	return candidate


# ─── Bobbing (the camouflage) ───────────────────────────────────────────────
# Slight per-face phase offset (a random interval before each cycle) so all
# 26 faces don't bob in lockstep — a more organic, harder-to-read crowd.
func _start_bob(i: int) -> void:
	var btn  : TextureButton = _faces[i]
	var base : Vector2 = btn.get_meta("base_pos")
	var t := create_tween()
	_bob_tweens[i] = t
	t.set_loops()
	t.tween_interval(randf() * BOB_HALF_DUR * 2.0)
	t.tween_property(btn, "position:y", base.y - BOB_AMPLITUDE, BOB_HALF_DUR).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(btn, "position:y", base.y, BOB_HALF_DUR).set_ease(Tween.EASE_IN_OUT)


# ─── Input ──────────────────────────────────────────────────────────────────

func _on_face_pressed(i: int) -> void:
	if _resolved:
		return
	if i == _real_index:
		_on_found_real(i)
	else:
		_on_wrong_tap()


# A wrong tap freezes every face mid-bob for a beat — no sound, no
# penalty, just a wordless "not that one" — then everything resumes. A
# second wrong tap while already frozen is a no-op rather than stacking.
func _on_wrong_tap() -> void:
	if _frozen:
		return
	_frozen = true
	for t in _bob_tweens:
		if t != null and t.is_valid():
			t.pause()
	if _hint_active and _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.pause()
	await get_tree().create_timer(FREEZE_DURATION).timeout
	for t in _bob_tweens:
		if t != null and t.is_valid():
			t.play()
	if _hint_active and _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.play()
	_frozen = false


func _on_found_real(i: int) -> void:
	_resolved = true
	for t in _bob_tweens:
		if t != null and t.is_valid():
			t.kill()
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()

	var real_btn : TextureButton = _faces[i]
	real_btn.scale = Vector2(1.0, 1.0)   # reset in case the hint pulse was mid-cycle
	# Swap Louis -> the real Play Button texture now that it's found — a
	# genuine "surprise, it was me!" reveal as it grows/dances, rather than
	# just a bigger Louis face.
	real_btn.texture_normal = load(REAL_TEXTURE_PATH)

	var grow := create_tween()
	grow.tween_property(real_btn, "scale", Vector2(GROW_SCALE_MULT, GROW_SCALE_MULT), GROW_DUR) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await grow.finished

	# 3 loops x 3 segments = 9 segments total, so each is DANCE_DUR/9 —
	# not /6, which would have made the real total 1.8s instead of DANCE_DUR.
	var dance := create_tween()
	dance.set_loops(3)
	dance.tween_property(real_btn, "rotation_degrees", 8.0, DANCE_DUR / 9.0)
	dance.tween_property(real_btn, "rotation_degrees", -8.0, DANCE_DUR / 9.0)
	dance.tween_property(real_btn, "rotation_degrees", 0.0, DANCE_DUR / 9.0)
	await dance.finished

	var fade := create_tween()
	fade.set_parallel(true)
	for f in _faces:
		fade.tween_property(f, "modulate:a", 0.0, FADE_DUR)
	await fade.finished

	await _stop_music()
	_on_transition_finished()


# Standalone for now — real integration will hand off to the next Set's
# setup here instead, once the core word-cloud gameplay exists.
func _on_transition_finished() -> void:
	print("Level 1 Sound Quest transition finished.")
