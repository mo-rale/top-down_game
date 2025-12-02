extends Node2D

@export var enemy_scenes: Array[PackedScene] = []
@export var spawn_weights: Array[float] = []  # Relative weights for each enemy type
@export var spawn_interval: float = 2.0
@export var max_enemies: int = 10
var spawn_radius: float = 150

# Special enemy that unlocks at wave 5
@export var special_enemy_scene: PackedScene
@export var special_enemy_spawn_weight: float = 1.0  # 30% chance when unlocked

# Boss enemy that spawns every 10th wave
@export var boss_enemy_scene: PackedScene
@export var boss_spawn_weight: float = 1.0  # Weight for boss spawning

# Health scaling settings
@export var health_increase_per_wave: float = 0.1  # 10% health increase per wave
@export var max_health_multiplier: float = 5.0     # Maximum health multiplier (5x base health)

@onready var timer: Timer = $Timer

var is_active: bool = false
var current_wave: int = 1
var special_enemy_unlocked: bool = false
var boss_spawn_enabled: bool = false
var base_enemy_health: Dictionary = {}  # Stores base health for each enemy type

func _ready() -> void:
	add_to_group("spawners")
	
	timer.wait_time = spawn_interval
	timer.autostart = false
	timer.one_shot = false
	timer.timeout.connect(_on_spawn_timer_timeout)
	
	set_active(false)
	
	# Initialize spawn weights if not set
	if spawn_weights.is_empty() and !enemy_scenes.is_empty():
		spawn_weights.resize(enemy_scenes.size())
		for i in spawn_weights.size():
			spawn_weights[i] = 1.0
	
	# Store base health values for all enemy types
	store_base_health_values()

func store_base_health_values():
	# Store base health for regular enemies
	for enemy_scene in enemy_scenes:
		if enemy_scene:
			var temp_enemy = enemy_scene.instantiate()
			if temp_enemy and "health" in temp_enemy and "max_health" in temp_enemy:
				var enemy_path = enemy_scene.resource_path
				base_enemy_health[enemy_path] = {
					"health": temp_enemy.health,
					"max_health": temp_enemy.max_health
				}
			temp_enemy.queue_free()
	
	# Store base health for special enemy
	if special_enemy_scene:
		var temp_enemy = special_enemy_scene.instantiate()
		if temp_enemy and "health" in temp_enemy and "max_health" in temp_enemy:
			var enemy_path = special_enemy_scene.resource_path
			base_enemy_health[enemy_path] = {
				"health": temp_enemy.health,
				"max_health": temp_enemy.max_health
			}
		temp_enemy.queue_free()
	
	# Store base health for boss enemy
	if boss_enemy_scene:
		var temp_enemy = boss_enemy_scene.instantiate()
		if temp_enemy and "health" in temp_enemy and "max_health" in temp_enemy:
			var enemy_path = boss_enemy_scene.resource_path
			base_enemy_health[enemy_path] = {
				"health": temp_enemy.health,
				"max_health": temp_enemy.max_health
			}
		temp_enemy.queue_free()

func set_active(active: bool) -> void:
	is_active = active
	if active:
		timer.start()
	else:
		timer.stop()

func set_spawning_active(active: bool) -> void:
	set_active(active)

func increase_difficulty(wave: int) -> void:
	current_wave = wave
	spawn_interval = max(0.5, spawn_interval * 0.95)
	max_enemies += 5

	# Check if this is a boss wave (every 10th wave)
	boss_spawn_enabled = (wave % 10 == 0) and boss_enemy_scene != null
	
	if timer and timer.time_left > 0:
		timer.wait_time = spawn_interval
	
	print("Wave ", wave, " - Enemy health increased!")

# New method to unlock special enemy
func unlock_special_enemy() -> void:
	if special_enemy_scene and not special_enemy_unlocked:
		special_enemy_unlocked = true
		print("Special enemy unlocked in spawner!")

func get_scaled_health_multiplier() -> float:
	# Calculate health multiplier based on current wave with cap
	var multiplier = 1.0 + (health_increase_per_wave * (current_wave - 1))
	return min(multiplier, max_health_multiplier)

func apply_health_scaling(enemy: Node) -> void:
	if not enemy or not ("health" in enemy and "max_health" in enemy):
		return
	
	var enemy_scene_path = enemy.get_scene_file_path()
	if enemy_scene_path in base_enemy_health:
		var base_stats = base_enemy_health[enemy_scene_path]
		var health_multiplier = get_scaled_health_multiplier()
		
		# Scale health values
		enemy.max_health = int(base_stats["max_health"] * health_multiplier)
		enemy.health = int(base_stats["health"] * health_multiplier)
		
		# Update healthbar if it exists
		if "healthbar" in enemy and enemy.healthbar:
			enemy.healthbar.max_value = enemy.max_health
			enemy.healthbar.value = enemy.health
		
		# Optional: Visual feedback for scaled enemies
		if health_multiplier > 1.5:
			# You could add a visual effect for tougher enemies
			pass

