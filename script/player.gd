extends CharacterBody2D

@export var SPEED = 250
@export var ACCELERATION = 10.0
@export var DECELERATION = 8.0
@export var health = 100
@export var camera_lean_strength: float = 0.2

var max_health = health
var is_dead: bool = false

@onready var camera_2d: Camera2D = $head/Camera2D
@onready var health_bar: ProgressBar = $ProgressBar
@onready var sprite = $AnimatedSprite2D
@onready var hand: Node2D = $hand
@onready var gun: Node2D = $hand/M4A1  # gun is child of hand

var target_velocity: Vector2 = Vector2.ZERO


func get_input():
	if is_dead:
		target_velocity = Vector2.ZERO
		return

	var input_direction = Input.get_vector("left", "right", "up", "down")
	target_velocity = input_direction * SPEED


func _physics_process(delta):
	health_bar.value = health

	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	get_input()

	if target_velocity.length() > 0:
		velocity = velocity.lerp(target_velocity, ACCELERATION * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, DECELERATION * delta)

	move_and_slide()

	# --- Camera lean ---
	var mouse_pos = get_global_mouse_position()
	var dir_to_mouse = (mouse_pos - global_position) * camera_lean_strength
	camera_2d.offset = dir_to_mouse

	# --- Hand aiming ---
	hand.look_at(mouse_pos)

	# --- Flip player + hand ---
	var facing_left = mouse_pos.x < global_position.x
	sprite.flip_h = facing_left

	# flip the hand and all its children automatically
	hand.scale.y = -1 if facing_left else 1


func take_damage(damage: int) -> void:
	if is_dead:
		return

	health -= damage
	health = clamp(health, 0, max_health)
	health_bar.value = health
	print("Player Health:", health)

	if health <= 0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	print("💀 Player has died.")

	if gun and gun.has_method("set_process"):
		gun.set_process(false)
		gun.set_physics_process(false)
