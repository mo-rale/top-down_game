extends CharacterBody2D

# --- Signals ---
signal weapons_updated

# --- Player Stats stored in a dictionary ---
@export var stats := {
	"SPEED": 230.0,
	"ACCELERATION": 10.0,
	"DECELERATION": 8.0,
	"HEALTH": 100,
	"CAMERA_LEAN_STRENGTH": 0.2,
	"BASH_DAMAGE": 10
}

# --- Inventory System ---
@export var max_inventory_size: int = 3
@export var inventory: Array[Node2D] = []     # stores weapon nodes
var current_weapon_index: int = 0     # which weapon is currently equipped

# --- Weapon Switching Cooldown ---
var weapon_switch_cooldown: float = 0.3  # 300ms cooldown between switches
var last_weapon_switch_time: float = 0.0
var can_switch_weapon: bool = true

# --- State variables ---
var max_health: int
var is_dead: bool = false
var target_velocity: Vector2 = Vector2.ZERO

# --- Node references ---
@onready var camera_2d: Camera2D = $head/Camera2D
@onready var health_bar: ProgressBar = $ProgressBar
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hand: Node2D = $hand
@onready var default_gun: Node2D = $hand/revolver
@onready var pick_area: Area2D = $pick_area
@onready var bash_area: Area2D = $bash_area
@onready var anim: AnimationPlayer = $AnimationPlayer

# --- Pickup variables ---
var nearby_weapons: Array[Node2D] = []
var closest_weapon: Node2D = null


# --- Setup ---
func _ready():
	max_health = stats["HEALTH"]
	health_bar.value = max_health
	# Add default weapon to inventory at start
	add_weapon(default_gun)
	current_weapon_index = 0
	
	# Connect pick area signals
	pick_area.connect("area_entered", Callable(self, "_on_pick_area_entered"))
	pick_area.connect("area_exited", Callable(self, "_on_pick_area_exited"))
	pick_area.connect("body_entered", Callable(self, "_on_pick_area_body_entered"))
	pick_area.connect("body_exited", Callable(self, "_on_pick_area_body_exited"))
	bash_area.connect("body_entered", Callable(self, "_on_bashing_area_enetered"))

# --- Movement & Input ---
func get_input():
	if is_dead:
		target_velocity = Vector2.ZERO
		return

	var input_direction = Input.get_vector("left", "right", "up", "down")
	target_velocity = input_direction * stats["SPEED"]

	# Bashing
	if Input.is_action_just_pressed("bash"):
		bashing()

	# Weapon Switching with cooldown
	if can_switch_weapon:
		if Input.is_action_just_pressed("weapon_next"):
			switch_weapon(1)
		elif Input.is_action_just_pressed("weapon_prev"):
			switch_weapon(-1)
	
	# Pick up weapon
	if Input.is_action_just_pressed("interact"):
		try_pick_up_weapon()
func _physics_process(delta):
	health_bar.value = stats["HEALTH"]
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		sprite.play("idle")
		return
	
	# Update weapon switch cooldown
	update_weapon_switch_cooldown(delta)
	
	update_game_manager_weapon()
	get_input()

	# Movement smoothing
	if target_velocity.length() > 0:
		velocity = velocity.lerp(target_velocity, stats["ACCELERATION"] * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, stats["DECELERATION"] * delta)

	move_and_slide()

	# Camera lean
	var mouse_pos = get_global_mouse_position()
	var dir_to_mouse = (mouse_pos - global_position) * stats["CAMERA_LEAN_STRENGTH"]
	camera_2d.offset = dir_to_mouse

	# Hand aiming
	hand.look_at(mouse_pos)

	# Flip player + hand
	var facing_left = mouse_pos.x < global_position.x
	sprite.flip_h = facing_left
	hand.scale.y = -1 if facing_left else 1

	# Animation handling
	if velocity.length() > 10:
		if sprite.animation != "walking":
			sprite.play("walking")
	else:
		if sprite.animation == "walking":
			sprite.stop()
			sprite.frame = 0
		if sprite.animation != "idle":
			sprite.play("idle")
	
	# Update closest weapon for pickup highlighting
	update_closest_weapon()

# --- Weapon Switch Cooldown Management ---
func update_weapon_switch_cooldown(delta: float):
	if not can_switch_weapon:
		last_weapon_switch_time += delta
		if last_weapon_switch_time >= weapon_switch_cooldown:
			can_switch_weapon = true
			last_weapon_switch_time = 0.0

# --- Pickup Area Detection ---
func _on_pick_area_entered(area: Area2D):
	if area.is_in_group("weapon_pickup"):
		var weapon = area.get_parent()
		if weapon and weapon not in nearby_weapons:
			nearby_weapons.append(weapon)
			print("Weapon nearby:", weapon.name)
			if weapon.has_method("on_player_entered_detection"):
				weapon.on_player_entered_detection()
