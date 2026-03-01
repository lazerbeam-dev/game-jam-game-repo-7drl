extends CharacterBody2D

# ─────────────────────────────────────────────────────────────────────────────
# LemonadeCharacter — Enter the Gungeon-style movement
# ─────────────────────────────────────────────────────────────────────────────
# WASD to move (8-directional), Space to dodge roll.
# The roll locks direction, boosts speed, and grants invincibility frames.
# is_invincible is a public flag — damage systems should check it before
# applying hits.
# ─────────────────────────────────────────────────────────────────────────────

enum State { NORMAL, ROLLING }

## Walking speed in pixels per second.
const MOVE_SPEED    := 300.0
## Speed during the dodge roll.
const ROLL_SPEED    := 650.0
## How long the roll lasts in seconds (~4 tiles at roll speed).
const ROLL_DURATION := 0.38
## Minimum time between rolls.
const ROLL_COOLDOWN := 0.50

var state          : State   = State.NORMAL
var roll_dir       : Vector2 = Vector2.DOWN
var roll_timer     : float   = 0.0
var cooldown_timer : float   = 0.0

## True while rolling — external systems (bullets, hazards) check this.
var is_invincible  : bool    = false

## Last non-zero movement direction; used so rolling from standstill has intent.
var last_facing    : Vector2 = Vector2.DOWN

## Hit points. Monsters call take_hit() to reduce this.
var health         : int     = 6


func _ready() -> void:
	add_to_group("player")


func take_hit(amount: int) -> void:
	if is_invincible:
		return
	health       -= amount
	is_invincible  = true
	print("Player hit! Health: ", health)
	await get_tree().create_timer(0.4).timeout
	is_invincible  = false


func _physics_process(delta: float) -> void:
	match state:
		State.NORMAL:  _normal_process(delta)
		State.ROLLING: _roll_process(delta)
	move_and_slide()


func _normal_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down")
	).normalized()

	velocity = dir * MOVE_SPEED

	if dir != Vector2.ZERO:
		last_facing = dir

	if Input.is_action_just_pressed("dodge_roll") and cooldown_timer <= 0.0:
		_start_roll(dir)


func _roll_process(delta: float) -> void:
	roll_timer -= delta
	velocity    = roll_dir * ROLL_SPEED
	if roll_timer <= 0.0:
		_end_roll()


func _start_roll(move_dir: Vector2) -> void:
	# Roll in movement direction; fall back to last facing if standing still.
	roll_dir      = move_dir if move_dir != Vector2.ZERO else last_facing
	roll_timer    = ROLL_DURATION
	state         = State.ROLLING
	is_invincible = true


func _end_roll() -> void:
	state          = State.NORMAL
	is_invincible  = false
	cooldown_timer = ROLL_COOLDOWN
	velocity       = Vector2.ZERO
