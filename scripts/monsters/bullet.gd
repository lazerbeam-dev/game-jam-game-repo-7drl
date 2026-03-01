extends Area2D

# ─────────────────────────────────────────────────────────────────────────────
# Bullet — fired by RANGED monsters toward the player.
# Moves in a straight line; deletes on player contact or after lifetime expires.
# Set `direction` (normalised Vector2) and `global_position` before add_child().
# ─────────────────────────────────────────────────────────────────────────────

var direction : Vector2 = Vector2.RIGHT
const SPEED   : float   = 320.0
var lifetime  : float   = 3.5


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build()


func _build() -> void:
	var poly     := Polygon2D.new()
	poly.polygon  = PackedVector2Array([
		Vector2(-5.0, -5.0), Vector2(5.0, -5.0),
		Vector2(5.0,   5.0), Vector2(-5.0, 5.0),
	])
	poly.color    = Color(1.0, 0.85, 0.1)
	add_child(poly)

	var shape     := CollisionShape2D.new()
	var circle    := CircleShape2D.new()
	circle.radius  = 5.0
	shape.shape    = circle
	add_child(shape)


func _process(delta: float) -> void:
	position += direction * SPEED * delta
	lifetime  -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not body.is_invincible:
		body.take_hit(1)
		queue_free()
	elif body is StaticBody2D:
		queue_free()
