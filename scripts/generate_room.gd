extends Node2D

## Emitted when the player walks through a door. Direction: "n"|"s"|"e"|"w".
signal door_entered(direction: String)

## Size of each tile in pixels. Must match tile_size_px in all four shaders.
const TILE_SIZE     := 64.0
const MONSTER_SCENE  = preload("res://scenes/monsters/monster.tscn")

## Room dimensions in tiles, including the one-tile-thick border wall.
@export var room_width  : int = 15
@export var room_height : int = 11

@onready var tile_material_manager: TileMaterialManager = $TileMaterialManager

## Set a fixed value to lock in a specific visual appearance for testing.
@export var fixed_seed: int = 0
## When true, always uses fixed_seed. When false, randomises each run.
@export var use_fixed_seed: bool = false

## Wear drives damage/rust/cracks across all materials (0 = pristine, 1 = destroyed).
@export_range(0.0, 1.0, 0.01) var wear_level: float = 0.2

## Set by WorldManager before add_child() so _ready() sees it.
## If null, the room uses its own fixed_seed / wear_level exports (standalone mode).
var room_config : RoomConfig = null


func _ready() -> void:
	if room_config:
		tile_material_manager.setup_room(room_config.room_seed, room_config.wear)
	else:
		var seed_value: int = fixed_seed if use_fixed_seed else randi()
		tile_material_manager.setup_room(seed_value, wear_level)
	_generate_room()


func _generate_room() -> void:
	var floor_cells : Array[Vector2i] = []
	var wall_cells  : Array[Vector2i] = []

	for y in room_height:
		for x in room_width:
			if x == 0 or x == room_width - 1 or y == 0 or y == room_height - 1:
				# Leave door openings — skip tiles that belong to an open door.
				if not _is_door_tile(x, y):
					wall_cells.append(Vector2i(x, y))
			else:
				floor_cells.append(Vector2i(x, y))

	_spawn_layer(floor_cells, tile_material_manager.material_dirt)
	_spawn_layer(wall_cells,  tile_material_manager.material_brick)
	_spawn_wall_collision(wall_cells)

	if room_config:
		_spawn_door_triggers()
		var centre := Vector2i(DungeonGenerator.GRID_W / 2, DungeonGenerator.GRID_H / 2)
		if room_config.grid_pos != centre:
			_spawn_monsters()


## Returns true if (x, y) is a tile that should be removed to form a door opening.
## Door positions (fixed, matching WorldManager's entry offsets):
##   North/South: centre 3 tiles wide (cols 6–8)
##   East/West:   centre 3 tiles tall  (rows 4–6)
func _is_door_tile(x: int, y: int) -> bool:
	if not room_config:
		return false
	var d : Dictionary = room_config.doors
	if d.get("n") and y == 0              and x >= 6 and x <= 8: return true
	if d.get("s") and y == room_height - 1 and x >= 6 and x <= 8: return true
	if d.get("w") and x == 0              and y >= 4 and y <= 6: return true
	if d.get("e") and x == room_width  - 1 and y >= 4 and y <= 6: return true
	return false


## Creates one StaticBody2D with a CollisionShape2D rectangle per wall tile.
## Uses only the non-door wall_cells already computed by _generate_room().
func _spawn_wall_collision(wall_cells: Array[Vector2i]) -> void:
	var body := StaticBody2D.new()
	var half  := Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	for cell : Vector2i in wall_cells:
		var shape := CollisionShape2D.new()
		var rect  := RectangleShape2D.new()
		rect.size      = Vector2(TILE_SIZE, TILE_SIZE)
		shape.position = Vector2(cell) * TILE_SIZE + half
		shape.shape    = rect
		body.add_child(shape)
	add_child(body)


## Spawns a thin Area2D sensor at each open door. Fires door_entered(dir)
## when the player's CharacterBody2D enters it.
func _spawn_door_triggers() -> void:
	for dir : String in room_config.doors:
		_spawn_trigger(dir)


func _spawn_trigger(dir: String) -> void:
	var area  := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()

	# Door openings are 3 tiles wide/tall centred on the wall midpoint.
	# The trigger is a thin strip just inside the opening so it fires as
	# the player crosses the threshold.
	var cx : float = 7.5 * TILE_SIZE   # horizontal centre of room
	var cy : float = 5.5 * TILE_SIZE   # vertical centre of room
	var tw : float = 3.0 * TILE_SIZE   # door width  (3 tiles)
	var th : float = 0.4 * TILE_SIZE   # trigger thickness

	match dir:
		"n":
			rect.size     = Vector2(tw, th)
			area.position = Vector2(cx, th * 0.5)
		"s":
			rect.size     = Vector2(tw, th)
			area.position = Vector2(cx, room_height * TILE_SIZE - th * 0.5)
		"w":
			rect.size     = Vector2(th, tw)
			area.position = Vector2(th * 0.5, cy)
		"e":
			rect.size     = Vector2(th, tw)
			area.position = Vector2(room_width * TILE_SIZE - th * 0.5, cy)

	shape.shape = rect
	area.add_child(shape)
	area.body_entered.connect(
		func(body: Node2D) -> void:
			if body.is_in_group("player"):
				door_entered.emit(dir)
	)
	add_child(area)


## Spawns monsters in this room using room_config.room_seed for determinism.
## Count scales with Manhattan-ish distance from the starting room.
func _spawn_monsters() -> void:
	var rng  := RandomNumberGenerator.new()
	rng.seed  = room_config.room_seed ^ 0xBEEF1234   # separate from tile visual seed

	var centre : Vector2i = Vector2i(DungeonGenerator.GRID_W / 2, DungeonGenerator.GRID_H / 2)
	var dist   : int      = int((room_config.grid_pos - centre).length())
	var count  : int      = clamp(dist + rng.randi_range(-1, 1), 1, 5)

	for i in count:
		var monster       = MONSTER_SCENE.instantiate()
		monster.body_type = rng.randi_range(0, 2)
		monster.arms_type = rng.randi_range(0, 2)
		monster.head_type = rng.randi_range(0, 2)
		# Place on interior floor away from walls and door centres.
		var mx : int = rng.randi_range(2, room_width  - 3)
		var my : int = rng.randi_range(2, room_height - 3)
		monster.position = Vector2(mx, my) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
		add_child(monster)


## Builds a MultiMeshInstance2D from a list of tile grid coordinates.
## One quad per cell, batched into a single draw call per material.
func _spawn_layer(cells: Array[Vector2i], mat: ShaderMaterial) -> void:
	if cells.is_empty() or mat == null:
		return

	# Quad mesh: centered at origin, sized to one tile.
	# UV automatically goes 0→1 across the quad — matches what the shaders expect.
	var quad := QuadMesh.new()
	quad.size = Vector2(TILE_SIZE, TILE_SIZE)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.mesh             = quad
	mm.instance_count   = cells.size()

	# Position each instance. QuadMesh is centred at origin, so offset by half a
	# tile so that cell (0,0) occupies pixels (0,0)→(64,64) in local space.
	# This keeps tile_cell = floor(world_pos / TILE_SIZE) == grid coords.
	var half := Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	for i in cells.size():
		var pos := Vector2(cells[i]) * TILE_SIZE + half
		mm.set_instance_transform_2d(i, Transform2D(0.0, pos))

	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = mm
	mmi.material  = mat
	add_child(mmi)
