class_name ReviewState

# Set active = true and set_key before routing to a game scene for replay.
# The game scene checks this at set-end only — no in-round logic is affected.
# Key format: "prep_A1", "level1_A1", "level15_1A", "level2_2A" etc.

static var active  : bool   = false
static var set_key : String = ""
