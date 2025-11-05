extends Node

# --- Game States ---
enum GameState {
	PREPARATION,
	WAVE_ACTIVE,
	WAVE_CLEANUP,
	GAME_OVER,
	PAUSED
}

# --- Game State ---
var current_currency: int = 0
var total_kills: int = 0
var game_time: float = 0.0
var player_current_weapon: String = ""
var player_current_ammo: int = 0
var current_state: GameState = GameState.PREPARATION

# --- Wave System ---
var current_wave: int = 0
var wave_timer: float = 0.0
var preparation_timer: float = 0.0
var wave_duration: float = 30.0  
var preparation_duration: float = 10.0
var cleanup_timer: float = 0.0
var cleanup_duration: float = 11.0

# ---- ANIMATION Reference ----
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# --- UI References ---
@onready var currency_label: Label = $UI/labels/CurrencyLabel
@onready var kills_label: Label = $UI/labels/KillsLabel
@onready var wave_label: Label = $UI/labels/Wave
@onready var time_label: Label = $UI/labels/TimeLabel
@onready var notification_label: Label = $UI/labels/Notification
@onready var current_ammo_label: Label = $UI/labels/Current_Ammo
@onready var current_weapon_label: Label = $UI/labels/Current_weapon
@onready var game_over_screen: Control = %GameOver
@onready var restart_button: Button = %Button
@onready var pause_menu: Control = $UI/PauseMenu
@onready var resume_button: Button = $UI/PauseMenu/NinePatchRect/resume

# --- Audio ---
@onready var ambiance: AudioStreamPlayer2D = $Sfx/ambiance

# --- Store UI References ---
@onready var shop_ui: Control = $UI/ShopUI

# --- Spawner Management ---
@onready var spawners: Array[Node] = [$spawner,$spawner2]

# --- Player Reference ---
var player: Node2D = null

# --- Store Management ---
var current_store: StaticBody2D = null

# --- Settings ---
@export var starting_currency: int = 100
@export var debug_mode: bool = false

# --- UI Hover Detection ---
signal ui_hover_changed(is_hovered: bool)
var is_ui_hovered: bool = false


func _ready():
	ambiance.play()
	current_currency = starting_currency
	total_kills = 0
	game_time = 0.0
	current_state = GameState.PREPARATION
	
	# Initialize wave system
	current_wave = 0
	wave_timer = 0.0
	preparation_timer = preparation_duration
	cleanup_timer = 0.0
	
	player = get_tree().get_first_node_in_group("player")
	
	# Find all spawner instances in the scene
	spawners = get_tree().get_nodes_in_group("spawners")
	
	add_to_group("game_manager")
	
	if game_over_screen:
		game_over_screen.visible = false
		game_over_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	
	if restart_button:
		restart_button.pressed.connect(restart_game)
	
	# Setup pause menu
	if pause_menu:
		pause_menu.visible = false
		pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	
	if resume_button:
		resume_button.pressed.connect(resume_game)
	
	update_ui()
	
	if player and player.has_method("get_current_weapon_name"):
		update_player_weapon(player.get_current_weapon_name(), player.get_current_weapon_ammo(), player.get_current_status())
	
	# Start with preparation phase
	start_preparation_phase()
	
	# Connect UI elements for mouse detection
	connect_ui_elements()

func _process(delta):
	if current_state == GameState.GAME_OVER:
		return
	
	if current_state == GameState.PAUSED:
		return  # Don't process game logic when paused
	
	if player and (!is_instance_valid(player) or !player.is_inside_tree()):
		if !game_over_screen.visible:
			on_player_died()
		return
	
	game_time += delta
	update_wave_timers(delta)
	update_ui()

func update_wave_timers(delta: float):
	match current_state:
		GameState.WAVE_ACTIVE:
			# Wave is active - count down wave timer
			wave_timer -= delta
			if wave_timer <= 0.0:
				# Wave time ended, start cleanup phase
				start_wave_cleanup()
		
		GameState.WAVE_CLEANUP:
			# Cleanup phase - give players time to finish off remaining enemies
			cleanup_timer -= delta
			if cleanup_timer <= 0.0 or get_remaining_enemies() == 0:
				# Cleanup completed or all enemies defeated
				complete_wave()
		
		GameState.PREPARATION:
			# Preparation phase - count down preparation timer
			preparation_timer -= delta
			if preparation_timer <= 0.0:
				# Preparation ended, start next wave
				start_next_wave()

