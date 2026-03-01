extends Area2D

# ─────────────────────────────────────────────────────────────────────────────
# Trap — dropped by TRAP monsters at their current position.
# Lingers on the floor; damages the player if they walk over it.
# A per-hit cooldown prevents the damage from stacking every frame.
# ─────────────────────────────────────────────────────────────────────────────

var lifetime     : float = 6.0
var hit_cooldown : float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build()


func _build() -> void:
	var poly     := Polygon2D.new()
	poly.polygon  = PackedVector2Array([
		Vector2(-20.0, -20.0), Vector2(20.0, -20.0),
		Vector2(20.0,   20.0), Vector2(-20.0, 20.0),
	])
	poly.color    = Color(0.8, 0.8, 0.1, 0.65)
	add_child(poly)

	var shape  := CollisionShape2D.new()
	var rect   := RectangleShape2D.new()
	rect.size   = Vector2(32.0, 32.0)
	shape.shape = rect
	add_child(shape)


func _process(delta: float) -> void:
	lifetime     -= delta
	hit_cooldown -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not body.is_invincible and hit_cooldown <= 0.0:
		body.take_hit(1)
		hit_cooldown = 1.0
