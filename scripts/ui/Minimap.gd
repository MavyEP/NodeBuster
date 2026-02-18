extends Control

## Isaac-style minimap drawn in the top-right corner.
## Shows visited rooms, current room, known neighbors, boss/start markers,
## and connections between rooms.

# ---- Layout ----------------------------------------------------------------
const CELL_SIZE := Vector2(10, 8)
const CELL_GAP := 2.0
const CONN_THICKNESS := 2.0
const MARGIN := 6.0

# ---- Colours ---------------------------------------------------------------
const COLOR_CURRENT := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_VISITED := Color(0.5, 0.5, 0.55, 0.9)
const COLOR_CLEARED := Color(0.38, 0.38, 0.42, 0.85)
const COLOR_BOSS := Color(0.85, 0.15, 0.15, 1.0)
const COLOR_START := Color(0.2, 0.7, 0.3, 1.0)
const COLOR_UNKNOWN := Color(0.35, 0.35, 0.4, 0.5)
const COLOR_CONN := Color(0.4, 0.4, 0.45, 0.7)
const COLOR_BG := Color(0.0, 0.0, 0.0, 0.35)

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	RoomManager.room_entered.connect(_on_map_changed)
	RoomManager.room_cleared.connect(_on_map_changed)
	DungeonManager.dungeon_generated.connect(func(): queue_redraw())

func _on_map_changed(_pos: Vector2i):
	queue_redraw()

func _draw():
	var map: Dictionary = DungeonManager.dungeon_map
	if map.is_empty():
		return

	var current_pos: Vector2i = RoomManager.current_grid_pos

	# --- Determine grid bounds -----------------------------------------------
	var min_g := Vector2i(999, 999)
	var max_g := Vector2i(-999, -999)
	for pos in map:
		min_g.x = mini(min_g.x, pos.x)
		min_g.y = mini(min_g.y, pos.y)
		max_g.x = maxi(max_g.x, pos.x)
		max_g.y = maxi(max_g.y, pos.y)

	var step := CELL_SIZE + Vector2(CELL_GAP, CELL_GAP)
	var cols: int = max_g.x - min_g.x + 1
	var rows: int = max_g.y - min_g.y + 1
	var map_px := Vector2(cols * step.x - CELL_GAP, rows * step.y - CELL_GAP)

	# Anchor to top-right of the control
	var origin := Vector2(size.x - map_px.x - MARGIN, MARGIN)

	# --- Background panel ----------------------------------------------------
	draw_rect(Rect2(origin - Vector2(4, 4), map_px + Vector2(8, 8)), COLOR_BG)

	# --- Collect "known" rooms (adjacent to visited but not yet visited) -----
	var known: Dictionary = {}   # Vector2i -> true
	for pos in map:
		var info = map[pos]
		if not info.is_visited:
			continue
		for dir_name in info.connections:
			var neighbor: Vector2i = info.connections[dir_name]
			if map.has(neighbor) and not map[neighbor].is_visited:
				known[neighbor] = true

	# --- Draw connections (behind cells) -------------------------------------
	var _drawn_conns: Dictionary = {}   # avoid drawing the same link twice
	for pos in map:
		var info = map[pos]
		if not info.is_visited and not known.has(pos):
			continue
		var cell_center: Vector2 = origin + Vector2(
			(pos.x - min_g.x) * step.x + CELL_SIZE.x / 2.0,
			(pos.y - min_g.y) * step.y + CELL_SIZE.y / 2.0)

		for dir_name in info.connections:
			var neighbor: Vector2i = info.connections[dir_name]
			if not map.has(neighbor):
				continue
			var n_info = map[neighbor]
			if not n_info.is_visited and not known.has(neighbor):
				continue

			# Deduplicate
			var key_a = pos * 1000 + neighbor
			var key_b = neighbor * 1000 + pos
			if _drawn_conns.has(key_a) or _drawn_conns.has(key_b):
				continue
			_drawn_conns[key_a] = true

			var n_center: Vector2 = origin + Vector2(
				(neighbor.x - min_g.x) * step.x + CELL_SIZE.x / 2.0,
				(neighbor.y - min_g.y) * step.y + CELL_SIZE.y / 2.0)

			# Draw connector rect in the gap between cells
			match dir_name:
				"north", "south":
					var top_y := minf(cell_center.y, n_center.y) + CELL_SIZE.y / 2.0
					var bot_y := maxf(cell_center.y, n_center.y) - CELL_SIZE.y / 2.0
					draw_rect(Rect2(
						cell_center.x - CONN_THICKNESS / 2.0, top_y,
						CONN_THICKNESS, bot_y - top_y), COLOR_CONN)
				"east", "west":
					var left_x := minf(cell_center.x, n_center.x) + CELL_SIZE.x / 2.0
					var right_x := maxf(cell_center.x, n_center.x) - CELL_SIZE.x / 2.0
					draw_rect(Rect2(
						left_x, cell_center.y - CONN_THICKNESS / 2.0,
						right_x - left_x, CONN_THICKNESS), COLOR_CONN)

	# --- Draw room cells -----------------------------------------------------
	for pos in map:
		var info = map[pos]
		var is_known := known.has(pos)

		if not info.is_visited and not is_known:
			continue

		var cell_origin := origin + Vector2(
			(pos.x - min_g.x) * step.x,
			(pos.y - min_g.y) * step.y)
		var rect := Rect2(cell_origin, CELL_SIZE)

		if pos == current_pos:
			draw_rect(rect, COLOR_CURRENT)
		elif not info.is_visited:
			# Known but unvisited — outline only
			draw_rect(rect, COLOR_UNKNOWN, false, 1.0)
		elif info.is_boss_room:
			draw_rect(rect, COLOR_BOSS)
		elif info.is_start:
			draw_rect(rect, COLOR_START)
		elif info.is_cleared:
			draw_rect(rect, COLOR_CLEARED)
		else:
			draw_rect(rect, COLOR_VISITED)
