extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
# WorldManager
# ─────────────────────────────────────────────────────────────────────────────
# Generates the dungeon layout, instantiates room scenes at their world-space
# positions, and handles the transition when the player walks through a door.
#
# All rooms are live in the scene tree simultaneously.
# Camera limits enforce the "one room visible at a time" feel.
# ─────────────────────────────────────────────────────────────────────────────

const ROOM_SCENE : PackedScene = preload("res://scenes/room.tscn")

const TILE_SIZE  : float = 64.0
const ROOM_W     : int   = 15
const ROOM_H     : int   = 11
const ROOM_PX_W  : float = ROOM_W * TILE_SIZE   # 960 px
const ROOM_PX_H  : float = ROOM_H * TILE_SIZE   # 704 px

@export var dungeon_seed   : int   = 0
@export var use_fixed_seed : bool  = false
@export var max_rooms      : int   = 10

@onready var camera     : Camera2D        = $Camera2D
@onready var player     : CharacterBody2D = $LemonadeCharacter
@onready var rooms_node : Node2D          = $Rooms

var layout           : Dictionary = {}
var room_nodes       : Dictionary = {}
var current_grid_pos : Vector2i


func _ready() -> void:
	current_grid_pos = Vector2i(DungeonGenerator.GRID_W / 2, DungeonGenerator.GRID_H / 2)
	var seed_val : int = dungeon_seed if use_fixed_seed else randi()
	layout = DungeonGenerator.generate(seed_val, max_rooms)
	_instantiate_rooms()
	_enter_room(current_grid_pos, "")


func _process(_delta: float) -> void:
	# Camera tracks player. Limits (set per room) keep it inside room bounds.
	camera.global_position = player.global_position


# ── Room Instantiation ────────────────────────────────────────────────────────

func _instantiate_rooms() -> void:
	for grid_pos: Vector2i in layout:
		var cfg  : RoomConfig = layout[grid_pos]
		var room              = ROOM_SCENE.instantiate()

		# Set config BEFORE add_child so _ready() on the room sees it.
		room.room_config = cfg
		room.position    = _grid_to_world(grid_pos)
		rooms_node.add_child(room)
		room_nodes[grid_pos] = room

		# Connect the room's door signal. Bind the grid pos so we know which room fired.
		room.door_entered.connect(_on_door_entered.bind(grid_pos))


# ── Door Transition ───────────────────────────────────────────────────────────

func _on_door_entered(direction: String, from_grid: Vector2i) -> void:
	# Ignore stale signals from rooms the player has already left.
	if from_grid != current_grid_pos:
		return

	var next : Vector2i = from_grid + DungeonGenerator.DIRS[direction]
	if next in layout:
		_enter_room(next, DungeonGenerator.OPPOSITE[direction])


func _enter_room(grid_pos: Vector2i, entry_dir: String) -> void:
	current_grid_pos = grid_pos
	var origin : Vector2 = _grid_to_world(grid_pos)

	# Lock camera to this room's pixel bounds.
	camera.limit_left   = int(origin.x)
	camera.limit_top    = int(origin.y)
	camera.limit_right  = int(origin.x + ROOM_PX_W)
	camera.limit_bottom = int(origin.y + ROOM_PX_H)

	# Teleport player to the appropriate entry point.
	player.velocity        = Vector2.ZERO
	player.global_position = _entry_position(grid_pos, entry_dir)
	camera.reset_smoothing()


func _entry_position(grid_pos: Vector2i, entry_dir: String) -> Vector2:
	var origin : Vector2 = _grid_to_world(grid_pos)
	# Place the player 2 tiles inward from the door they walked through.
	var inset  : float   = TILE_SIZE * 2.0
	match entry_dir:
		"n": return origin + Vector2(7.5 * TILE_SIZE, inset)
		"s": return origin + Vector2(7.5 * TILE_SIZE, ROOM_PX_H - inset)
		"w": return origin + Vector2(inset, 5.5 * TILE_SIZE)
		"e": return origin + Vector2(ROOM_PX_W - inset, 5.5 * TILE_SIZE)
	# No entry direction = starting room; place at centre.
	return origin + Vector2(ROOM_PX_W * 0.5, ROOM_PX_H * 0.5)


# ── Utilities ─────────────────────────────────────────────────────────────────

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos) * Vector2(ROOM_PX_W, ROOM_PX_H)
