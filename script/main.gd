extends Node

# --- Game State ---
var current_currency: int = 0
var total_kills: int = 0
var game_time: float = 0.0
var is_game_active: bool = true

# --- UI References ---
@onready var currency_label: Label = $UI/CurrencyLabel
@onready var kills_label: Label = $UI/KillsLabel
@onready var time_label: Label = $UI/TimeLabel
@onready var game_over_screen: Control = $UI/GameOver
@onready var restart_button: Button = %Button  # Fixed spelling
@onready var notification: Label = $UI/Notification

# --- Wave Spawning ---
@export var enemy_scene: PackedScene
@export var max_enemies: int = 10
@export var spawn_interval: float = 3.0
@export var spawn_areas: Array[Node2D] = []

var current_enemies: int = 0
var spawn_timer: float = 0.0

# --- Player Reference ---
var player: Node2D = null

# --- Settings ---
@export var starting_currency: int = 100
@export var debug_mode: bool = false

# Add this for selective pausing
var original_game_states: Dictionary = {}


func _ready():
	# Initialize game state
	current_currency = starting_currency
	total_kills = 0
	game_time = 0.0
	is_game_active = true
	
	# Find player
	player = get_tree().get_first_node_in_group("player")
	
	# Add to group for enemy access
	add_to_group("game_manager")
	add_to_group("spawners")  # Add this so store can find and pause this
	
	# Hide game over screen at start
	if game_over_screen:
		game_over_screen.visible = false
		# Make sure game over screen can process even when paused
		game_over_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect restart button (fixed variable name)
	if restart_button:
		restart_button.pressed.connect(restart_game)
	
	# Initialize UI
	update_ui()
	
	if debug_mode:
		print("🎮 Game Manager initialized with $", current_currency, " starting currency")

func _process(delta):
	if !is_game_active:
		return
	
	# Auto-detect player death if they disappear from scene
	if player and (!is_instance_valid(player) or !player.is_inside_tree()):
		if !game_over_screen.visible:  # Only trigger once
			on_player_died()
		return
	
	# Update game time
	game_time += delta
	
	# Handle enemy spawning
	if current_enemies < max_enemies:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_enemy()
			spawn_timer = spawn_interval
	
	# Update UI every frame
	update_ui()


func update_ui():
	# Update currency display
	if currency_label:
		currency_label.text = "$" + str(current_currency)
	
	# Update kills display
	if kills_label:
		kills_label.text = "Kills: " + str(total_kills)
	
	# Update time display
	if time_label:
		var minutes = int(game_time) / 60
		var seconds = int(game_time) % 60
		time_label.text = "Time: %02d:%02d" % [minutes, seconds]


# --- Currency System ---
func add_currency(amount: int):
	current_currency += amount
	if debug_mode:
		print("💰 Added $", amount, " | Total: $", current_currency)
	update_ui()


func spend_currency(amount: int) -> bool:
	if current_currency >= amount:
		current_currency -= amount
		if debug_mode:
			print("💸 Spent $", amount, " | Remaining: $", current_currency)
		update_ui()
		return true
	else:
		if debug_mode:
			print("❌ Not enough currency! Need: $", amount, " | Have: $", current_currency)
		return false

# Add this function to your Game Manager script (with other functions)
func show_notification(message: String, duration: float = 5.0) -> void:
	if notification:
		notification.text = message
		notification.visible = true
		
		# Create a timer to hide the notification
		var timer = get_tree().create_timer(duration)
		await timer.timeout
		
		if notification:
			notification.visible = false
	else:
		print("❌ No notification label found for message:", message)

func enemy_killed_reward(currency_reward: int):
	total_kills += 1
	add_currency(currency_reward)
	
	if debug_mode:
		print("🎯 Enemy killed! Reward: $", currency_reward, " | Total kills: ", total_kills)


# --- Enemy Spawning ---
func spawn_enemy():
	if !enemy_scene or current_enemies >= max_enemies:
		return
	
	var spawn_area = get_random_spawn_area()
	if !spawn_area or !player:
		return
	
	var enemy = enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	
	# Position enemy at spawn area
	enemy.global_position = spawn_area.global_position
	
	current_enemies += 1
	
	if debug_mode:
		print("👹 Spawned enemy at position: ", spawn_area.global_position, " | Total enemies: ", current_enemies)


func get_random_spawn_area() -> Node2D:
	if spawn_areas.is_empty():
		return null
	return spawn_areas[randi() % spawn_areas.size()]


func on_enemy_died():
	current_enemies -= 1
	if debug_mode:
		print("💀 Enemy died | Remaining enemies: ", current_enemies)


