class_name Level15SoundQuestTransitions
extends Node2D

# ─── Level 1.5 Sound Quest — shared Short/Long Set Transitions ─────────────
# Extracted from level15_sound_quest_ab.gd once Quest C/D needed the exact
# same choreography — every Level 1.5 Sound Quest type instantiates this as
# a child and calls play_short()/play_long() rather than duplicating this
# code per quest type.
#
# Two-tier Transition rule (locked 2026-08-06, corrected same day — the
# original design draft had this backwards, treating the Long Transition as
# a one-time first-entry moment; it is NOT):
#   - Short Transition: every Set boundary WITHIN a Quest (e.g. A1->A2,
#     A2->A3, A3->A4).
#   - Long Story Transition: a Quest type's FINAL Set boundary only (e.g.
#     A4's completion) — the Short Transition does NOT also play there.
#     Plays once per Quest type (A-F), 6 times total across all of Level 1.5
#     Sound Quest. Story: Play Button hesitates 4x at a bridge, fails a
#     first crossing attempt, succeeds on a second while a ~20-strong friend
#     group's energy shifts from nervous bouncing to celebration, joins them
#     at ~80% across, group exits together.
# Callers decide WHICH one to play (mutually exclusive per boundary) — see
# each quest scene's own _on_round_complete()-equivalent.
#
# Reuses louisfaces/ (already used by Level 1 Sound Quest's own crowd) for
# the friend group, same fade-in/loop/fade-out music pattern as Level 1
# Sound Quest's Quest Transition (`_qt_` functions in level1_sound_quest.gd).
# First-pass sizing/timing — like Level 1's Quest Transition, this will
# likely need a live visual-feel pass once the user can actually see it.
# ─────────────────────────────────────────────────────────────────────────

const PLAYBUTTON_TEXTURE_PATH : String = "res://UI_assets/playbutton.png"

var _lt_music_player : AudioStreamPlayer = null


# ─── Short between-Set Transition (no letters n/a — no target/bubble ────────
# ─── content shown, just Play Button walking) ───────────────────────────────

const SHORT_SIZE   : Vector2 = Vector2(160, 160)
const SHORT_START_X : float = -120.0
const SHORT_END_X   : float = 1400.0
const SHORT_Y       : float = 400.0
const SHORT_DUR     : float = 1.4

func play_short() -> void:
	var tex : Texture2D = load(PLAYBUTTON_TEXTURE_PATH)
	var face := TextureRect.new()
	face.texture = tex
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.size = SHORT_SIZE
	face.position = Vector2(SHORT_START_X, SHORT_Y)
	add_child(face)

	var walk := create_tween()
	walk.tween_property(face, "position:x", SHORT_END_X, SHORT_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await walk.finished
	face.queue_free()


# ─── Long Story Transition ───────────────────────────────────────────────────

const LONG_BGM : String = "res://soundquest/assets/quest_level15_bgm.mp3"
const BRIDGE_TEXTURE_PATH : String = "res://soundquest/assets/bridge_level15_soundquest_transition.png"
const LT_NERVOUS_TEXTURE   : String = "res://louisfaces/neutrallous3-Photoroom.png"
const LT_CELEBRATE_TEXTURE : String = "res://louisfaces/happylouis3-Photoroom.png"

const LT_BRIDGE_POS  : Vector2 = Vector2(340, 310)
const LT_BRIDGE_SIZE : Vector2 = Vector2(600, 182)
const LT_DECK_Y  : float = 380.0
const LT_START_X : float = 160.0   # Play Button's resting spot, before the bridge
const LT_FAR_X   : float = 940.0   # bridge's far edge, where the friend group waits

const LT_HESITATE_APPROACH_X : float = 300.0   # short of the bridge's near edge (340)
const LT_HESITATE_COUNT : int = 4
const LT_HESITATE_DUR   : float = 0.35

const LT_FIRST_ATTEMPT_X   : float = 550.0   # ~35% across the bridge, then retreats (fail)
const LT_FIRST_ATTEMPT_DUR : float = 0.6
const LT_RETREAT_DUR       : float = 0.5

const LT_CROSS_DUR     : float = 2.0   # full START_X -> FAR_X crossing duration
const LT_JOIN_FRACTION : float = 0.8   # joins the group at ~80% across

const LT_CROWD_COUNT        : int = 20
const LT_CROWD_FACE_SIZE    : Vector2 = Vector2(70, 62)
const LT_PLAYBUTTON_SIZE    : Vector2 = Vector2(90, 43)
const LT_CROWD_CENTER       : Vector2 = Vector2(1060, 380)
const LT_CROWD_HALF_EXTENTS : Vector2 = Vector2(140, 140)
const LT_CROWD_MIN_SPACING  : float = 45.0
const LT_CROWD_MAX_ATTEMPTS : int = 30

const LT_EXIT_DX  : float = 500.0   # how far past FAR_X the group walks to exit
const LT_EXIT_DUR : float = 1.2

func play_long() -> void:
	_lt_start_music()

	var bridge : TextureRect = _lt_spawn_bridge()
	var crowd  : Array = _lt_spawn_crowd()
	var pb     : TextureRect = _lt_spawn_playbutton()

	await _lt_hesitate(pb)
	await _lt_fail_attempt(pb)
	await _lt_succeed_and_join(pb, crowd)
	await _lt_exit(crowd)

	await _lt_stop_music()
	bridge.queue_free()


func _lt_start_music() -> void:
	if not ResourceLoader.exists(LONG_BGM):
		return
	_lt_music_player = AudioStreamPlayer.new()
	_lt_music_player.stream = load(LONG_BGM)
	add_child(_lt_music_player)
	_lt_music_player.play()


func _lt_stop_music() -> void:
	if _lt_music_player == null:
		return
	var fade := create_tween()
	fade.tween_property(_lt_music_player, "volume_db", -40.0, 0.6)
	await fade.finished
	_lt_music_player.stop()
	_lt_music_player.queue_free()
	_lt_music_player = null


func _lt_spawn_bridge() -> TextureRect:
	var tex : Texture2D = load(BRIDGE_TEXTURE_PATH)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size = LT_BRIDGE_SIZE
	rect.position = LT_BRIDGE_POS
	add_child(rect)
	return rect


func _lt_spawn_playbutton() -> TextureRect:
	var tex : Texture2D = load(PLAYBUTTON_TEXTURE_PATH)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size = LT_PLAYBUTTON_SIZE
	rect.pivot_offset = LT_PLAYBUTTON_SIZE / 2.0
	rect.position = Vector2(LT_START_X, LT_DECK_Y) - rect.pivot_offset
	add_child(rect)
	return rect


func _lt_spawn_crowd() -> Array:
	var crowd  : Array = []
	var placed : Array = []
	var tex : Texture2D = load(LT_NERVOUS_TEXTURE)
	for i in range(LT_CROWD_COUNT):
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size = LT_CROWD_FACE_SIZE
		rect.pivot_offset = LT_CROWD_FACE_SIZE / 2.0
		var center : Vector2 = _lt_pick_crowd_center(placed)
		placed.append(center)
		rect.position = center - rect.pivot_offset
		add_child(rect)
		crowd.append(rect)
		_lt_start_nervous_bob(rect)
	return crowd


func _lt_pick_crowd_center(placed: Array) -> Vector2:
	var candidate : Vector2 = LT_CROWD_CENTER
	for _attempt in range(LT_CROWD_MAX_ATTEMPTS):
		candidate = LT_CROWD_CENTER + Vector2(
			randf_range(-1.0, 1.0) * LT_CROWD_HALF_EXTENTS.x,
			randf_range(-1.0, 1.0) * LT_CROWD_HALF_EXTENTS.y)
		var far_enough := true
		for p in placed:
			if candidate.distance_to(p) < LT_CROWD_MIN_SPACING:
				far_enough = false
				break
		if far_enough:
			return candidate
	return candidate


func _lt_start_nervous_bob(node: Control) -> void:
	var base : Vector2 = node.position
	var t := create_tween()
	node.set_meta("bob_tween", t)
	t.set_loops()
	t.tween_interval(randf() * 0.3)
	t.tween_property(node, "position:y", base.y - 4.0, 0.18).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "position:y", base.y, 0.18).set_ease(Tween.EASE_IN_OUT)