#region Wave System
func start_preparation_phase():
	current_state = GameState.PREPARATION
	preparation_timer = preparation_duration
	cleanup_timer = 0.0
	
	# Disable spawners
	set_spawners_active(false)
	for store in get_tree().get_nodes_in_group("store"):
		if store and is_instance_valid(store) and store.has_method("play_opening_animation"):
			store.play_opening_animation()

	show_notification("Preparation Phase - Get Ready!")

func start_next_wave():
	current_wave += 1
	current_state = GameState.WAVE_ACTIVE
	wave_timer = wave_duration
	cleanup_timer = 0.0
	
	# Increase difficulty for this wave
	increase_difficulty()
	
	# Enable spawners
	set_spawners_active(true)
	for store in get_tree().get_nodes_in_group("store"):
		if store and is_instance_valid(store) and store.has_method("play_closing_animation"):
			store.play_closing_animation()
	show_notification("Wave " + str(current_wave) + " Incoming!")

func start_wave_cleanup():
	current_state = GameState.WAVE_CLEANUP
	cleanup_timer = cleanup_duration
	
	# Disable spawners immediately when cleanup starts
	set_spawners_active(false)
	
	var remaining_enemies = get_remaining_enemies()
	if remaining_enemies > 0:
		show_notification("Wave Complete! Finish off " + str(remaining_enemies) + " remaining enemies!")
	else:
		show_notification("Wave Complete! No enemies remaining!")

func complete_wave():
	current_state = GameState.PREPARATION
	preparation_timer = preparation_duration
	
	var remaining_enemies = get_remaining_enemies()
	var wave_bonus = current_wave * 50  # Base bonus currency
	
	# Bonus for clearing all enemies
	if remaining_enemies == 0:
		wave_bonus += current_wave * 25  # Extra bonus for perfect clear
		show_notification("Wave " + str(current_wave) + " Perfect Clear! +$" + str(wave_bonus))
	else:
		# Small penalty for remaining enemies, but still give reward
		var penalty = remaining_enemies * 5
		wave_bonus = max(wave_bonus - penalty, current_wave * 25)  # Minimum reward
		show_notification("Wave " + str(current_wave) + " Complete! " + str(remaining_enemies) + " enemies escaped. +$" + str(wave_bonus))
	
	add_currency(wave_bonus)
	start_preparation_phase()

func get_remaining_enemies() -> int:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_inside_tree():
			count += 1
	return count

func clear_remaining_enemies():
	# Only clear enemies if absolutely necessary (game over, etc.)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()

func increase_difficulty():
	# Increase difficulty for all spawners
	for spawner in spawners:
		if spawner and is_instance_valid(spawner):
			if spawner.has_method("increase_difficulty"):
				spawner.increase_difficulty(current_wave)
			else:
				# Basic difficulty scaling
				spawner.spawn_interval = max(0.5, spawner.spawn_interval * 0.95)
				spawner.max_enemies += 1

func get_wave_time_remaining() -> float:
	match current_state:
		GameState.WAVE_ACTIVE:
			return wave_timer
		GameState.WAVE_CLEANUP:
			return cleanup_timer
		GameState.PREPARATION:
			return preparation_timer
		_:
			return 0.0

func get_wave_status() -> String:
	match current_state:
		GameState.WAVE_ACTIVE:
			return "WAVE " + str(current_wave) + " - " + format_time(wave_timer)
		GameState.WAVE_CLEANUP:
			var remaining = get_remaining_enemies()
			return "CLEANUP - " + format_time(cleanup_timer) + " - " + str(remaining) + " left"
		GameState.PREPARATION:
			return "PREP - " + format_time(preparation_timer) + " - Wave " + str(current_wave + 1)
		GameState.GAME_OVER:
			return "GAME OVER"
		GameState.PAUSED:
			return "PAUSED"
		_:
			return ""

