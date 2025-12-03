extends CharacterBody2D
class_name BossEnemy

# --- Boss Stats ---
@export var max_health: int = 2500
@export var speed: int = 80
@export var contact_damage: int = 15
@export var knockback_strength: float = 300.0

# --- Boss Special Attacks ---
@export var rock_attack_damage: int = 20
@export var stomp_attack_damage: int = 30
@export var rock_attack_cooldown: float = 3.0
@export var stomp_attack_cooldown: float = 5.0
@export var rock_scene: PackedScene
@export var stomp_radius: float = 150.0
@export var rock_speed: float = 250.0
@export var attack_range: float = 200.0

# --- Visual/UI ---
@export var health_bar_scene: PackedScene
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_indicator: Sprite2D = $AttackIndicator
@onready var stomp_area: Area2D = $StompArea
@onready var hurt_box: Area2D = $HurtBox
@onready var health_bar: ProgressBar = $CanvasLayer/ProgressBar

# --- Audio ---
@onready var hurt_sound: AudioStreamPlayer2D = $Hurt
@onready var death_sound: AudioStreamPlayer2D = $Death
@onready var attack_sound: AudioStreamPlayer2D = $Attack

# --- State Variables ---
var health: int = max_health
var player: CharacterBody2D = null
var is_dead: bool = false
var is_attacking: bool = false
var can_move: bool = true

# --- Attack Timers ---
var rock_attack_timer: float = 0.0
var stomp_attack_timer: float = 0.0

# --- Boss State Machine ---
enum BossState {
	CHASING,
	ROCK_ATTACK,
	STOMP_ATTACK,
	VULNERABLE,
	DEAD
}
var current_state: BossState = BossState.CHASING


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	
	# Initialize health
	health = max_health
	
	# Setup attack timers with offsets
	rock_attack_timer = rock_attack_cooldown * 0.7
	stomp_attack_timer = stomp_attack_cooldown * 0.5
	
	# Setup area connections
	if stomp_area:
		stomp_area.body_entered.connect(_on_stomp_body_entered)
	
	if hurt_box:
		hurt_box.body_entered.connect(_on_hurt_box_body_entered)
	
	# Setup attack indicator
	if attack_indicator:
		attack_indicator.visible = false
		attack_indicator.modulate = Color(0.983, 0.0, 0.0, 1.0)
	
	# Find player
	find_player()
	
	# Create health bar
	update_health_bar()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Update player reference if lost
	if not player or not is_instance_valid(player):
		find_player()
		if not player:
			return
	
	# Update timers
	rock_attack_timer -= delta
	stomp_attack_timer -= delta
	
	# State machine
	match current_state:
		BossState.CHASING:
			handle_chasing_state(delta)
		BossState.ROCK_ATTACK:
			handle_rock_attack_state(delta)
		BossState.STOMP_ATTACK:
			handle_stomp_attack_state(delta)
		BossState.VULNERABLE:
			handle_vulnerable_state(delta)
		BossState.DEAD:
			handle_dead_state()
	
	# Apply movement if not attacking
	if can_move and current_state == BossState.CHASING:
		var direction = (player.position - position).normalized()
		velocity = direction * speed
		move_and_slide()
		
		# Flip sprite based on direction
		if velocity.x != 0:
			sprite.flip_h = velocity.x < 0
	else:
		velocity = Vector2.ZERO


func find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("Boss found player: ", player.name)


func update_health_bar() -> void:
	if health_bar:
		health_bar.value = health




func handle_chasing_state(_delta: float) -> void:
	# Check for attack opportunities
	if rock_attack_timer <= 0.0 and not is_attacking:
		var distance_to_player = position.distance_to(player.position) if player else 9999
		if distance_to_player > attack_range:
			start_rock_attack()
	
	if stomp_attack_timer <= 0.0 and not is_attacking:
		var distance_to_player = position.distance_to(player.position) if player else 9999
		if distance_to_player <= attack_range:
			start_stomp_attack()


func handle_rock_attack_state(_delta: float) -> void:
	# Look at player during rock attack
	if player:
		var direction_to_player = (player.position - position).normalized()
		sprite.flip_h = direction_to_player.x < 0


func handle_stomp_attack_state(_delta: float) -> void:
	# Show attack indicator
	if attack_indicator:
		attack_indicator.visible = true
		attack_indicator.scale = Vector2.ONE * (stomp_radius / 50.0)


func handle_vulnerable_state(_delta: float) -> void:
	# Boss is vulnerable after attacks - can take full damage
	pass


func handle_dead_state() -> void:
	# Boss is dead - no actions
	pass


func start_rock_attack() -> void:
	if is_attacking or not player:
		return
	
	current_state = BossState.ROCK_ATTACK
	is_attacking = true
	can_move = false
	
	# Play rock attack animation
	sprite.play("throw")
	if attack_sound:
		attack_sound.play()
	
	# Wait for animation to reach throwing point
	await get_tree().create_timer(0.4).timeout
	# Throw rocks
	throw_rocks()
	
	# Wait for animation to finish
	await sprite.animation_finished
	
	# Reset state
	is_attacking = false
	can_move = true
	rock_attack_timer = rock_attack_cooldown
	current_state = BossState.VULNERABLE
	
	# Brief vulnerability period
	await get_tree().create_timer(0.5).timeout
	sprite.play("walking")
	if not is_dead:
		current_state = BossState.CHASING