func _lt_start_celebrate_bob(node: Control) -> void:
	var base : Vector2 = node.position
	var t := create_tween()
	node.set_meta("bob_tween", t)
	t.set_loops()
	t.tween_property(node, "position:y", base.y - 14.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position:y", base.y, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _lt_shift_to_celebration(crowd: Array) -> void:
	var tex : Texture2D = load(LT_CELEBRATE_TEXTURE)
	for node in crowd:
		if not is_instance_valid(node):
			continue
		node.texture = tex
		var old_bob : Tween = node.get_meta("bob_tween", null)
		if old_bob != null and old_bob.is_valid():
			old_bob.kill()
		_lt_start_celebrate_bob(node)


func _lt_hesitate(pb: TextureRect) -> void:
	for _i in range(LT_HESITATE_COUNT):
		var t := create_tween()
		t.tween_property(pb, "position:x", LT_HESITATE_APPROACH_X - pb.size.x / 2.0, LT_HESITATE_DUR) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(pb, "position:x", LT_START_X - pb.size.x / 2.0, LT_HESITATE_DUR) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await t.finished


func _lt_fail_attempt(pb: TextureRect) -> void:
	var t := create_tween()
	t.tween_property(pb, "position:x", LT_FIRST_ATTEMPT_X - pb.size.x / 2.0, LT_FIRST_ATTEMPT_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(pb, "position:x", LT_START_X - pb.size.x / 2.0, LT_RETREAT_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished


# Succeeds on the second attempt; the friend group's energy shifts from
# nervous to celebration partway through (not the instant it starts), then
# Play Button settles into the crowd's cluster at ~80% across rather than a
# special merge transform.
func _lt_succeed_and_join(pb: TextureRect, crowd: Array) -> void:
	var join_x    : float = LT_START_X + (LT_FAR_X - LT_START_X) * LT_JOIN_FRACTION
	var cross_dur : float = LT_CROSS_DUR * LT_JOIN_FRACTION

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(pb, "position:x", join_x - pb.size.x / 2.0, cross_dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(_lt_shift_to_celebration.bind(crowd)).set_delay(cross_dur * 0.5)
	await t.finished

	pb.position = Vector2(join_x, LT_DECK_Y) - pb.pivot_offset
	crowd.append(pb)


func _lt_exit(crowd: Array) -> void:
	var t := create_tween()
	t.set_parallel(true)
	for node in crowd:
		if is_instance_valid(node):
			# pb (joined at ~80%) never had a bob tween — only the Louis
			# crowd faces do — so guard with has_meta() rather than relying
			# on get_meta()'s default, which still logs a missing-key error.
			if node.has_meta("bob_tween"):
				var old_bob : Tween = node.get_meta("bob_tween")
				if old_bob != null and old_bob.is_valid():
					old_bob.kill()
			t.tween_property(node, "position:x", node.position.x + LT_EXIT_DX, LT_EXIT_DUR) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished
	for node in crowd:
		if is_instance_valid(node):
			node.queue_free()
