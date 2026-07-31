class_name MazeGenerator

# Recursive-backtracker (randomized DFS) spanning-tree maze generator for
# Sound Quest. A spanning tree has no loops, so there is always exactly one
# path from start to goal — matches the "hard wall, simple, predictable"
# design goal: the corridor is unambiguous, no branching decisions for the
# player to second-guess.
#
# Algorithm verified separately in Python across 3x3 through 7x7 grids
# (including the 2x2 edge case): every cell always ends up visited, and the
# traced start->goal path is always contiguous.

const DEFAULT_COLS : int = 5
const DEFAULT_ROWS : int = 5

# Per-cell bitmask of which walls are OPEN (passable).
const N : int = 1
const S : int = 2
const E : int = 4
const W : int = 8

const DIRS      : Array[int] = [N, S, E, W]
const DX         : Dictionary = {1: 0, 2: 0, 4: 1, 8: -1}   # N,S,E,W -> dx  (E:1  W:-1)
const DY         : Dictionary = {1: -1, 2: 1, 4: 0, 8: 0}   # N,S,E,W -> dy  (N:-1 S:1)
const OPPOSITE   : Dictionary = {1: 2, 2: 1, 4: 8, 8: 4}    # N<->S, E<->W


class MazeData:
	var cols       : int
	var rows       : int
	var cell_size  : float
	var origin     : Vector2          # top-left of the maze, in the parent's local coords
	var passages   : Array            # passages[y][x] = open-wall bitmask
	var start_cell : Vector2i
	var goal_cell  : Vector2i
	var path_cells : Array            # Array[Vector2i], ordered start -> goal (the one true route)

	func cell_center(cell: Vector2i) -> Vector2:
		return origin + Vector2(
			(cell.x + 0.5) * cell_size,
			(cell.y + 0.5) * cell_size
		)

	func cell_rect(cell: Vector2i) -> Rect2:
		var c    : Vector2 = cell_center(cell)
		var half : float   = cell_size * 0.5
		return Rect2(c - Vector2(half, half), Vector2(cell_size, cell_size))

	func start_pos() -> Vector2:
		return cell_center(start_cell)

	func goal_pos() -> Vector2:
		return cell_center(goal_cell)

	# Corridor = union of every cell on the path plus a doorway rect bridging
	# each consecutive pair, so the shared edge between two adjacent path
	# cells isn't a wall-width gap in the collision area.
	func corridor_rects() -> Array:
		var rects : Array = []
		for cell in path_cells:
			rects.append(cell_rect(cell))
		for i in range(path_cells.size() - 1):
			rects.append(_doorway_rect(path_cells[i], path_cells[i + 1]))
		return rects

	func _doorway_rect(a: Vector2i, b: Vector2i) -> Rect2:
		var ca : Vector2 = cell_center(a)
		var cb : Vector2 = cell_center(b)
		var pad : Vector2 = Vector2(cell_size, cell_size) * 0.5
		var min_pt : Vector2 = Vector2(min(ca.x, cb.x), min(ca.y, cb.y)) - pad
		var max_pt : Vector2 = Vector2(max(ca.x, cb.x), max(ca.y, cb.y)) + pad
		return Rect2(min_pt, max_pt - min_pt)

	func is_point_in_corridor(point: Vector2) -> bool:
		for rect in corridor_rects():
			if rect.has_point(point):
				return true
		return false

	# ─── Full-maze gameplay collision ──────────────────────────────────────
	# Wandering the WHOLE connected maze structure (every branch, dead ends
	# included — wall_segments() below renders the whole grid, so a child
	# can see and wander into any of them) needs a different check than
	# corridor_rects() above: since adjacent cells' rects are geometrically
	# contiguous (touching with zero gap — that's just grid geometry)
	# regardless of whether the wall between them is open, a plain
	# "is this point inside the union of every visited cell's rect" test
	# can't actually tell a real dead end apart from crossing a genuinely
	# closed wall — both cells' rects exist and touch either way. Instead,
	# track which CELL the drag currently occupies and only allow moving to
	# an adjacent cell when that specific connection is open per passages.
	func cell_at(point: Vector2) -> Vector2i:
		var local : Vector2 = point - origin
		return Vector2i(int(floor(local.x / cell_size)), int(floor(local.y / cell_size)))

	func is_cell_valid(cell: Vector2i) -> bool:
		return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows \
			and passages[cell.y][cell.x] != 0

	# True if the drag can move from cell a directly into cell b: staying
	# in the same cell is always fine; moving to an orthogonally adjacent
	# cell is fine only if that specific wall is open; anything else
	# (diagonal jump, non-adjacent, out of bounds) is rejected — the caller
	# is expected to break a big move into smaller per-axis steps instead
	# (see sound_quest.gd's _update_maze_drag() sliding logic).
	func can_move_between(a: Vector2i, b: Vector2i) -> bool:
		if a == b:
			return true
		if not is_cell_valid(a) or not is_cell_valid(b):
			return false
		var dx : int = b.x - a.x
		var dy : int = b.y - a.y
		if abs(dx) + abs(dy) != 1:
			return false
		var dir : int = E if dx == 1 else (W if dx == -1 else (S if dy == 1 else N))
		return (passages[a.y][a.x] & dir) != 0

	# One line segment per CLOSED edge (wall) — for Line2D rendering. Renders
	# the whole grid (every cell's closed edges), dead-end branches included
	# — see can_move_between() above, which is what makes those branches
	# actually explorable rather than just visually present.
	#
	# The maze's outer boundary is otherwise fully sealed by construction —
	# an edge cell's bit facing outward is never set by generate() (there's
	# no neighbor beyond the grid to open toward). So a single door is cut by
	# skipping exactly one boundary segment on whichever edge start_cell (the
	# entry) or goal_cell (the exit) actually sits on — top, left, right, or
	# bottom, whichever applies — nowhere else, matching "no open contour
	# except the entry and exit."
	func wall_segments() -> Array:
		var segs : Array = []
		for y in range(rows):
			for x in range(cols):
				var open : int    = passages[y][x]
				var cell : Vector2i = Vector2i(x, y)
				var tl   : Vector2 = origin + Vector2(x * cell_size, y * cell_size)
				var tr   : Vector2 = tl + Vector2(cell_size, 0)
				var bl   : Vector2 = tl + Vector2(0, cell_size)
				var br   : Vector2 = tl + Vector2(cell_size, cell_size)
				var is_entry : bool = cell == start_cell
				var is_exit  : bool = cell == goal_cell
				if open & N == 0 and not (is_entry and start_cell.y == 0):
					segs.append([tl, tr])
				if open & S == 0 and not (is_exit and goal_cell.y == rows - 1):
					segs.append([bl, br])
				if open & E == 0 and not (is_exit and goal_cell.x == cols - 1):
					segs.append([tr, br])
				if open & W == 0 and not (is_entry and start_cell.x == 0):
					segs.append([tl, bl])
		return segs


