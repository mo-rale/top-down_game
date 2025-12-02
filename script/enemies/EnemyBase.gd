class_name EnemyBase
extends CharacterBody2D

# --- Load Damage Text Scene ---
const DAMAGE_TEXT_SCENE = preload("res://scene/damage_text.tscn")  # CHANGE THIS PATH!

# --- Enemy Stats ---
@export var speed: float = 100
@export var health: int = 100
@export var max_health: int = 100
@export var enemy_damage: int = 5
@export var damage_interval: float = 0.5
@export var knockback_strength: float = 200.0

# --- Armor System ---
@export var armor: int = 0  # Flat damage reduction
@export var armor_percentage: float = 0.0  # Percentage damage reduction (0.0 to 1.0)
@export var armor_type: String = "light"  # Can be "light", "medium", "heavy", "boss"
@export var weak_to: Array[String] = []  # Array of damage types this enemy is weak to
@export var resistant_to: Array[String] = []  # Array of damage types this enemy is resistant to

# --- Currency System ---
@export var min_currency_reward: int = 10
@export var max_currency_reward: int = 25

# --- Sound Settings ---
@export var death_pitch_min: float = 0.9
@export var death_pitch_max: float = 1.1
@export var dying_pitch_min: float = 0.9
@export var dying_pitch_max: float = 1.1
@export var dialogue_chance: float = 0.01  # 1% chance per frame
@export var min_dialogue_delay: float = 5.0  # Minimum seconds between dialogues
@export var max_dialogue_delay: float = 15.0  # Maximum seconds between dialogues

# --- Top-Down Damage Effects ---
@export var damage_flash_color: Color = Color(2.0, 2.0, 2.0, 1.0)  # Brighter white flash
@export var damage_flash_duration: float = 0.08

# --- Damage Text Settings ---
@export var damage_text_offset: Vector2 = Vector2(0, -30)  # Where to show damage text
@export var damage_text_color: Color = Color.WHITE
@export var critical_text_color: Color = Color(1.0, 0.8, 0.0)  # Gold/yellow for crits
@export var weak_text_color: Color = Color(0.0, 1.0, 0.0)  # Green for weakness hits
@export var resistant_text_color: Color = Color(0.5, 0.5, 0.5)  # Gray for resisted hits

# --- Node References ---
@onready var healthbar: ProgressBar = $ProgressBar
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_2d: Area2D = $Area2D
@onready var dead: AudioStreamPlayer2D = $dead
@onready var dying: AudioStreamPlayer2D = $dying
@onready var coll: CollisionShape2D = $CollisionShape2D
@onready var hit: AudioStreamPlayer2D = $hit
@onready var dialogue: AudioStreamPlayer2D = $dialogue

# --- Enemy State ---
var player: Node2D = null
var player_in_area: Node2D = null
var damage_timer: float = 0.0
var currency_reward: int = 0
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_friction: float = 8.0
var is_dead: bool = false
var dialogue_timer: float = 0.0
var time_since_last_dialogue: float = 0.0
var is_flashing: bool = false  # Prevent multiple overlapping flashes
var original_modulate: Color = Color.WHITE  # Store original color


func _ready():
	add_to_group("enemies")
	
	currency_reward = randi_range(min_currency_reward, max_currency_reward)
	player = get_tree().get_first_node_in_group("player")
	
	if not area_2d.body_entered.is_connected(_on_body_entered):
		area_2d.body_entered.connect(_on_body_entered)
	if not area_2d.body_exited.is_connected(_on_body_exited):
		area_2d.body_exited.connect(_on_body_exited)
	
	# Initialize dialogue timer with a random delay
	dialogue_timer = randf_range(min_dialogue_delay, max_dialogue_delay)
	
	# Store original modulate
	if sprite:
		original_modulate = sprite.modulate


func _physics_process(delta: float) -> void:
	healthbar.value = health
	
	# Stop processing if dead
	if is_dead:
		return
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return
	
	handle_movement()
	handle_knockback()
	handle_continuous_damage(delta)
	handle_dialogue(delta)
	
	move_and_slide()


