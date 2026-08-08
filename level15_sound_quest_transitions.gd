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
#     Sound Quest. Locked story (settled 2026-08-08 after several drifts —
#     an interim version wrongly used louisfaces/ for the waiting group,
#     another wrongly dropped the group entirely, another added a bridge
#     that turned out to need an asset that didn't really exist; all
#     corrected — no bridge, open ground the whole scene):
#       1. One large Play Button stands alone on the left.
#       2. A group of smaller Play Buttons waits happily on the right,
#          gently bouncing — the WHOLE time, not just after it arrives.
#       3. The large Play Button takes a few steps toward the group.
#       4. It gets nervous and walks back.
#       5. Repeats ~4 times (hesitation).
#       6. Finally gathers courage and walks all the way to the group.
#       7. Nearing them, it speeds up slightly with excitement.
#       8. The whole group (crowd + the now-joined Play Button) celebrates
#          together briefly — a hop+swirl dance, not a plain bounce.
#       9. They all exit together to the right, still dancing as they go.
#     An emotional beat (gaining confidence, joining friends), not just a
#     between-Group animation — matters because it marks a Group completion.
# Callers decide WHICH one to play (mutually exclusive per boundary) — see
# each quest scene's own _on_round_complete()-equivalent.
#
# Same fade-in/loop/fade-out music pattern as Level 1 Sound Quest's Quest
# Transition (`_qt_` functions in level1_sound_quest.gd).
# ─────────────────────────────────────────────────────────────────────────

const PLAYBUTTON_TEXTURE_PATH : String = "res://UI_assets/playbutton.png"

# Transitions never set their own background — normally they inherit
# whatever the calling Quest scene set (sky blue for A/B, pale green for
# F, etc.), since Transitions is just a child node layered on top. Per
# direct request, both Short and Long now override that and cover the
# screen in Level 1.5's own main-gameplay color instead (game15.gd's
# BG_COLOR, matched exactly), for the duration of the transition only —
# freed at the end so the calling Quest's own color shows through again
# once play_short()/play_long() returns.
const L15_BG_COLOR : Color = Color("#A83A22")

func _lt_cover_background() -> ColorRect:
	SceneBackground.set_color(L15_BG_COLOR)
	var bg := ColorRect.new()
	bg.color = L15_BG_COLOR
	bg.size = get_viewport_rect().size
	bg.position = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)
	return bg

var _lt_music_player : AudioStreamPlayer = null
var _lt_music_start_ms : int = 0


# ─── Short between-Set Transition (no letters n/a — no target/bubble ────────
# ─── content shown, just Play Button hopping) ───────────────────────────────
# The 6x (960x960) size read as too big live — shrunk 70% down to 288x288
# (30% of 960, i.e. 1.8x the original 160x160). playbutton.png's drawn face
# only fills its own box's ~20%-80% vertically (measured earlier for the
# Quest C/D landing-spot work) — positioned so the actual visible face, not
# the box edges, centers around y=400 (roughly matching the Long
# Transition's ground level).

const SHORT_SIZE       : Vector2 = Vector2(288, 288)   # 960 shrunk 70% (960*0.3)
const SHORT_START_X    : float = -220.0
const SHORT_END_X      : float = 1450.0
const SHORT_Y          : float = 256.0   # top-left, chosen so the face's visible content centers near y=400
const SHORT_DUR        : float = 5.0     # slowed from 1.4 — "slowly slowly... slowly"
const SHORT_HOP_COUNT  : int   = 8
const SHORT_HOP_HEIGHT : float = 60.0