func set_spawners_active(active: bool):
	for spawner in spawners:
		if spawner and is_instance_valid(spawner):
			if spawner.has_method("set_active"):
				spawner.set_active(active)
			elif spawner.has_method("set_spawning_active"):
				spawner.set_spawning_active(active)
#endregion

#region UI Management
func update_ui():
	if currency_label:
		currency_label.text = "Money: $" + str(current_currency)
	
	if kills_label:
		kills_label.text = "Kills: " + str(total_kills)
	
	if wave_label:
		wave_label.text = get_wave_status()
	
	if time_label:
		var minutes = float(game_time) / 60
		var seconds = int(game_time) % 60
		time_label.text = "%02d:%02d" % [minutes, seconds]

func update_player_weapon(weapon_name: String, current_ammo: int, _status: String) -> void:
	player_current_weapon = weapon_name
	player_current_ammo = current_ammo
	
	if current_ammo_label:
		if player_current_ammo == 0:
			current_ammo_label.text = "RELOADING"
		else:
			current_ammo_label.text = "AMMO: " + str(current_ammo)
	
	if current_weapon_label:
		current_weapon_label.text = "WEAPON: " + weapon_name

func show_notification(message: String, duration: float = 5.0) -> void:
	if notification_label:
		notification_label.text = message
		notification_label.visible = true
		
		var timer = get_tree().create_timer(duration)
		await timer.timeout
		
		if notification_label:
			notification_label.visible = false

