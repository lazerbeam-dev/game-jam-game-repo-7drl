class_name DungeonGenerator

# ─────────────────────────────────────────────────────────────────────────────
# DungeonGenerator
# ─────────────────────────────────────────────────────────────────────────────
# Produces a Binding of Isaac-style grid of connected rooms using a depth-first
# random walk with backtracking. Returns a Dictionary[Vector2i, RoomConfig].
#
# All randomness is driven by the supplied seed so the same seed always
# produces the same layout.
# ─────────────────────────────────────────────────────────────────────────────

const GRID_W : int = 7
const GRID_H : int = 7

## Cardinal direction vectors (grid units).
const DIRS : Dictionary = {
	"e": Vector2i( 1,  0),
	"w": Vector2i(-1,  0),
	"s": Vector2i( 0,  1),
	"n": Vector2i( 0, -1),
}

## Reverse direction look-up.
const OPPOSITE : Dictionary = { "e": "w", "w": "e", "n": "s", "s": "n" }


## Generate a connected dungeon layout.
## Returns Dictionary[Vector2i, RoomConfig] — one entry per room.
static func generate(seed: int, max_rooms: int = 10) -> Dictionary:
	var rng  := RandomNumberGenerator.new()
	rng.seed  = seed

	var grid  : Dictionary = {}   # Vector2i -> RoomConfig
	var stack : Array      = []
	var start : Vector2i   = Vector2i(GRID_W / 2, GRID_H / 2)   # centre of grid

	_add_room(grid, start, rng)
	stack.append(start)

	while grid.size() < max_rooms and stack.size() > 0:
		var current : Vector2i = stack.back()

		# Shuffle directions deterministically with our rng
		var dir_keys : Array = DIRS.keys()
		_shuffle(dir_keys, rng)

		var moved := false
		for dir_key : String in dir_keys:
			var next : Vector2i = current + DIRS[dir_key]
			if _in_bounds(next) and next not in grid:
				# Connect the two rooms
				grid[current].doors[dir_key]          = true
				_add_room(grid, next, rng)
				grid[next].doors[OPPOSITE[dir_key]]   = true
				stack.append(next)
				moved = true
				break   # Depth-first: go deeper before branching

		if not moved:
			stack.pop_back()   # Backtrack when no unvisited neighbours remain

	return grid


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _add_room(grid: Dictionary, pos: Vector2i, rng: RandomNumberGenerator) -> void:
	var cfg       := RoomConfig.new()
	cfg.grid_pos   = pos
	cfg.room_seed  = rng.randi()
	cfg.wear       = rng.randf_range(0.05, 0.55)
	grid[pos]      = cfg


static func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < GRID_W and p.y >= 0 and p.y < GRID_H


## Deterministic Fisher-Yates shuffle using the provided RNG instance.
static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j  : int = rng.randi_range(0, i)
		var tmp      = arr[i]
		arr[i]       = arr[j]
		arr[j]       = tmp