#region Core Enemy Functions
func handle_movement() -> void:
	if player and health > 0:
		var move_dir = (player.position - position).normalized()
		
		if position.distance_to(player.position) > 3:
			velocity = move_dir * speed
		else:
			velocity = Vector2.ZERO
		
		if move_dir.x != 0:
			sprite.flip_h = move_dir.x < 0


func handle_knockback() -> void:
	if knockback_velocity.length() > 1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction)


func handle_continuous_damage(delta: float) -> void:
	if player_in_area:
		damage_timer -= delta
		if damage_timer <= 0.0:
			if player_in_area and player_in_area.has_method("take_damage"):
				player_in_area.take_damage(enemy_damage)
			damage_timer = damage_interval


func handle_dialogue(delta: float) -> void:
	if not dialogue:
		return
	
	time_since_last_dialogue += delta
	dialogue_timer -= delta
	if time_since_last_dialogue >= min_dialogue_delay and randf() < dialogue_chance:
		play_random_dialogue()


func play_random_dialogue() -> void:
	if dialogue and not dialogue.playing and health > 0:
		dialogue.play()
		time_since_last_dialogue = 0.0
#endregion


#region Combat System
func take_damage(damage: int, _knockback_dir: Vector2 = Vector2.ZERO, damage_type: String = "normal", critical: bool = false) -> void:
	if is_dead:
		return  # Already dead, don't process more damage
	
	# Calculate damage with armor reduction
	var actual_damage = calculate_damage_with_armor(damage, damage_type, critical)
	
	# Determine damage type for text color
	var is_weak = damage_type in weak_to
	var is_resistant = damage_type in resistant_to
	
	# Show damage text
	show_damage_text(actual_damage, critical, is_weak, is_resistant)
	
	# Show top-down damage effect
	show_damage_effect(actual_damage, critical)
	
	if hit:
		hit.play()
	
	health -= actual_damage
	health = clamp(health, 0, max_health)
	healthbar.value = health

	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		var move_dir = (player.position - position).normalized()
		knockback_velocity = -move_dir * knockback_strength
	
	if health <= 0 and not is_dead:
		is_dead = true
		reward_currency()
		on_death()


func calculate_damage_with_armor(base_damage: int, damage_type: String = "normal", critical: bool = false) -> int:
	var final_damage = base_damage
	
	# Apply critical hit multiplier if applicable
	if critical:
		final_damage = int(final_damage * 1.5)  # 50% bonus for critical hits
	
	# Apply damage type modifiers
	if damage_type in weak_to:
		final_damage = int(final_damage * 1.25)  # 25% bonus against weaknesses
	elif damage_type in resistant_to:
		final_damage = int(final_damage * 0.75)  # 25% reduction against resistances
	
	# Apply flat armor reduction
	if armor > 0:
		final_damage = max(final_damage - armor, 1)  # Minimum 1 damage
	
	# Apply percentage armor reduction
	if armor_percentage > 0.0:
		final_damage = int(final_damage * (1.0 - armor_percentage))
	
	return max(final_damage, 1)  # Always do at least 1 damage


func show_damage_text(damage: int, critical: bool = false, is_weak: bool = false, is_resistant: bool = false):
	# Check if damage text scene is loaded
	if DAMAGE_TEXT_SCENE == null:
		print("Warning: DAMAGE_TEXT_SCENE not loaded. Update the path in EnemyBase.gd")
		return
	
	var damage_text = DAMAGE_TEXT_SCENE.instantiate()
	
	# Add to scene tree (add to parent so it doesn't get deleted with enemy)
	get_parent().add_child(damage_text)
	damage_text.global_position = global_position + damage_text_offset
	
	# Set damage value
	if damage_text.has_method("set_damage"):
		damage_text.set_damage(damage)
	elif damage_text.has_node("Label") and damage_text.get_node("Label") is Label:
		damage_text.get_node("Label").text = str(damage)
	
	# Set color based on hit type
	var text_color = damage_text_color
	
	if critical:
		text_color = critical_text_color
	elif is_weak:
		text_color = weak_text_color
	elif is_resistant:
		text_color = resistant_text_color
	
	# Apply color
	if damage_text.has_method("set_color"):
		damage_text.set_color(text_color)
	elif damage_text.has_node("Label") and damage_text.get_node("Label") is Label:
		damage_text.get_node("Label").modulate = text_color
	
	# Add "CRIT!" text for critical hits
	if critical and damage_text.has_method("set_critical"):
		damage_text.set_critical(true)
	
	# Optional: Add small random offset for multiple hits
	damage_text.position += Vector2(randf_range(-10, 10), randf_range(-5, 5))


