class_name ProgressStatus

# Progress and access, kept separate (locked rule).
#
#   Progress  — what the child has actually done: SaveManager's explicit
#               sets_entered / sets_completed records. Never inferred from the
#               resume cursor or from ×N play counts.
#   Access    — whether a Set can be entered right now: the first Set of a Level
#               is always open; once it has actually been attempted every other
#               Set in that Level is open; a verified subscription is needed for
#               everything except Prep's free Sets. Access never changes a record.
#
# Pure functions: they read state and decide, they never write it.

enum Step { CORONATION, NEXT_SET, PAYWALL, WHERE_AM_I }

# What Where Am I shows for a Set, a Group or a Level. Derived only from the
# explicit records and the access rules — never from the resume cursor.
enum Status { NOT_STARTED, IN_PROGRESS, COMPLETED, LOCKED }


static func completed_count(level_id: String) -> int:
	var n : int = 0
	for key : String in ReleaseScope.set_keys(level_id):
		if SaveManager.is_set_completed(key):
			n += 1
	return n


# Every required Set of the Level has been passed. A Level with no Sets yet is never complete.
static func all_required_completed(level_id: String) -> bool:
	var keys : Array[String] = ReleaseScope.set_keys(level_id)
	return not keys.is_empty() and completed_count(level_id) == keys.size()


static func first_set_attempted(level_id: String) -> bool:
	var keys : Array[String] = ReleaseScope.set_keys(level_id)
	return not keys.is_empty() and SaveManager.has_entered_set(keys[0])


# Subscription requirement for a Set. Prep keeps its free Sets (A1/A2); every Set
# of every other Level is premium and needs a verified subscription.
static func needs_subscription(level_id: String, index: int) -> bool:
	if level_id == "prep":
		return not PrepLevelProgress.is_set_accessible(index)
	return not SaveManager.is_subscribed()


static func is_set_accessible(level_id: String, index: int) -> bool:
	var keys : Array[String] = ReleaseScope.set_keys(level_id)
	if index < 0 or index >= keys.size():
		return false
	if needs_subscription(level_id, index):
		return false
	return index == 0 or first_set_attempted(level_id)


static func current_index(level_id: String) -> int:
	match level_id:
		"prep":    return PrepLevelProgress.current_index
		"level1":  return LevelProgress.current_index
		"level15": return Level15Progress.current_index
		"level2":  return Level2Progress.current_index
	return 0


# The Level has just become fully completed for the first time: every required
# Set is recorded and the Level's own completion flag is not yet set. That flag
# is what keeps the Coronation from ever repeating.
static func first_completion_ready(level_id: String) -> bool:
	return all_required_completed(level_id) and not ReleaseScope.is_level_completed(level_id)


# What follows a passed Set, in the approved order:
#   1. the Level just became fully completed for the first time -> Coronation
#   2. a following Set exists and the player may enter it         -> that Set
#   3. a following Set exists but needs a subscription            -> the paywall
#   4. otherwise (final Set, or nothing accessible follows)      -> Where Am I
# It never advances to the next Level while any required Set remains incomplete.
static func next_step(level_id: String) -> int:
	if first_completion_ready(level_id):
		return Step.CORONATION
	var next_index : int = current_index(level_id) + 1
	if next_index < ReleaseScope.set_keys(level_id).size():
		if is_set_accessible(level_id, next_index):
			return Step.NEXT_SET
		if needs_subscription(level_id, next_index):
			return Step.PAYWALL
	return Step.WHERE_AM_I


# A Set chosen from Where Am I must start as a fresh attempt, never inherit a
# half-finished incorrect-rounds retry.
static func clear_retry(level_id: String) -> void:
	match level_id:
		"prep":
			PrepLevelProgress.is_retry = false
			PrepLevelProgress.retry_rounds = []
		"level1":
			LevelProgress.is_retry = false
			LevelProgress.retry_rounds = []
			LevelProgress.last_run_was_retry = false
		"level15":
			Level15Progress.is_retry = false
			Level15Progress.retry_rounds = []
		"level2":
			Level2Progress.is_retry = false
			Level2Progress.retry_rounds = []


# LOCKED when the Set cannot be entered (it takes precedence over everything,
# including an earlier completion). Otherwise COMPLETED if it was passed by its
# Level's own criterion, IN_PROGRESS if it was actually entered but not passed,
# else NOT_STARTED.
static func set_status(level_id: String, index: int) -> int:
	if not is_set_accessible(level_id, index):
		return Status.LOCKED
	var key : String = ReleaseScope.set_key(level_id, index)
	if SaveManager.is_set_completed(key):
		return Status.COMPLETED
	if SaveManager.has_entered_set(key):
		return Status.IN_PROGRESS
	return Status.NOT_STARTED


# A Group (or chunk) reflects its required Sets: LOCKED only when none of them
# can be entered, COMPLETED only when every one is recorded as passed, IN_PROGRESS
# once any has been entered or passed, otherwise NOT_STARTED.
static func group_status(level_id: String, indices: Array) -> int:
	var any_accessible : bool = false
	var all_completed  : bool = not indices.is_empty()
	var any_entered    : bool = false
	for index : int in indices:
		var key : String = ReleaseScope.set_key(level_id, index)
		var done : bool = SaveManager.is_set_completed(key)
		if is_set_accessible(level_id, index):
			any_accessible = true
		if not done:
			all_completed = false
		if done or SaveManager.has_entered_set(key):
			any_entered = true
	if not any_accessible:
		return Status.LOCKED if not indices.is_empty() else Status.NOT_STARTED
	if all_completed:
		return Status.COMPLETED
	if any_entered:
		return Status.IN_PROGRESS
	return Status.NOT_STARTED


# A Level reflects all of its required Sets (its own lock cascade is separate and
# is applied by the caller). A Level with no Sets yet is NOT_STARTED.
static func level_status(level_id: String) -> int:
	var count : int = ReleaseScope.set_keys(level_id).size()
	if count == 0:
		return Status.NOT_STARTED
	var indices : Array = []
	for i in range(count):
		indices.append(i)
	return group_status(level_id, indices)
