class_name RoomConfig

## Grid position of this room in the dungeon layout (e.g. Vector2i(3, 4)).
var grid_pos  : Vector2i   = Vector2i.ZERO

## Which cardinal doors are open. Keys: "n" | "s" | "e" | "w", value: true.
## A missing key or false means that wall is solid.
var doors     : Dictionary = {}

## Seed passed to tile_material_manager for per-room visual variation.
var room_seed : int        = 0

## Wear level for this room's materials (0 = pristine, 1 = destroyed).
var wear      : float      = 0.2