# Style presets bias the backtracker's neighbor choice, controlling whether
# the resulting corridor reads as a gentle curve, a zigzag, a longer wind, or
# a spiral-ish curl. Style never affects maze correctness — every style still
# always produces a fully-connected spanning tree with exactly one path, it
# only influences *which* valid tree gets generated. There is deliberately no
# "straight" style: the maze box is compact, so a literal straight run would
# neither use the space nor build any fine-motor-skill value.
const STYLE_CURVE   : String = "curve"
const STYLE_ZIGZAG  : String = "zigzag"
const STYLE_WINDING : String = "winding"
const STYLE_SPIRAL  : String = "spiral"

# Clockwise rotation of the last direction (N->E->S->W->N) — used by the
# spiral bias to favor consistently turning the same rotational way.
const CLOCKWISE : Dictionary = {1: 4, 4: 2, 2: 8, 8: 1}

static func generate(cols: int = DEFAULT_COLS, rows: int = DEFAULT_ROWS,
		cell_size: float = 80.0, origin: Vector2 = Vector2.ZERO,
		style: String = STYLE_CURVE, start_cell: Vector2i = Vector2i(0, 0),
		goal_col: int = -1) -> MazeData:
	var data : MazeData = MazeData.new()
	data.cols      = cols
	data.rows      = rows
	data.cell_size = cell_size
	data.origin    = origin

	var passages : Array = []
	var visited  : Array = []
	for y in range(rows):
		var prow : Array = []
		var vrow : Array = []
		for x in range(cols):
			prow.append(0)
			vrow.append(false)
		passages.append(prow)
		visited.append(vrow)

	var start : Vector2i = start_cell
	var stack : Array[Vector2i] = [start]
	# Direction that led INTO each cell on the stack (0 = start, no direction
	# yet), tracked per stack frame rather than as one running variable — this
	# keeps the style bias correct across backtracks: after popping back to an
	# earlier cell, its "last direction" is whatever direction originally led
	# into it, not the direction of the branch that was just abandoned.
	var dir_stack : Array[int] = [0]
	visited[start.y][start.x] = true
	var order : Array[Vector2i] = [start]

	while stack.size() > 0:
		var current  : Vector2i = stack[-1]
		var last_dir : int      = dir_stack[-1]
		var neighbors : Array = _unvisited_neighbors(current, cols, rows, visited)
		if neighbors.is_empty():
			stack.pop_back()
			dir_stack.pop_back()
			continue
		var choice : Array = _weighted_pick(neighbors, last_dir, style)
		var dir  : int     = choice[0]
		var next : Vector2i = choice[1]
		passages[current.y][current.x] |= dir
		passages[next.y][next.x]       |= OPPOSITE[dir]
		visited[next.y][next.x] = true
		stack.append(next)
		dir_stack.append(dir)
		order.append(next)

	data.passages   = passages
	data.start_cell = start
	# Goal defaults to the last cell carved by the backtracker — always the
	# far end of some branch, never adjacent to start in a trivial way. When
	# goal_col is given (Sound Quest's shared maze, exit always on the right
	# edge), pick randomly among the visited cells in that column instead —
	# every cell is visited by construction (full spanning tree), so that
	# column always has at least one valid candidate.
	if goal_col >= 0:
		var candidates : Array[Vector2i] = []
		for y in range(rows):
			if visited[y][goal_col]:
				candidates.append(Vector2i(goal_col, y))
		data.goal_cell = candidates[randi() % candidates.size()] if not candidates.is_empty() else order[-1]
	else:
		data.goal_cell = order[-1]
	data.path_cells = _trace_path(passages, data.start_cell, data.goal_cell)
	return data


