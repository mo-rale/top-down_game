# rocket.gd
extends Node2D

@export var speed: float = 900.0
@export var damage: int = 450
@export var explosion_damage: int = 150
@export var explosion_radius: float = 250.0
@export var lifetime: float = 6.0
@export var rotation_speed: float = 90.0  # Not needed for straight rockets

var is_critical: bool = false
var has_exploded: bool = false
var velocity: Vector2 = Vector2.ZERO

@onready var explosion_light: PointLight2D = $ExplosionParticles/explosion_light
@onready var sprite: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var explosion_particles: CPUParticles2D = $ExplosionParticles
@onready var rocket_trail: CPUParticles2D = $RocketTrail
@onready var explosion_sound: AudioStreamPlayer2D = $ExplosionSound
@onready var light: PointLight2D = $light

func _ready() -> void:
	# Initialize velocity based on rotation (same as bullet)
	velocity = transform.x * speed
	
	# Start rocket trail
	if rocket_trail:
		rocket_trail.emitting = true
	
	# Auto delete after lifetime
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree() and not has_exploded:
		explode()

func _process(delta: float) -> void:
	if has_exploded:
		return
	
	# Update position (straight line like bullet, no gravity)
	position += velocity * delta

func set_critical(critical: bool) -> void:
	is_critical = critical
	if is_critical and sprite:
		# Critical visual effect
		sprite.modulate = Color(1.5, 0.8, 0.3, 1.0)
		sprite.scale = Vector2(1.2, 1.2)
		
	else:
		if sprite:
			sprite.modulate = Color(0.942, 0.048, 0.0, 1.0)
			sprite.scale = Vector2(1, 1)
		
		if rocket_trail:
			rocket_trail.process_material.color = Color(1, 0.8, 0.3)

func set_speed(new_speed: float) -> void:
	speed = new_speed
	velocity = transform.x * speed

func explode() -> void:
	if has_exploded:
		return
	light.visible = false
	has_exploded = true
	
	# Stop trail and hide rocket
	if rocket_trail:
		rocket_trail.emitting = false
	if sprite:
		sprite.visible = false
	
	# Disable collision
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Play explosion effects
	if explosion_particles:
		explosion_particles.emitting = true
		if explosion_light:
			explosion_light.visible = true
	
	if explosion_sound:
		explosion_sound.play()
	
	# Apply area damage to ALL enemies in range
	apply_area_damage()
	
	# Wait for particles to finish
	await get_tree().create_timer(explosion_particles.lifetime if explosion_particles else 1.0).timeout
	
	# Fade out explosion light using Tween
	if explosion_light and explosion_light.visible:
		var tween = create_tween()
		tween.tween_property(explosion_light, "energy", 0.0, 0.5).set_ease(Tween.EASE_OUT)
		await tween.finished
		explosion_light.visible = false
	
	queue_free()

func apply_area_damage() -> void:
	# Get all enemies in the scene that are in the damageable group
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	
	# Apply damage to each target within range
	for target in all_enemies:
		if not target.is_inside_tree() or not target.has_method("take_damage"):
			continue
		
		# Calculate distance from explosion center
		var distance = global_position.distance_to(target.global_position)
		
		# Check if target is within blast radius
		if distance <= explosion_radius:
			# Calculate damage falloff (closer = more damage)
			var distance_ratio = 1.0 - (distance / explosion_radius)
			var damage_multiplier = lerp(0.3, 1.0, distance_ratio)  # 30% to 100% damage
			
			# Apply critical multiplier if rocket was critical
			var final_damage = explosion_damage * damage_multiplier
			if is_critical:
				final_damage *= 1.5
			
			# Calculate knockback direction (away from explosion)
			var direction = (target.global_position - global_position).normalized()
			var knockback = direction * 500.0 * damage_multiplier
			
			# Apply damage
			target.take_damage(final_damage, knockback)
			
			# Optional: Visual feedback for hit enemy
			if target.has_method("on_explosion_hit"):
				target.on_explosion_hit()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if has_exploded:
		return
	
	# Direct hit - apply full damage
	if body.has_method("take_damage"):
		var final_damage = damage * (2.0 if is_critical else 1.0)
		body.take_damage(final_damage, velocity.normalized() * 300.0)
	
	# Always explode on impact
	explode()

func _on_area_2d_area_entered(area: Area2D) -> void:
	if has_exploded:
		return
	
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage"):
		var final_damage = damage * (2.0 if is_critical else 1.0)
		parent.take_damage(final_damage, velocity.normalized() * 300.0)
	
	explode()