# --- Game State Management ---
func game_over():
	if !is_game_active:
		return
		
	is_game_active = false
	
	# Show game over screen
	if game_over_screen:
		game_over_screen.visible = true
	
	# Use selective pausing instead of global pausing
	pause_game_selectively(true)
	
	if debug_mode:
		print("🎮 Game Over! Final stats - Kills: ", total_kills, " | Time: ", game_time, " | Currency: $", current_currency)


func pause_game_but_keep_ui():
	# Don't use global pause - use selective pausing instead
	pause_game_selectively(true)


func pause_game_selectively(pause: bool) -> void:
	if pause:
		# Store original states and pause everything except UI
		store_and_pause_game_elements()
	else:
		# Restore original states
		restore_game_elements()


func store_and_pause_game_elements() -> void:
	# Clear previous states
	original_game_states.clear()
	
	# Pause enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			original_game_states[enemy.get_path()] = {
				"process": enemy.process_mode,
				"physics_process": enemy.is_physics_processing()
			}
			enemy.set_process(false)
			enemy.set_physics_process(false)
	
	# Pause spawners (including this game manager)
	var spawners = get_tree().get_nodes_in_group("spawners")
	for spawner in spawners:
		if is_instance_valid(spawner):
			original_game_states[spawner.get_path()] = {
				"process": spawner.process_mode,
				"physics_process": spawner.is_physics_processing()
			}
			spawner.set_process(false)
			spawner.set_physics_process(false)
	
	# Pause player
	if player and is_instance_valid(player):
		original_game_states[player.get_path()] = {
			"process": player.process_mode,
			"physics_process": player.is_physics_processing()
		}
		player.set_process(false)
		player.set_physics_process(false)
	
	print("⏸️ Game paused: ", enemies.size(), " enemies, ", spawners.size(), " spawners")


func restore_game_elements() -> void:
	# Restore enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and original_game_states.has(enemy.get_path()):
			enemy.set_process(true)
			enemy.set_physics_process(true)
	
	# Restore spawners
	var spawners = get_tree().get_nodes_in_group("spawners")
	for spawner in spawners:
		if is_instance_valid(spawner) and original_game_states.has(spawner.get_path()):
			spawner.set_process(true)
			spawner.set_physics_process(true)
	
	# Restore player
	if player and is_instance_valid(player) and original_game_states.has(player.get_path()):
		player.set_process(true)
		player.set_physics_process(true)
	
	print("▶️ Game resumed: ", enemies.size(), " enemies, ", spawners.size(), " spawners")


func restart_game():
	# Restore game elements first
	restore_game_elements()
	
	# Reset process modes for UI
	if game_over_screen:
		game_over_screen.process_mode = Node.PROCESS_MODE_INHERIT
		for child in game_over_screen.get_children():
			child.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Reload current scene
	get_tree().reload_current_scene()


func pause_game():
	pause_game_selectively(true)
	is_game_active = false


func resume_game():
	pause_game_selectively(false)
	is_game_active = true


# --- Player Events ---
func on_player_died():
	game_over()


func on_player_health_changed(current_health: int, max_health: int):
	if debug_mode:
		print("❤️ Player health: ", current_health, "/", max_health)


# --- Debug Functions ---
func _input(event):
	# Allow debug inputs even when paused
	if debug_mode and event.is_action_pressed("debug_add_currency"):
		add_currency(100)
		print("🔧 DEBUG: Added $100 currency")
	
	if debug_mode and event.is_action_pressed("debug_kill_all"):
		kill_all_enemies()
	
	if debug_mode and event.is_action_pressed("debug_game_over"):
		game_over()
		print("🔧 DEBUG: Forced game over")


func kill_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(9999)
	print("🔧 DEBUG: Killed all enemies")


# --- Save/Load System ---
func save_game():
	var save_data = {
		"currency": current_currency,
		"kills": total_kills,
		"game_time": game_time,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	if debug_mode:
		print("💾 Game saved: ", save_data)
	
	return save_data


func load_game():
	if debug_mode:
		print("📂 Game loaded")


# --- Getter Functions ---
func get_current_currency() -> int:
	return current_currency


func get_total_kills() -> int:
	return total_kills


func get_game_time() -> float:
	return game_time


func is_game_running() -> bool:
	return is_game_active


# --- Wave Management ---
func increase_difficulty():
	max_enemies += 2
	spawn_interval = max(0.5, spawn_interval * 0.9)
	
	if debug_mode:
		print("📈 Difficulty increased! Max enemies: ", max_enemies, " | Spawn interval: ", spawn_interval)