func get_random_enemy_scene() -> PackedScene:
	if enemy_scenes.is_empty():
		push_error("No enemy scenes assigned to spawner!")
		return null
	
	# Check if this is a boss wave and boss should spawn
	if boss_spawn_enabled and boss_enemy_scene:
		# Boss has priority on boss waves
		var total_weight: float = 0.0
		
		# Calculate total weight including all enemies
		for weight in spawn_weights:
			total_weight += weight
		
		if special_enemy_unlocked and special_enemy_scene:
			total_weight += special_enemy_spawn_weight
		
		total_weight += boss_spawn_weight
		
		var random_value = randf() * total_weight
		var cumulative_weight: float = 0.0
		
		# First check if we should spawn boss
		cumulative_weight += boss_spawn_weight
		if random_value <= cumulative_weight:
			boss_spawn_enabled = false  # Only spawn one boss per wave
			print("Spawning BOSS on wave ", current_wave)
			return boss_enemy_scene
		
		# Then check special enemy
		if special_enemy_unlocked and special_enemy_scene:
			cumulative_weight += special_enemy_spawn_weight
			if random_value <= cumulative_weight:
				return special_enemy_scene
		
		# Finally check regular enemies
		for i in enemy_scenes.size():
			cumulative_weight += spawn_weights[i]
			if random_value <= cumulative_weight:
				return enemy_scenes[i]
		
		# Fallback: return last regular enemy
		return enemy_scenes[enemy_scenes.size() - 1]
	
	# Normal wave spawning logic (non-boss waves)
	elif special_enemy_unlocked and special_enemy_scene:
		# Special enemy has a chance to spawn based on its weight
		var total_weight: float = 0.0
		
		# Calculate total weight including special enemy
		for weight in spawn_weights:
			total_weight += weight
		total_weight += special_enemy_spawn_weight
		
		var random_value = randf() * total_weight
		var cumulative_weight: float = 0.0
		
		# First check if we should spawn special enemy
		cumulative_weight += special_enemy_spawn_weight
		if random_value <= cumulative_weight:
			return special_enemy_scene
		
		# Then check regular enemies
		for i in enemy_scenes.size():
			cumulative_weight += spawn_weights[i]
			if random_value <= cumulative_weight:
				return enemy_scenes[i]
		
		# Fallback: return last regular enemy
		return enemy_scenes[enemy_scenes.size() - 1]
	
	else:
		# No special enemy unlocked, use regular weighted selection
		if !spawn_weights.is_empty() and spawn_weights.size() == enemy_scenes.size():
			var total_weight: float = 0.0
			for weight in spawn_weights:
				total_weight += weight
			
			var random_value = randf() * total_weight
			var cumulative_weight: float = 0.0
			
			for i in enemy_scenes.size():
				cumulative_weight += spawn_weights[i]
				if random_value <= cumulative_weight:
					return enemy_scenes[i]
	
	# Fallback: return random enemy if weights aren't set up properly
	return enemy_scenes[randi() % enemy_scenes.size()]

func _on_spawn_timer_timeout() -> void:
	if !is_active:
		return
	
	var current_enemies = get_tree().get_nodes_in_group("enemies").size()
	if current_enemies >= max_enemies:
		return
	
	var enemy_scene = get_random_enemy_scene()
	if enemy_scene == null:
		return
	
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * spawn_radius
	var spawn_pos = global_position + offset

	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	
	# Apply health scaling before adding to scene
	apply_health_scaling(enemy)
	
	get_parent().add_child(enemy)
	enemy.add_to_group("enemies")
	
	# Debug info
	print("Spawned enemy with health: ", enemy.health, "/", enemy.max_health, " (Wave ", current_wave, ")")

# Optional: Method to add enemy types dynamically
func add_enemy_type(enemy_scene: PackedScene, weight: float = 1.0) -> void:
	enemy_scenes.append(enemy_scene)
	spawn_weights.append(weight)
	
	# Store base health for the new enemy type
	var temp_enemy = enemy_scene.instantiate()
	if temp_enemy and "health" in temp_enemy and "max_health" in temp_enemy:
		var enemy_path = enemy_scene.resource_path
		base_enemy_health[enemy_path] = {
			"health": temp_enemy.health,
			"max_health": temp_enemy.max_health
		}
	temp_enemy.queue_free()

# Optional: Method to remove enemy type
func remove_enemy_type(index: int) -> void:
	if index >= 0 and index < enemy_scenes.size():
		var enemy_scene = enemy_scenes[index]
		var enemy_path = enemy_scene.resource_path
		if enemy_path in base_enemy_health:
			base_enemy_health.erase(enemy_path)
		
		enemy_scenes.remove_at(index)
		if index < spawn_weights.size():
			spawn_weights.remove_at(index)

# Optional: Method to update spawn weights
func set_enemy_weight(index: int, weight: float) -> void:
	if index >= 0 and index < spawn_weights.size():
		spawn_weights[index] = weight

# Get current health multiplier for debug purposes
func get_current_health_multiplier() -> float:
	return get_scaled_health_multiplier()
