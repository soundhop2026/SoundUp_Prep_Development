class_name Level15SoundQuestCDState

# Handoff state for level15_sound_quest_cd.gd — set before change_scene_to_file,
# read once in _ready(). One shared scene serves both Quest C (Initial
# Isolation) and Quest D (Final Isolation); these two values are the only
# thing that distinguishes them, same pattern as Level15SoundQuestABState.
static var position     : String = "initial"   # "initial" (Quest C) or "final" (Quest D)
static var total_rounds : int    = 56          # 56 for both Quest C and Quest D (4 Sets x 14)
