class_name Monster
extends CharacterBody2D

# ─────────────────────────────────────────────────────────────────────────────
# Monster — component-based enemy
# ─────────────────────────────────────────────────────────────────────────────
# Three independent components combine to define each monster:
#   Body  → movement speed   (SLOW / MEDIUM / FAST)
#   Arms  → attack pattern   (MELEE / RANGED / TRAP)
#   Head  → AI behaviour     (APPROACH / FLEE / ORBIT)
#
# All visuals and collision shapes are built at runtime — no editor setup.
# Set body_type / arms_type / head_type BEFORE add_child() so _ready() sees them.
# ─────────────────────────────────────────────────────────────────────────────

enum BodyType { SLOW, MEDIUM, FAST }
enum ArmsType { MELEE, RANGED, TRAP }
enum HeadType { APPROACH, FLEE, ORBIT }

const SPEEDS     := { BodyType.SLOW: 70.0, BodyType.MEDIUM: 150.0, BodyType.FAST: 260.0 }
const ORBIT_DIST := 200.0

const BULLET_SCENE = preload("res://scenes/monsters/bullet.tscn")
const TRAP_SCENE   = preload("res://scenes/monsters/trap.tscn")

@export var body_type : BodyType = BodyType.MEDIUM
@export var arms_type : ArmsType = ArmsType.MELEE
@export var head_type : HeadType = HeadType.APPROACH

var speed        : float = 150.0
var attack_timer : float = 0.0
var melee_cd     : float = 0.0


func _ready() -> void:
	speed = SPEEDS[body_type]
	_build_visuals()
	_build_collision()
	if arms_type == ArmsType.MELEE:
		_build_melee_area()
	add_to_group("monsters")


# ── AI ────────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	velocity = _head_velocity(player)
	move_and_slide()
	_tick_attack(delta, player)


func _head_velocity(player: Node2D) -> Vector2:
	var to_player := player.global_position - global_position
	var dist      := to_player.length()
	var dir       := to_player.normalized()
	match head_type:
		HeadType.APPROACH:
			return dir * speed
		HeadType.FLEE:
			return -dir * speed
		HeadType.ORBIT:
			if dist > ORBIT_DIST + 24.0:
				return dir * speed
			elif dist < ORBIT_DIST - 24.0:
				return -dir * speed
			else:
				return Vector2(-dir.y, dir.x) * speed   # circle perpendicular
	return Vector2.ZERO


func _tick_attack(delta: float, player: Node2D) -> void:
	attack_timer -= delta
	melee_cd     -= delta
	if attack_timer > 0.0:
		return
	match arms_type:
		ArmsType.RANGED:
			_fire_bullet(player)
			attack_timer = 2.0
		ArmsType.TRAP:
			_drop_trap()
			attack_timer = 4.0
		ArmsType.MELEE:
			attack_timer = 0.5   # MELEE damage is handled by Area2D body_entered


func _fire_bullet(player: Node2D) -> void:
	var b         = BULLET_SCENE.instantiate()
	b.direction   = (player.global_position - global_position).normalized()
	b.global_position = global_position
	get_parent().add_child(b)


func _drop_trap() -> void:
	var t             = TRAP_SCENE.instantiate()
	t.global_position = global_position
	get_parent().add_child(t)


# ── Visuals ───────────────────────────────────────────────────────────────────
# Three coloured squares: large body centre, small head above, small arms right.

func _build_visuals() -> void:
	var body_cols := {
		BodyType.SLOW:   Color(0.3, 0.3, 1.0),
		BodyType.MEDIUM: Color(1.0, 0.65, 0.0),
		BodyType.FAST:   Color(1.0, 0.2, 0.2),
	}
	var head_cols := {
		HeadType.APPROACH: Color(1.0, 0.2, 0.2),
		HeadType.FLEE:     Color(0.2, 0.85, 0.2),
		HeadType.ORBIT:    Color(0.75, 0.2, 1.0),
	}
	var arms_cols := {
		ArmsType.MELEE:  Color(1.0, 0.4, 0.0),
		ArmsType.RANGED: Color(0.2, 0.8, 1.0),
		ArmsType.TRAP:   Color(0.8, 0.8, 0.2),
	}
	_add_square(Vector2.ZERO,       14.0, body_cols[body_type])   # body
	_add_square(Vector2(0.0, -18.0), 7.0, head_cols[head_type])   # head
	_add_square(Vector2(18.0, 0.0),  7.0, arms_cols[arms_type])   # arms


func _add_square(offset: Vector2, half: float, col: Color) -> void:
	var poly     := Polygon2D.new()
	poly.polygon  = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half,   half), Vector2(-half, half),
	])
	poly.color    = col
	poly.position = offset
	add_child(poly)


# ── Collision ─────────────────────────────────────────────────────────────────

func _build_collision() -> void:
	var shape  := CollisionShape2D.new()
	var rect   := RectangleShape2D.new()
	rect.size   = Vector2(28.0, 28.0)
	shape.shape = rect
	add_child(shape)


func _build_melee_area() -> void:
	var area      := Area2D.new()
	var shape     := CollisionShape2D.new()
	var circle    := CircleShape2D.new()
	circle.radius  = 26.0
	shape.shape    = circle
	area.add_child(shape)
	area.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player") and not body.is_invincible and melee_cd <= 0.0:
			body.take_hit(1)
			melee_cd = 0.8
	)
	add_child(area)
