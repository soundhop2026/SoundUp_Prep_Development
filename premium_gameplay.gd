class_name PremiumGameplay

# Premium gameplay: everything except Prep Sets A1/A2.
# That is every other Prep Set, EVERY Sound Quest (Prep Quest A included), and ALL
# of Level 1, 1.5, 2 and any later Level.
#
# Two obligations for a premium gameplay scene:
#   1. An entry guard at the top of _ready(): refuse to start without a verified
#      subscription (see level_scene_admitted() / PrepLevelProgress).
#   2. Join GROUP and implement interrupt_for_entitlement_loss(), so confirmed
#      loss of the subscription stops it at once. A scene that only is premium
#      for some content (Prep) joins the group only when its content is premium.
#
# Adding a Level or Sound Quest scene: register its path in SCENE_PATHS. A test
# fails for any game / Sound Quest scene that is neither registered nor on the
# allowlist, and the entitlement service interrupts a registered scene even if
# it forgot to implement the method (generic route, no custom teardown).

const GROUP : String = "premium_gameplay"

const SCENE_PATHS : Array[String] = [
	"res://prep_game.tscn",
	"res://sound_quest.tscn",
	"res://game.tscn",
	"res://level1_sound_quest.tscn",
	"res://game15.tscn",
	"res://level15_sound_quest_ab.tscn",
	"res://level15_sound_quest_cd.tscn",
	"res://level15_sound_quest_e.tscn",
	"res://level15_sound_quest_f.tscn",
	"res://game2.tscn",
	"res://game25.tscn",   # Level 2 Sets I-L (the name is historical, it is not Level 2.5)
]


static func is_registered(path: String) -> bool:
	return path in SCENE_PATHS


# Level 1 and later scenes are premium in their entirety. QA debug launches
# (DebugConfig.debug_launch, never set in a release flow) bypass the guard.
static func level_scene_admitted() -> bool:
	return DebugConfig.debug_launch or SaveManager.is_subscribed()


# Registers a running premium scene for interruption and asks the store to
# re-verify now (coalesced with any request already in flight).
static func join(scene: Node) -> void:
	if DebugConfig.debug_launch:
		return   # QA launch from the debug menu: not an entitled session, never interrupted
	scene.add_to_group(GROUP)
	SaveManager.entitlement().refresh("premium_entry")


# Stops the scene taking input or processing, then goes to the existing
# subscription flow (Parent Gate -> plans). Writes nothing: no completion, no
# full-attempt count, cursor and records untouched.
static func refuse(scene: Node) -> void:
	scene.set_process(false)
	scene.set_physics_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	route_to_paywall(scene.get_tree())


# Silences every audio player under the scene (word sounds, music, effects).
static func stop_audio(root: Node) -> void:
	if root is AudioStreamPlayer or root is AudioStreamPlayer2D or root is AudioStreamPlayer3D:
		root.call("stop")
	for child in root.get_children():
		stop_audio(child)


static func route_to_paywall(tree: SceneTree) -> void:
	tree.paused = false
	ReviewState.active = false
	PremiumIntroState.context_id     = PremiumIntroState.CONTEXT_PREMIUM_LOCKED
	PremiumIntroState.boundary_index = -1
	tree.change_scene_to_file("res://premium_intro.tscn")
