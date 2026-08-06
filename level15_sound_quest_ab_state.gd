class_name Level15SoundQuestABState

# Handoff state for level15_sound_quest_ab.gd — set before change_scene_to_file,
# read once in _ready(). One shared scene serves both Quest A (Initial
# Identification) and Quest B (Final Identification); these two values are
# the only thing that distinguishes them.
static var position     : String = "initial"   # "initial" (Quest A) or "final" (Quest B)
static var total_rounds : int    = 32           # 32 for Quest A, 40 for Quest B
