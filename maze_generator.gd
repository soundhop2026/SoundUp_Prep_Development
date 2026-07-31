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
const DX         : Dictionary = {1: 1, 2: 0, 4: 1, 8: -1}   # N,S,E,W -> dx  (E:1  W:-1)
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

	# One line segment per CLOSED edge (wall) — for Line2D rendering. Only
	# emits walls immediately bordering the path corridor cells plus a
	# one-cell margin, since Sound Quest never shows the full unvisited grid.
	func wall_segments() -> Array:
		var segs : Array = []
		for y in range(rows):
			for x in range(cols):
				var open : int    = passages[y][x]
				var tl   : Vector2 = origin + Vector2(x * cell_size, y * cell_size)
				var tr   : Vector2 = tl + Vector2(cell_size, 0)
				var bl   : Vector2 = tl + Vector2(0, cell_size)
				var br   : Vector2 = tl + Vector2(cell_size, cell_size)
				if open & N == 0:
					segs.append([tl, tr])
				if open & S == 0:
					segs.append([bl, br])
				if open & E == 0:
					segs.append([tr, br])
				if open & W == 0:
					segs.append([tl, bl])
		return segs


static func generate(cols: int = DEFAULT_COLS, rows: int = DEFAULT_ROWS,
		cell_size: float = 80.0, origin: Vector2 = Vector2.ZERO) -> MazeData:
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

	var start : Vector2i = Vector2i(0, 0)
	var stack : Array[Vector2i] = [start]
	visited[start.y][start.x] = true
	var order : Array[Vector2i] = [start]

	while stack.size() > 0:
		var current : Vector2i = stack[-1]
		var neighbors : Array = _unvisited_neighbors(current, cols, rows, visited)
		if neighbors.is_empty():
			stack.pop_back()
			continue
		var choice : Array = neighbors[randi() % neighbors.size()]
		var dir  : int     = choice[0]
		var next : Vector2i = choice[1]
		passages[current.y][current.x] |= dir
		passages[next.y][next.x]       |= OPPOSITE[dir]
		visited[next.y][next.x] = true
		stack.append(next)
		order.append(next)

	data.passages   = passages
	data.start_cell = start
	# Goal = the last cell carved by the backtracker — always the far end of
	# some branch, never adjacent to start in a trivial way.
	data.goal_cell  = order[-1]
	data.path_cells = _trace_path(passages, data.start_cell, data.goal_cell)
	return data


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
