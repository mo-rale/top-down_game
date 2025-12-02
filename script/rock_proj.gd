extends Node2D
class_name RockProjectile

@export var speed: float = 400.0     # Rock speed (slower than bullets)
@export var damage: int = 20         # Rock damage
@export var lifetime: float = 5.0    # seconds before rock auto-despawns
@export var knockback_strength: float = 300.0  # Knockback force

var velocity: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D  # Reference to your rock sprite
@onready var area_2d: Area2D = $Area2D


func _ready() -> void:
	# Auto delete after a while
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()


func setup(target_direction: Vector2, rock_speed: float, rock_damage: int):
	direction = target_direction.normalized()
	speed = rock_speed
	damage = rock_damage
	velocity = direction * speed
	
	# Rotate sprite to face movement direction
	if sprite:
		sprite.rotation = direction.angle()


func _process(delta: float) -> void:
	position += velocity * delta


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		# Apply damage with knockback in the rock's direction
		body.take_damage(damage, velocity.normalized() * knockback_strength)
		
		# Create hit effect (you can add particles here)
		create_hit_effect()
		queue_free()
	
	# Also destroy rock when hitting walls/obstacles
	elif body.is_in_group("walls") or body.is_in_group("obstacles"):
		create_hit_effect()
		queue_free()


func _on_area_2d_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage"):
		# Apply damage with knockback
		parent.take_damage(damage, velocity.normalized() * knockback_strength)
		create_hit_effect()
		queue_free()


func create_hit_effect():
	# You can add rock breaking particles or sound here
	# Example: spawn particles, play sound
	pass