func _on_pick_area_exited(area: Area2D):
	if area.is_in_group("weapon_pickup"):
		var weapon = area.get_parent()
		if weapon in nearby_weapons:
			nearby_weapons.erase(weapon)
			print("Weapon no longer nearby:", weapon.name)
			if weapon.has_method("on_player_exited_detection"):
				weapon.on_player_exited_detection()
func _on_pick_area_body_entered(body: Node2D):
	if body.is_in_group("weapon_pickup"):
		if body not in nearby_weapons:
			nearby_weapons.append(body)
			print("Weapon nearby:", body.name)
			if body.has_method("on_player_entered_detection"):
				body.on_player_entered_detection()
func _on_pick_area_body_exited(body: Node2D):
	if body.is_in_group("weapon_pickup"):
		if body in nearby_weapons:
			nearby_weapons.erase(body)
			print("Weapon no longer nearby:", body.name)
			if body.has_method("on_player_exited_detection"):
				body.on_player_exited_detection()
func update_closest_weapon():
	if nearby_weapons.is_empty():
		closest_weapon = null
		return
	
	var closest_distance = INF
	var new_closest_weapon = null
	
	for weapon in nearby_weapons:
		var distance = global_position.distance_to(weapon.global_position)
		if distance < closest_distance:
			closest_distance = distance
			new_closest_weapon = weapon
	
	closest_weapon = new_closest_weapon
func try_pick_up_weapon():
	if closest_weapon and closest_weapon not in inventory:
		collect_weapon(closest_weapon)
		nearby_weapons.erase(closest_weapon)
		closest_weapon = null
	elif nearby_weapons.size() > 0:
		var weapon_to_pick = nearby_weapons[0]
		if weapon_to_pick not in inventory:
			collect_weapon(weapon_to_pick)
			nearby_weapons.erase(weapon_to_pick)

# --- Inventory System ---
func add_weapon(weapon: Node2D) -> bool:
	if inventory.size() >= max_inventory_size:
		print("⚠️ Inventory full! Can't add more weapons.")
		return false
	
	if weapon not in inventory:
		inventory.append(weapon)
		print("🔫 Added weapon:", weapon.name)
		update_equipped_weapon()
		return true
	return false
func collect_weapon(weapon: Node2D) -> void:
	if add_weapon(weapon):
		var original_parent = weapon.get_parent()
		if original_parent:
			original_parent.remove_child(weapon)
		hand.add_child(weapon)
		
		weapon.position = Vector2.ZERO
		weapon.rotation = 0
		weapon.scale = Vector2.ONE
		
		disable_weapon_pickup(weapon)
		
		if weapon.has_method("on_picked_up"):
			weapon.on_picked_up(self)
		
		switch_to_weapon_slot(inventory.size() - 1)
		print("🎯 Collected and equipped:", weapon.name)
		weapons_updated.emit()
		update_game_manager_weapon()
func disable_weapon_pickup(weapon: Node2D):
	for child in weapon.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D or child is Area2D:
			child.set_deferred("disabled", true)
func enable_weapon_pickup(weapon: Node2D):
	for child in weapon.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D or child is Area2D:
			child.set_deferred("disabled", false)
func drop_weapon(index: int) -> void:
	if index < 0 or index >= inventory.size():
		print("❌ Invalid weapon index to drop.")
		return
	
	if inventory[index] == default_gun:
		print("❌ Cannot drop default weapon.")
		return
	
	var dropped_weapon = inventory[index]
	inventory.remove_at(index)
	print("💰 Sold weapon:", dropped_weapon.name)
	
	hand.remove_child(dropped_weapon)
	get_parent().add_child(dropped_weapon)
	dropped_weapon.global_position = global_position + Vector2(50, 0).rotated(rotation)
	
	enable_weapon_pickup(dropped_weapon)
	
	if dropped_weapon.has_method("on_dropped"):
		dropped_weapon.on_dropped()
	
	# Schedule weapon for cleanup after 10 seconds
	schedule_weapon_cleanup(dropped_weapon)
	
	if current_weapon_index >= inventory.size():
		current_weapon_index = max(inventory.size() - 1, 0)
	
	update_equipped_weapon()
	weapons_updated.emit()
func schedule_weapon_cleanup(weapon: Node2D) -> void:
	var cleanup_timer = Timer.new()
	weapon.add_child(cleanup_timer)
	cleanup_timer.wait_time = 10.0
	cleanup_timer.one_shot = true
	cleanup_timer.connect("timeout", Callable(self, "_on_weapon_cleanup_timeout").bind(weapon, cleanup_timer))
	cleanup_timer.start()
	print("⏰ Scheduled cleanup for", weapon.name, "in 10 seconds")
func _on_weapon_cleanup_timeout(weapon: Node2D, timer: Timer) -> void:
	print("🗑️ Cleaning up dropped weapon:", weapon.name)
	
	if timer and is_instance_valid(timer):
		timer.queue_free()
	
	if weapon and is_instance_valid(weapon):
		weapon.queue_free()
