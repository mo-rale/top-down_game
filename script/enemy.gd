extends CharacterBody2D

var speed: float = 100
var health: int = 100
var max_health: int = 100
var enemy_damage: int = 5   # per tick of damage
var damage_interval: float = 0.5 # seconds between damage ticks

@export var knockback_strength: float = 200.0
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_friction: float = 8.0

@onready var healthbar: ProgressBar = $ProgressBar
@onready var sprite: Node2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D

# --- New variables ---
var player: Node2D = null
var player_in_area: Node2D = null
var damage_timer: float = 0.0

# --- Currency System ---
@export var min_currency_reward: int = 10
@export var max_currency_reward: int = 25
var currency_reward: int = 0


func _ready():
	# Generate random currency reward when enemy spawns
	currency_reward = randi_range(min_currency_reward, max_currency_reward)
	
	# Find player using group instead of hardcoded path
	player = get_tree().get_first_node_in_group("player")
	
	# Connect the Area2D signals if not connected in the editor
	if not area_2d.body_entered.is_connected(_on_body_entered):
		area_2d.body_entered.connect(_on_body_entered)
	if not area_2d.body_exited.is_connected(_on_body_exited):
		area_2d.body_exited.connect(_on_body_exited)


func take_damage(damage: int, _knockback_dir: Vector2 = Vector2.ZERO) -> void:
	health -= damage
	health = clamp(health, 0, max_health)
	healthbar.value = health

	# Find player if not already found
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		var move_dir = (player.position - position).normalized()
		knockback_velocity = -move_dir * knockback_strength

	if health <= 0:
		reward_currency()
		queue_free()


func reward_currency():
	# Find the game manager to reward currency
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("enemy_killed_reward"):
		game_manager.enemy_killed_reward(currency_reward)
		print("💰 Enemy killed! Reward: $", currency_reward)
	elif game_manager and game_manager.has_method("add_currency"):
		# Alternative method name
		game_manager.add_currency(currency_reward)
		print("💰 Enemy killed! Reward: $", currency_reward)
	else:
		# Fallback: try to find any node with currency methods
		var nodes = get_tree().get_nodes_in_group("currency_manager")
		if nodes.size() > 0:
			var currency_manager = nodes[0]
			if currency_manager.has_method("enemy_killed_reward"):
				currency_manager.enemy_killed_reward(currency_reward)
				print("💰 Enemy killed! Reward: $", currency_reward)
			elif currency_manager.has_method("add_currency"):
				currency_manager.add_currency(currency_reward)
				print("💰 Enemy killed! Reward: $", currency_reward)
		else:
			print("❌ No currency manager found. Reward lost: $", currency_reward)


func _physics_process(delta: float) -> void:
	var move_dir := Vector2.ZERO
	healthbar.value = health
	
	# Find player if not already found
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return  # Wait until next frame to avoid errors
	
	# Basic chasing behavior
	if player and health > 0:
		move_dir = (player.position - position).normalized()
		if position.distance_to(player.position) > 3:
			velocity = move_dir * speed
		else:
			velocity = Vector2.ZERO

	# Apply knockback
	if knockback_velocity.length() > 1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction)
	
	# Move the character
	move_and_slide()
	
	# Flip sprite horizontally - FIXED THIS LINE
	if move_dir.x != 0:
		sprite.flip_h = move_dir.x < 0

	# --- Continuous damage logic ---
	if player_in_area:
		damage_timer -= delta
		if damage_timer <= 0.0:
			# Check if player still exists and has take_damage method
			if player_in_area and player_in_area.has_method("take_damage"):
				player_in_area.take_damage(enemy_damage)
			damage_timer = damage_interval


func _on_body_entered(body: Node2D) -> void:
	if body and body.is_in_group("player"):
		player_in_area = body
		damage_timer = 0.0  # damage immediately on contact


func _on_body_exited(body: Node2D) -> void:
	if body == player_in_area:
		player_in_area = null