func show_damage_effect(damage_amount: int, critical: bool = false):
	# Don't start new flash if already flashing
	if is_flashing:
		return
	
	is_flashing = true
	
	if sprite:
		# Quick white flash with tween
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
		
		# Flash to white quickly
		tween.tween_property(sprite, "modulate", damage_flash_color, damage_flash_duration / 2)
		tween.tween_property(sprite, "modulate", original_modulate, damage_flash_duration / 2)
		
		# Optional: Add scale effect for more visibility
		if critical:
			var original_scale = sprite.scale
			tween.parallel().tween_property(sprite, "scale", original_scale * 1.2, damage_flash_duration / 2)
			tween.parallel().tween_property(sprite, "scale", original_scale, damage_flash_duration / 2)
		
		await tween.finished
		
		# Ensure we're back to normal
		sprite.modulate = original_modulate
		if critical:
			sprite.scale = Vector2.ONE
	
	# Reset flash state
	is_flashing = false


func on_death() -> void:
	# Disable all collisions and detection
	healthbar.visible = false
	collision_layer = 0
	collision_mask = 0
	area_2d.collision_layer = 0
	area_2d.collision_mask = 0
	
	# Stop any movement
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	
	# Remove from enemies group so bullets don't target it
	remove_from_group("enemies")
	
	# Play death effects with random pitch
	play_death_sounds()
	sprite.play("dying")
	
	await sprite.animation_finished
	await dying.finished
	queue_free()


func play_death_sounds() -> void:
	# Set random pitch for death sound
	if dead:
		dead.pitch_scale = randf_range(death_pitch_min, death_pitch_max)
		dead.play()
	
	# Set random pitch for dying sound
	if dying:
		dying.pitch_scale = randf_range(dying_pitch_min, dying_pitch_max)
		dying.play()
#endregion


#region Currency System
func reward_currency() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("enemy_killed_reward"):
		game_manager.enemy_killed_reward(currency_reward)
	elif game_manager and game_manager.has_method("add_currency"):
		game_manager.add_currency(currency_reward)
	else:
		var nodes = get_tree().get_nodes_in_group("currency_manager")
		if nodes.size() > 0:
			var currency_manager = nodes[0]
			if currency_manager.has_method("enemy_killed_reward"):
				currency_manager.enemy_killed_reward(currency_reward)
			elif currency_manager.has_method("add_currency"):
				currency_manager.add_currency(currency_reward)
#endregion


#region Area Detection
func _on_body_entered(body: Node2D) -> void:
	if body and body.is_in_group("player"):
		player_in_area = body
		damage_timer = 0.0


func _on_body_exited(body: Node2D) -> void:
	if body == player_in_area:
		player_in_area = null
#endregion


#region Armor Management
func set_armor(new_armor: int, new_armor_percentage: float = 0.0, new_armor_type: String = ""):
	armor = new_armor
	armor_percentage = clamp(new_armor_percentage, 0.0, 0.95)  # Cap at 95% reduction
	
	if new_armor_type:
		armor_type = new_armor_type


func add_armor(armor_amount: int):
	armor += armor_amount


func reduce_armor(armor_amount: int):
	armor = max(armor - armor_amount, 0)


func set_weakness(damage_types: Array[String]):
	weak_to = damage_types


func set_resistance(damage_types: Array[String]):
	resistant_to = damage_types


func has_armor() -> bool:
	return armor > 0 or armor_percentage > 0.0


func get_armor_info() -> Dictionary:
	return {
		"flat_armor": armor,
		"percentage_armor": armor_percentage,
		"armor_type": armor_type,
		"weak_to": weak_to,
		"resistant_to": resistant_to
	}
#endregion


#region Hooks (Override in Child Classes)
# Override these functions in child enemy classes for custom behavior
func on_spawn() -> void:
	pass


func on_player_detected() -> void:
	pass


func on_attack() -> void:
	pass
#endregion