func play_short() -> void:
	var bg_cover : ColorRect = _lt_cover_background()
	var tex : Texture2D = load(PLAYBUTTON_TEXTURE_PATH)
	var face := TextureRect.new()
	face.texture = tex
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.size = SHORT_SIZE
	face.pivot_offset = SHORT_SIZE / 2.0
	face.position = Vector2(SHORT_START_X, SHORT_Y)
	add_child(face)

	var base_y : float = face.position.y
	var step_dur : float = SHORT_DUR / float(SHORT_HOP_COUNT)
	for i in range(SHORT_HOP_COUNT):
		var frac : float = float(i + 1) / float(SHORT_HOP_COUNT)
		var target_x : float = lerp(SHORT_START_X, SHORT_END_X, frac)

		var up := create_tween()
		up.tween_property(face, "position", Vector2(target_x, base_y - SHORT_HOP_HEIGHT), step_dur * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await up.finished

		var down := create_tween()
		down.tween_property(face, "position", Vector2(target_x, base_y), step_dur * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await down.finished

	face.queue_free()
	bg_cover.queue_free()


# ─── Long Story Transition ───────────────────────────────────────────────────
# No bridge — removed 2026-08-08 per direct feedback: the bridge asset
# turned out to be a placeholder (a single curved line, no deck/rails/
# structure), and the walk-the-arc code it required was unnecessary
# complexity in service of an asset that wasn't real yet. The story was
# never really about the bridge — it's hesitation, courage, joining
# friends — so Play Button now just walks on flat, open ground the whole
# time. Simpler and more reliable, same emotional beats.

const LONG_BGM : String = "res://soundquest/assets/quest_level15_bgm.mp3"
const LT_MUSIC_OUTRO_RESERVE : float = 10.0   # seconds of music held back to play under the breathe + hop-away exit beats

const LT_GROUND_Y : float = 400.0   # flat ground level — everyone (crossing Play Button + waiting group) stands here
const LT_START_X  : float = 160.0   # Play Button's resting spot

const LT_HESITATE_APPROACH_X : float = 320.0   # a few steps forward, short of the group
const LT_HESITATE_COUNT      : int   = 4       # ~4 attempts before finally succeeding
const LT_HESITATE_APPROACH_DUR : float = 0.4
const LT_HESITATE_RETREAT_DUR  : float = 0.4

const LT_CROSS_DUR        : float = 1.6   # full START_X -> join-point walk duration, at normal pace
const LT_SPEEDUP_FRACTION : float = 0.7   # normal pace up to here (of the join distance), faster after — "speeds up slightly with excitement"
const LT_SPEEDUP_MULT     : float = 1.5

# The last resize bumped only the crowd (right side) bigger, leaving the
# crossing Play Button (left side) static — caught live and corrected: both
# grow together now. Crossing Play Button up 40% (152x73 -> 213x102).
# Crowd's own multiplier brought back down to 0.9 so its ABSOLUTE size
# stays where it was (~191x92) rather than compounding on top of the
# left side's growth too — the crowd itself wasn't the complaint, the
# static left side was. The crossing Play Button is the LARGE one; the
# waiting group is smaller.
const LT_PLAYBUTTON_SIZE : Vector2 = Vector2(213, 102)
const LT_EXIT_DX  : float = 500.0   # how far past the join point the group walks to exit
const LT_EXIT_DUR : float = 1.2

# Play Buttons waiting on the right — same texture as the large crossing
# one, tied to LT_PLAYBUTTON_SIZE so the ratio stays locked if that ever
# changes. Count raised 8->13 (+5) per direct request. Spacing: the strict
# non-overlap value (135, clearing the face diagonal) was superseded by a
# direct follow-up asking them to cluster close together in a natural
# "wagle wagle" cloud instead (same loose, slightly-overlapping-allowed
# idiom as Level 1's Word Cloud) — reduced back down and the placement
# area tightened to match.
const LT_CROWD_COUNT        : int = 13
const LT_CROWD_SIZE_MULT    : float = 0.9
const LT_CROWD_FACE_SIZE    : Vector2 = LT_PLAYBUTTON_SIZE * LT_CROWD_SIZE_MULT
const LT_CROWD_CENTER       : Vector2 = Vector2(1060, LT_GROUND_Y)
const LT_CROWD_HALF_EXTENTS : Vector2 = Vector2(150, 110)
const LT_CROWD_MIN_SPACING  : float = 55.0

# Crossing Play Button settles at the group's near (left) edge rather than
# a fixed point that could land anywhere inside the cluster — reads as
# "arrives and stands with the group," not "teleports into the middle."
const LT_JOIN_X : float = LT_CROWD_CENTER.x - LT_CROWD_HALF_EXTENTS.x - 40.0
const LT_CROWD_MAX_ATTEMPTS : int = 30

func play_long() -> void:
	var bg_cover : ColorRect = _lt_cover_background()
	_lt_start_music()

	var crowd : Array = _lt_spawn_crowd()
	var pb    : TextureRect = _lt_spawn_playbutton()

	for _i in range(LT_HESITATE_COUNT):
		await _lt_hesitate_attempt(pb)
	await _lt_succeed_and_join(pb, crowd)
	await _lt_talk(crowd)
	await _lt_celebrate_until_music_ends(crowd)
	await _lt_breathe(crowd, 4)
	await _lt_exit(crowd)

	await _lt_stop_music()
	bg_cover.queue_free()


func _lt_start_music() -> void:
	if not ResourceLoader.exists(LONG_BGM):
		return
	_lt_music_player = AudioStreamPlayer.new()
	_lt_music_player.stream = load(LONG_BGM)
	add_child(_lt_music_player)
	_lt_music_player.play()
	_lt_music_start_ms = Time.get_ticks_msec()


func _lt_stop_music() -> void:
	if _lt_music_player == null:
		return
	var fade := create_tween()
	fade.tween_property(_lt_music_player, "volume_db", -40.0, 0.6)
	await fade.finished
	_lt_music_player.stop()
	_lt_music_player.queue_free()
	_lt_music_player = null


func _lt_spawn_playbutton() -> TextureRect:
	var tex : Texture2D = load(PLAYBUTTON_TEXTURE_PATH)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size = LT_PLAYBUTTON_SIZE
	rect.pivot_offset = LT_PLAYBUTTON_SIZE / 2.0
	rect.position = Vector2(LT_START_X, LT_GROUND_Y) - rect.pivot_offset
	add_child(rect)
	return rect


func _lt_spawn_crowd() -> Array:
	var crowd  : Array = []
	var placed : Array = []
	var tex : Texture2D = load(PLAYBUTTON_TEXTURE_PATH)
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
		_lt_start_encourage_bob(rect)
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


# Gentle "encouraging" bounce + breathe, active the WHOLE time the group is
# waiting — per the locked story, they're cheering the crossing Play Button
# on throughout its hesitation and attempts, not just reacting after it
# arrives. Gentler than the celebration dance's breathe (1.08x vs 1.18x) —
# this is patient waiting, not the crazy post-join celebration.
const LT_ENCOURAGE_BREATHE_SCALE : float = 1.08

func _lt_start_encourage_bob(node: Control) -> void:
	var base : Vector2 = node.position
	var t := create_tween()
	node.set_meta("bob_tween", t)
	t.set_loops()
	t.tween_interval(randf() * 0.3)
	t.tween_property(node, "position:y", base.y - 8.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(node, "scale", Vector2.ONE * LT_ENCOURAGE_BREATHE_SCALE, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "position:y", base.y, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(node, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Dance: hop + swirl combined, for the shared celebration beat once Play
# Button has joined the group — a 5-beat loop (hop up, swirl one way, hop
# down, swirl back, settle) rather than a plain bounce.
const LT_CELEBRATE_HOP_HEIGHT    : float = 28.0    # up from 16 — "bounce crazily"
const LT_CELEBRATE_SWIRL_ANGLE   : float = 50.0    # up from 30
const LT_CELEBRATE_BEAT_DUR      : float = 0.11    # down from 0.15 — faster, more frantic
const LT_CELEBRATE_BREATHE_SCALE : float = 1.18    # scale pulse layered on top — the "breathe" part

func _lt_start_celebrate_bob(node: Control) -> void:
	var base : Vector2 = node.position
	var t := create_tween()
	node.set_meta("bob_tween", t)
	t.set_loops()
	t.tween_property(node, "position:y", base.y - LT_CELEBRATE_HOP_HEIGHT, LT_CELEBRATE_BEAT_DUR) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(node, "scale", Vector2.ONE * LT_CELEBRATE_BREATHE_SCALE, LT_CELEBRATE_BEAT_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "rotation_degrees", LT_CELEBRATE_SWIRL_ANGLE, LT_CELEBRATE_BEAT_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position:y", base.y, LT_CELEBRATE_BEAT_DUR) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(node, "scale", Vector2.ONE, LT_CELEBRATE_BEAT_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(node, "rotation_degrees", -LT_CELEBRATE_SWIRL_ANGLE, LT_CELEBRATE_BEAT_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(node, "rotation_degrees", 0.0, LT_CELEBRATE_BEAT_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Takes a few steps toward the group, then gets nervous and walks back —
# one full attempt. Called LT_HESITATE_COUNT times in a row from play_long().
func _lt_hesitate_attempt(pb: TextureRect) -> void:
	var approach := create_tween()
	approach.tween_property(pb, "position:x", LT_HESITATE_APPROACH_X - pb.size.x / 2.0, LT_HESITATE_APPROACH_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await approach.finished

	var retreat := create_tween()
	retreat.tween_property(pb, "position:x", LT_START_X - pb.size.x / 2.0, LT_HESITATE_RETREAT_DUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await retreat.finished


# Finally gathers courage and walks all the way to the group — normal pace
# for most of it, speeding up slightly with excitement as it gets close —
# and settles in among them.
func _lt_succeed_and_join(pb: TextureRect, crowd: Array) -> void:
	var speedup_x : float = LT_START_X + (LT_JOIN_X - LT_START_X) * LT_SPEEDUP_FRACTION

	var normal_dist : float = speedup_x - LT_START_X
	var fast_dist    : float = LT_JOIN_X - speedup_x
	var full_dist    : float = LT_JOIN_X - LT_START_X
	var normal_dur : float = LT_CROSS_DUR * (normal_dist / full_dist)
	var fast_dur    : float = (LT_CROSS_DUR * (fast_dist / full_dist)) / LT_SPEEDUP_MULT

	var t1 := create_tween()
	t1.tween_property(pb, "position:x", speedup_x - pb.size.x / 2.0, normal_dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t1.finished

	var t2 := create_tween()
	t2.tween_property(pb, "position:x", LT_JOIN_X - pb.size.x / 2.0, fast_dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t2.finished

	crowd.append(pb)


# They "talk" — 5 gentle bob/breathe cycles together, everyone in sync,
# before the more energetic celebration dance starts.
const LT_TALK_COUNT      : int   = 5
const LT_TALK_BOB_HEIGHT : float = 6.0
const LT_TALK_BEAT_DUR   : float = 0.45

func _lt_talk(crowd: Array) -> void:
	for node in crowd:
		if is_instance_valid(node) and node.has_meta("bob_tween"):
			var old_bob : Tween = node.get_meta("bob_tween")
			if old_bob != null and old_bob.is_valid():
				old_bob.kill()

	for _i in range(LT_TALK_COUNT):
		var up := create_tween()
		up.set_parallel(true)
		for node in crowd:
			if is_instance_valid(node):
				up.tween_property(node, "position:y", node.position.y - LT_TALK_BOB_HEIGHT, LT_TALK_BEAT_DUR) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await up.finished

		var down := create_tween()
		down.set_parallel(true)
		for node in crowd:
			if is_instance_valid(node):
				down.tween_property(node, "position:y", node.position.y + LT_TALK_BOB_HEIGHT, LT_TALK_BEAT_DUR) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await down.finished


# A calmer beat after the dance winds down — pure scale-pulse breathing
# (no hop/swirl), `count` times, right before everyone exits.
const LT_BREATHE_SCALE : float = 1.12
const LT_BREATHE_DUR   : float = 0.35

func _lt_breathe(crowd: Array, count: int) -> void:
	for node in crowd:
		if is_instance_valid(node) and node.has_meta("bob_tween"):
			var old_bob : Tween = node.get_meta("bob_tween")
			if old_bob != null and old_bob.is_valid():
				old_bob.kill()
			node.rotation_degrees = 0.0

	for _i in range(count):
		var up := create_tween()
		up.set_parallel(true)
		for node in crowd:
			if is_instance_valid(node):
				up.tween_property(node, "scale", Vector2.ONE * LT_BREATHE_SCALE, LT_BREATHE_DUR) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await up.finished

		var down := create_tween()
		down.set_parallel(true)
		for node in crowd:
			if is_instance_valid(node):
				down.tween_property(node, "scale", Vector2.ONE, LT_BREATHE_DUR) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await down.finished


# The whole group — waiting crowd + the newly-joined Play Button — dances
# (hop+swirl) together for as long as the BGM keeps playing, so the full
# track is heard rather than being cut short by the animation's own pacing.
func _lt_celebrate_until_music_ends(crowd: Array) -> void:
	for node in crowd:
		if not is_instance_valid(node):
			continue
		# pb (just joined) never had a bob tween — only the waiting crowd
		# faces do — so guard with has_meta() rather than relying on
		# get_meta()'s default, which still logs a missing-key error.
		if node.has_meta("bob_tween"):
			var old_bob : Tween = node.get_meta("bob_tween")
			if old_bob != null and old_bob.is_valid():
				old_bob.kill()
		_lt_start_celebrate_bob(node)
	# Wait out the track's own known duration, minus a reserved tail so the
	# breathe + hop-away exit beats that follow still have ~10s of music
	# playing under them instead of finishing in silence. Duration-based
	# (not the `finished` signal) — that resolved near-instantly in testing
	# despite `playing` reporting true (an audio-session quirk with how
	# these background test launches get audio device access; duration math
	# sidesteps it either way and is the more robust approach anyway).
	if _lt_music_player != null:
		var elapsed_sec : float = float(Time.get_ticks_msec() - _lt_music_start_ms) / 1000.0
		var remaining : float = _lt_music_player.stream.get_length() - elapsed_sec - LT_MUSIC_OUTRO_RESERVE
		if remaining > 0.0:
			await get_tree().create_timer(remaining).timeout


# The dance keeps playing (bob_tween is NOT killed here) while everyone
# walks off — "hop together and gone," not dance-then-plain-walk.
# Everyone hops (bounces while advancing) rather than a plain slide off.
const LT_EXIT_HOP_COUNT  : int   = 6
const LT_EXIT_HOP_HEIGHT : float = 18.0

func _lt_exit(crowd: Array) -> void:
	var step_dur : float = LT_EXIT_DUR / float(LT_EXIT_HOP_COUNT)
	var dx : float = LT_EXIT_DX / float(LT_EXIT_HOP_COUNT)
	for _i in range(LT_EXIT_HOP_COUNT):
		var up := create_tween()
		up.set_parallel(true)
		for node in crowd:
			if is_instance_valid(node):
				up.tween_property(node, "position", node.position + Vector2(dx, -LT_EXIT_HOP_HEIGHT), step_dur * 0.5) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await up.finished

		var down := create_tween()
		down.set_parallel(true)
		for node in crowd:
			if is_instance_valid(node):
				down.tween_property(node, "position:y", node.position.y + LT_EXIT_HOP_HEIGHT, step_dur * 0.5) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await down.finished

	for node in crowd:
		if is_instance_valid(node):
			if node.has_meta("bob_tween"):
				var old_bob : Tween = node.get_meta("bob_tween")
				if old_bob != null and old_bob.is_valid():
					old_bob.kill()
			node.queue_free()