func start_stomp_attack() -> void:
	if is_attacking or not player:
		return
	
	current_state = BossState.STOMP_ATTACK
	is_attacking = true
	can_move = false
	
	# Play stomp animation
	if sprite:
		sprite.play("stomp")
	if attack_sound:
		attack_sound.pitch_scale = 0.8
		attack_sound.play()
	
	# Show attack indicator
	if attack_indicator:
		attack_indicator.visible = true
	
	# Wait for the moment in animation to actually stomp
	await get_tree().create_timer(0.6).timeout
	
	# Perform stomp
	perform_stomp()
	
	# Wait for animation to finish
	await sprite.animation_finished
	
	# Reset state
	is_attacking = false
	can_move = true
	stomp_attack_timer = stomp_attack_cooldown
	
	# Hide attack indicator
	if attack_indicator:
		attack_indicator.visible = false
	
	current_state = BossState.VULNERABLE
	
	# Brief vulnerability period
	await get_tree().create_timer(0.5).timeout
	sprite.play("walking")
	if not is_dead:
		current_state = BossState.CHASING


func throw_rocks() -> void:
	if not rock_scene or not player:
		return
	
	var player_direction = (player.position - position).normalized()
	
	# Throw 3 rocks in a spread pattern
	for i in range(3):
		var rock = rock_scene.instantiate()
		get_parent().add_child(rock)
		rock.position = position
		
		# Calculate spread direction
		var spread_angle = deg_to_rad((i - 1) * 30)  # -30, 0, +30 degrees
		var direction = player_direction.rotated(spread_angle)
		
		# Set rock properties
		if rock.has_method("setup"):
			rock.setup(direction, rock_speed, rock_attack_damage)
		elif "velocity" in rock:
			rock.velocity = direction * rock_speed
		if "damage" in rock:
			rock.damage = rock_attack_damage


func perform_stomp() -> void:
	# Create stomp effect
	create_stomp_effect()
	
	# Damage players in stomp radius
	if stomp_area:
		var bodies = stomp_area.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(stomp_attack_damage)
				
				# Apply knockback
				var knockback_dir = (body.position - position).normalized()
				if body.has_method("apply_knockback"):
					body.apply_knockback(knockback_dir * knockback_strength * 1.5)


func create_stomp_effect() -> void:
	# Screen shake
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(1.5, 0.3)
	
	# Create shockwave particles or other effects
	print("BOSS STOMP!")


func take_damage(damage_amount: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	
	# Boss takes reduced damage during attacks
	var damage_multiplier = 1.0
	if is_attacking:
		damage_multiplier = 0.5  # 50% damage reduction during attacks
	
	var actual_damage = int(damage_amount * damage_multiplier)
	health -= actual_damage
	
	# Play hurt sound
	if hurt_sound:
		hurt_sound.pitch_scale = randf_range(0.9, 1.1)
		hurt_sound.play()
	
	# Visual feedback
	sprite.modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		sprite.modulate = Color(1, 1, 1)
	
	# Update health bar
	update_health_bar()
	
	# Check for death
	if health <= 0:
		die()
	
	# Enrage mode when health is low
	if health <= max_health * 0.3:
		# Faster attacks when enraged
		rock_attack_cooldown = 2.0
		stomp_attack_cooldown = 3.0
		speed = 100  # Faster movement
		
		# Visual enrage effect
		sprite.modulate = Color(1.2, 0.5, 0.5)


func die() -> void:
	is_dead = true
	current_state = BossState.DEAD
	
	# Play death animation
	sprite.play("dying")
	
	# Play death sound
	if death_sound:
		death_sound.play()
	
	# Wait for animation
	await sprite.animation_finished
	
	# Drop loot or trigger victory
	drop_loot()
	
	# Remove boss
	queue_free()


func drop_loot() -> void:
	# Drop ammo, health, or special items
	print("BOSS DEFEATED! Drops loot!")
	
	# You could spawn powerups here
	# Example: spawn_health_pack()


func _on_stomp_body_entered(body: Node2D) -> void:
	# Handled in perform_stomp()
	pass


func _on_hurt_box_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		# Apply contact damage to player
		body.take_damage(contact_damage)
		
		# Apply knockback to player
		var knockback_dir = (body.position - position).normalized()
		if body.has_method("apply_knockback"):
			body.apply_knockback(knockback_dir * knockback_strength)


func get_attack_cooldown_percentage() -> Vector2:
	return Vector2(
		max(0, 1.0 - (rock_attack_timer / rock_attack_cooldown)),
		max(0, 1.0 - (stomp_attack_timer / stomp_attack_cooldown))
	)


func is_player_in_range() -> bool:
	if not player:
		return false
	return position.distance_to(player.position) <= attack_range


# For debugging or UI display
func get_boss_info() -> Dictionary:
	return {
		"health": health,
		"max_health": max_health,
		"state": current_state,
		"rock_cooldown": rock_attack_timer,
		"stomp_cooldown": stomp_attack_timer,
		"is_attacking": is_attacking
	}
