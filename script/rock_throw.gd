# boss_rock.gd - Using CharacterBody2D
extends CharacterBody2D

@export var speed: float = 650.0
@export var damage: int = 120
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	print("Boss Rock spawned")
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()

func _physics_process(delta: float) -> void:
	velocity = direction * speed
	
	# Update rotation and flip based on direction
	update_sprite_direction()
	
	var collision = move_and_collide(velocity * delta)
	if collision:
		handle_collision(collision.get_collider())
		queue_free()

func setup(dir: Vector2, spd: float, dmg: int) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	
	# Set initial sprite direction
	update_sprite_direction()
	
	print("Rock setup - Direction: ", direction, " Speed: ", speed)

func update_sprite_direction() -> void:
	if not sprite:
		return
	
	# Method 1: Flip sprite horizontally based on X direction
	if direction.x != 0:
		sprite.flip_h = direction.x < 0
	
	# Method 2: Rotate sprite to face direction (choose one)
	# sprite.rotation = direction.angle()
	
	# Method 3: Both flip and rotation (if your sprite needs it)
	# sprite.rotation = direction.angle()
	# Additional flip logic if needed:
	# if abs(direction.angle()) > PI/2 and abs(direction.angle()) < 3*PI/2:
	#     sprite.flip_v = true
	# else:
	#     sprite.flip_v = false

func handle_collision(collider: Node2D) -> void:
	print("Rock collided with: ", collider.name)
	
	if collider.is_in_group("player") and collider.has_method("take_damage"):
		print("Dealing ", damage, " damage to player")
		collider.take_damage(damage)
	
	# Optional: Add impact effect
	create_impact_effect()

func create_impact_effect() -> void:
	# Add particles or sound here
	pass