func switch_weapon(direction: int) -> void:
	if inventory.size() <= 1 or not can_switch_weapon:
		return
	
	# Start cooldown
	can_switch_weapon = false
	last_weapon_switch_time = 0.0
	
	var old_index = current_weapon_index
	current_weapon_index = (current_weapon_index + direction) % inventory.size()
	if current_weapon_index < 0:
		current_weapon_index = inventory.size() - 1
	
	# Only update if the index actually changed
	if old_index != current_weapon_index:
		update_equipped_weapon()
		weapons_updated.emit()
		update_game_manager_weapon()
		print("🔀 Switched to weapon:", current_weapon_index)
	else:
		# If no change, allow immediate switching again
		can_switch_weapon = true
func switch_to_weapon_slot(slot: int) -> void:
	if slot < 0 or slot >= inventory.size() or slot == current_weapon_index or not can_switch_weapon:
		return
	
	# Start cooldown
	can_switch_weapon = false
	last_weapon_switch_time = 0.0
	
	current_weapon_index = slot
	update_equipped_weapon()
	weapons_updated.emit()
	update_game_manager_weapon()
func update_equipped_weapon() -> void:
	if inventory.is_empty():
		return

	# Disable all weapons first
	for weapon in inventory:
		print("recent: " + str(weapon))
		if weapon.has_method("stop_reload"):
			print("reloading of " + str(weapon) + "has stopped")
			weapon.stop_reload()
		weapon.visible = false
		weapon.set_process(false)
		weapon.set_physics_process(false)
	
	# Enable only the current weapon
	var current_weapon = inventory[current_weapon_index]
	print("current: " + str(current_weapon))
	if current_weapon.current_ammo <= 0:
		current_weapon.reload()
	current_weapon.visible = true
	current_weapon.set_process(true)
	current_weapon.set_physics_process(true)
	
	update_game_manager_weapon()

# --- Damage and Death System ---
func take_damage(damage: int) -> void:
	if is_dead:
		return

	stats["HEALTH"] -= damage
	stats["HEALTH"] = clamp(stats["HEALTH"], 0, max_health)
	health_bar.value = stats["HEALTH"]
	
	damage_flash()
	
	print("Player Health:", stats["HEALTH"])

	if stats["HEALTH"] <= 0:
		die()
func damage_flash():
	var original_modulate = sprite.modulate
	sprite.modulate = Color(2.0, 0.5, 0.5)
	
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", original_modulate, 0.3)
	tween.set_ease(Tween.EASE_OUT)
func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	print("💀 Player has died.")
	sprite.play("idle")

	for weapon in inventory:
		if weapon and weapon.has_method("set_process"):
			weapon.set_process(false)
			weapon.set_physics_process(false)
	
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("on_player_died"):
		game_manager.on_player_died()
func bashing():
	anim.play("bashing")
func _on_bashing_area_enetered(body: Node2D):
	var enemy = body
	if enemy.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(stats["BASH_DAMAGE"], velocity)

# --- Health Management ---
func heal(amount: int) -> void:
	if is_dead:
		return
	
	stats["HEALTH"] += amount
	stats["HEALTH"] = clamp(stats["HEALTH"], 0, max_health)
	health_bar.value = stats["HEALTH"]
	print("❤️ Player healed: +", amount, " | Health: ", stats["HEALTH"])
func get_health_percentage() -> float:
	return float(stats["HEALTH"]) / float(max_health)

# --- UI Interactions ---
func update_game_manager_weapon():
	var current_status = get_current_status()
	var weapon_ammo = get_current_weapon_ammo()
	var weapon_name = get_current_weapon_name()
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("update_player_weapon"):
		game_manager.update_player_weapon(weapon_name, weapon_ammo, current_status)

# --- Weapon Data Getters ---
func get_current_weapon_name() -> String:
	if inventory.is_empty():
		return "None"
	
	var current_weapon = inventory[current_weapon_index]
	return current_weapon.name
func get_weapon_at_index(index: int) -> Node2D:
	if index >= 0 and index < inventory.size():
		return inventory[index]
	return null
func get_current_status() -> String:
	if inventory.is_empty():
		return "None"
	var current_weapon = inventory[current_weapon_index]
	if current_weapon.has_method("get_status_text"):
		return current_weapon.get_status_text()
	return "UNKNOWN"
func get_current_weapon() -> Node2D:
	if inventory.is_empty():
		return null
	return inventory[current_weapon_index]
func get_current_weapon_ammo() -> int:
	if inventory.is_empty():
		return 0
	
	var current_weapon = inventory[current_weapon_index]
	return current_weapon.current_ammo
func get_weapon_count() -> int:
	return inventory.size()

# --- Utility Functions ---
func is_player_alive() -> bool:
	return !is_dead and stats["HEALTH"] > 0
func get_player_position() -> Vector2:
	return global_position