# Weighted neighbor choice: how strongly a style favors continuing last_dir
# (or, for spiral, favors the clockwise-rotated direction) over turning.
static func _weighted_pick(neighbors: Array, last_dir: int, style: String) -> Array:
	if last_dir == 0 or neighbors.size() == 1:
		return neighbors[randi() % neighbors.size()]
	var weights : Array[float] = []
	var total   : float        = 0.0
	for n in neighbors:
		var dir : int   = n[0]
		var w   : float = 1.0
		match style:
			STYLE_CURVE:
				w = 3.0 if dir == last_dir else 1.0
			STYLE_ZIGZAG:
				w = 0.2 if dir == last_dir else 1.0
			STYLE_WINDING:
				w = 1.3 if dir == last_dir else 1.0
			STYLE_SPIRAL:
				if dir == CLOCKWISE.get(last_dir, -1):
					w = 6.0
				elif dir == last_dir:
					w = 2.0
				else:
					w = 1.0
		weights.append(w)
		total += w
	var r : float = randf() * total
	for i in range(neighbors.size()):
		r -= weights[i]
		if r <= 0.0:
			return neighbors[i]
	return neighbors[-1]


static func _unvisited_neighbors(cell: Vector2i, cols: int, rows: int, visited: Array) -> Array:
	var result : Array = []
	for dir in DIRS:
		var nx : int = cell.x + DX[dir]
		var ny : int = cell.y + DY[dir]
		if nx < 0 or nx >= cols or ny < 0 or ny >= rows:
			continue
		if visited[ny][nx]:
			continue
		result.append([dir, Vector2i(nx, ny)])
	return result


# BFS from start to goal along open passages. The maze is a spanning tree, so
# exactly one such path always exists.
static func _trace_path(passages: Array, start: Vector2i, goal: Vector2i) -> Array:
	var came_from : Dictionary = {}
	var queue     : Array[Vector2i] = [start]
	var seen      : Dictionary = {start: true}
	while queue.size() > 0:
		var cur : Vector2i = queue.pop_front()
		if cur == goal:
			break
		var open : int = passages[cur.y][cur.x]
		for dir in DIRS:
			if open & dir == 0:
				continue
			var nxt : Vector2i = Vector2i(cur.x + DX[dir], cur.y + DY[dir])
			if seen.has(nxt):
				continue
			seen[nxt] = true
			came_from[nxt] = cur
			queue.append(nxt)
	var path : Array[Vector2i] = [goal]
	var walker : Vector2i = goal
	while walker != start:
		walker = came_from[walker]
		path.append(walker)
	path.reverse()
	return path