func format_time(seconds: float) -> String:
	var mins = float(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [mins, secs]
#endregion

#region Currency System
func add_currency(amount: int):
	current_currency += amount
	update_ui()

func spend_currency(amount: int) -> bool:
	if current_currency >= amount:
		current_currency -= amount
		update_ui()
		return true
	return false

func get_current_currency() -> int:
	return current_currency
#endregion

#region Enemy System
func enemy_killed_reward(currency_reward: int):
	total_kills += 1
	add_currency(currency_reward)

func kill_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(9999)
#endregion

#region Game State Management
func game_over():
	if current_state == GameState.GAME_OVER:
		return
		
	current_state = GameState.GAME_OVER
	
	if game_over_screen:
		game_over_screen.visible = true

func restart_game():
	if game_over_screen:
		game_over_screen.process_mode = Node.PROCESS_MODE_INHERIT
		for child in game_over_screen.get_children():
			child.process_mode = Node.PROCESS_MODE_INHERIT
	
	get_tree().reload_current_scene()

func pause_game():
	if current_state != GameState.GAME_OVER and current_state != GameState.PAUSED:
		current_state = GameState.PAUSED
		
		# Show pause menu
		if pause_menu:
			pause_menu.visible = true
		
		# Set process mode for game elements to disabled
		set_game_elements_process(false)

func resume_game():
	if current_state == GameState.PAUSED:
		# Hide pause menu
		if pause_menu:
			pause_menu.visible = false
		
		# Restore process mode for game elements
		set_game_elements_process(true)
		
		# Update the state based on timers
		if cleanup_timer > 0:
			current_state = GameState.WAVE_CLEANUP
		elif wave_timer > 0:
			current_state = GameState.WAVE_ACTIVE
		else:
			current_state = GameState.PREPARATION

func set_game_elements_process(enabled: bool):
	# Set process mode for enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.set_process(enabled)
			enemy.set_physics_process(enabled)
	
	# Set process mode for player
	if player and is_instance_valid(player):
		player.set_process(enabled)
		player.set_physics_process(enabled)
	
	# Set process mode for projectiles
	var projectiles = get_tree().get_nodes_in_group("bullet")
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.set_process(enabled)
			projectile.set_physics_process(enabled)
	
	# Handle spawners based on the actual game state, not just enabled/disabled
	for spawner in spawners:
		if is_instance_valid(spawner) and spawner.has_method("set_active"):
			if enabled:
				# Only enable spawners if we're in WAVE_ACTIVE state
				# We need to check what state we're RETURNING TO after pause
				if cleanup_timer > 0:
					# Returning to WAVE_CLEANUP - keep spawners disabled
					spawner.set_active(false)
				elif wave_timer > 0:
					# Returning to WAVE_ACTIVE - enable spawners
					spawner.set_active(true)
				else:
					# Returning to PREPARATION - keep spawners disabled
					spawner.set_active(false)
			else:
				# When pausing, always disable spawners
				spawner.set_active(false)

func is_store_available() -> bool:
	return current_state == GameState.PREPARATION
#endregion

#region Store UI Management - Simplified
func open_store_ui(store: StaticBody2D) -> void:
	if not is_store_available():
		return
	
	current_store = store
	if shop_ui:
		animation_player.play("store_ui_open")

func close_store_ui() -> void:
	current_store = null
	if shop_ui:
		animation_player.play("store_ui_close")

func update_store_ui() -> void:
	# This will be handled by your custom store UI implementation
	pass
#endregion

#region UI Hover Detection
func connect_ui_elements():
	# Connect all UI elements that should block shooting
	var ui_elements = [
		shop_ui,
		pause_menu,
		game_over_screen
	]
	
	for ui_element in ui_elements:
		if ui_element and is_instance_valid(ui_element):
			# Make sure they capture mouse events
			ui_element.mouse_filter = Control.MOUSE_FILTER_STOP
			
			# Connect mouse signals
			if not ui_element.mouse_entered.is_connected(_on_ui_mouse_entered):
				ui_element.mouse_entered.connect(_on_ui_mouse_entered)
			if not ui_element.mouse_exited.is_connected(_on_ui_mouse_exited):
				ui_element.mouse_exited.connect(_on_ui_mouse_exited)
			
			# Also connect for all child controls
			connect_child_controls(ui_element)

func connect_child_controls(node: Node):
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_STOP
			if not child.mouse_entered.is_connected(_on_ui_mouse_entered):
				child.mouse_entered.connect(_on_ui_mouse_entered)
			if not child.mouse_exited.is_connected(_on_ui_mouse_exited):
				child.mouse_exited.connect(_on_ui_mouse_exited)
			# Recursively connect grandchildren
			connect_child_controls(child)

func _on_ui_mouse_entered():
	if !is_ui_hovered:
		is_ui_hovered = true
		ui_hover_changed.emit(true)

func _on_ui_mouse_exited():
	if is_ui_hovered:
		is_ui_hovered = false
		ui_hover_changed.emit(false)

func get_is_ui_hovered() -> bool:
	return is_ui_hovered
#endregion

#region Player Events
func on_player_died():
	game_over()

func _input(event):
	if current_state == GameState.GAME_OVER:
		return
	
	if debug_mode and event.is_action_pressed("debug_add"):
		add_currency(100)
	
	if debug_mode and event.is_action_pressed("debug_kill"):
		kill_all_enemies()
	
	# Pause input - only process if not already in pause menu
	if event.is_action_pressed("ui_cancel"):
		if current_state == GameState.PAUSED:
			resume_game()
		elif current_state != GameState.GAME_OVER:
			pause_game()
#endregion

#region Save/Load System
func save_game():
	var save_data = {
		"currency": current_currency,
		"kills": total_kills,
		"game_time": game_time,
		"current_wave": current_wave,
		"current_state": current_state,
		"timestamp": Time.get_datetime_string_from_system()
	}
	return save_data

func load_game():
	pass
#endregion

#region Getter Functions
func get_total_kills() -> int:
	return total_kills

func get_game_time() -> float:
	return game_time

func is_game_running() -> bool:
	return current_state != GameState.GAME_OVER and current_state != GameState.PAUSED

func get_current_wave() -> int:
	return current_wave

func is_wave_in_progress() -> bool:
	return current_state == GameState.WAVE_ACTIVE or current_state == GameState.WAVE_CLEANUP

func get_game_state() -> GameState:
	return current_state

func get_remaining_enemy_count() -> int:
	return get_remaining_enemies()
#endregion
