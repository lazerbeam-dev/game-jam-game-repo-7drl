# tile_material_manager.gd
# ─────────────────────────────────────────────────────────────────────────────
# TileMaterialManager
# ─────────────────────────────────────────────────────────────────────────────
# Assigns ShaderMaterial resources to TileMapLayer nodes and exposes per-room
# controls (room seed, wear level) that are forwarded to each material as
# shader uniforms.
#
# All per-tile variation is handled entirely inside the shaders using a
# deterministic hash of the tile's world-space grid cell. No per-tile work
# from GDScript is needed — just call setup_room() when generating a room.
#
# USAGE:
#   1. Add this script as a Node child of your DungeonRoom scene.
#   2. In the Inspector, assign the ShaderMaterial .tres resources and the
#      TileMapLayer nodes.
#   3. Call setup_room(seed, wear) from your room generator after placing tiles.
#
# SCENE STRUCTURE EXAMPLE:
#   DungeonRoom (Node2D)
#     TileMapLayer_Dirt   — floors and open ground
#     TileMapLayer_Brick  — walls
#     TileMapLayer_Wood   — wooden sub-floors, platforms
#     TileMapLayer_Metal  — metal grating, pipes, tech floors
#     TileMaterialManager (this script)
#
# TILESET SETUP:
#   • Create a TileSet with your tile sprites. The white 64×64 sprite at
#     sprites/White_64x64.png works well as the base texture — the shader
#     replaces the white with procedural color.
#   • Set the Tile Size to match tile_size_px in each shader (default 64).
#   • In the Inspector for each TileMapLayer, set CanvasItem → Material to
#     the corresponding .tres ShaderMaterial resource.
# ─────────────────────────────────────────────────────────────────────────────
class_name TileMaterialManager
extends Node


# ── Inspector Exports: Materials ──────────────────────────────────────────────

## ShaderMaterial for dirt/ground tiles.
## Shader: res://materials/tile_dirt.gdshader
@export var material_dirt  : ShaderMaterial

## ShaderMaterial for brick/stone tiles.
## Shader: res://materials/tile_brick.gdshader
@export var material_brick : ShaderMaterial

## ShaderMaterial for wood plank tiles.
## Shader: res://materials/tile_wood.gdshader
@export var material_wood  : ShaderMaterial

## ShaderMaterial for metal plate tiles.
## Shader: res://materials/tile_metal.gdshader
@export var material_metal : ShaderMaterial


# ── Inspector Exports: TileMapLayer Nodes ────────────────────────────────────

@export var layer_dirt  : TileMapLayer
@export var layer_brick : TileMapLayer
@export var layer_wood  : TileMapLayer
@export var layer_metal : TileMapLayer


# ── Room-Level Shader Uniforms ────────────────────────────────────────────────

## Seed that shifts per-tile variation patterns. Set uniquely per room so
## the same room layout looks different each run.
@export var room_seed : int = 0

## Wear/damage level for the whole room. 0 = pristine, 1 = heavily damaged.
## Affects: dirt compaction, brick cracking, wood weathering, metal rust.
@export_range(0.0, 1.0, 0.01) var wear_level : float = 0.2


# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Assign materials to layers so CanvasItem.material is set even before
	# setup_room() is called (useful when testing in editor).
	_assign_materials()
	_push_uniforms_to_all()


# ─────────────────────────────────────────────────────────────────────────────
## Call this from your room generator after all tiles have been placed.
## seed: unique integer per room (e.g. a hash of room position or rng value)
## wear: 0 = fresh, 1 = heavily damaged — can scale with dungeon depth
func setup_room(my_seed: int, wear: float = 0.2) -> void:
	room_seed = my_seed
	wear_level = clamp(wear, 0.0, 1.0)
	_assign_materials()
	_push_uniforms_to_all()


# ─────────────────────────────────────────────────────────────────────────────
## Update a single uniform on all materials at once.
## Useful for animated effects (e.g. pulsing wetness on dirt).
func set_uniform_all(param_name: StringName, value: Variant) -> void:
	for mat in _all_materials():
		if mat:
			mat.set_shader_parameter(param_name, value)


# ─────────────────────────────────────────────────────────────────────────────
# PRIVATE HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _assign_materials() -> void:
	if layer_dirt  and material_dirt:  layer_dirt.material  = material_dirt
	if layer_brick and material_brick: layer_brick.material = material_brick
	if layer_wood  and material_wood:  layer_wood.material  = material_wood
	if layer_metal and material_metal: layer_metal.material = material_metal


func _push_uniforms_to_all() -> void:
	for mat in _all_materials():
		if mat:
			mat.set_shader_parameter(&"room_seed",  float(room_seed))
			mat.set_shader_parameter(&"wear_level", wear_level)


func _all_materials() -> Array[ShaderMaterial]:
	var result : Array[ShaderMaterial] = []
	if material_dirt:  result.append(material_dirt)
	if material_brick: result.append(material_brick)
	if material_wood:  result.append(material_wood)
	if material_metal: result.append(material_metal)
	return result
