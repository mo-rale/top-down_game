extends Node2D

const Bullet = preload("res://scene/bullet.tscn")

@export var fire_rate: float = 0.1
@export var damage: int = 30
@export var magazine_size: int = 30
@export var reload_time: float = 3.2

# 💥 Critical hit system
@export var crit_chance: float = 25.0  # 25% chance for critical hit
@export var crit_multiplier: float = 2.0  # 2x damage on critical hit

# --- Store Price ---
@export var price: int = 2100  # Price for the store

# --- Recoil Settings ---
@export var recoil_strength: float = -8.0
@export var recoil_recover_speed: float = 15.0

@onready var reloading: AudioStreamPlayer2D = $reloading
@onready var anim: AnimatedSprite2D = $Sprite2D
@onready var marker_2d: Marker2D = $Marker2D
@onready var shooting: AudioStreamPlayer2D = $shooting
@onready var pickable_area: Area2D = $pickable_area
@onready var collision_shape: CollisionShape2D = $pickable_area/CollisionShape2D

var fire_timer: float = 0.0
var current_ammo: int = magazine_size
var is_reloading: bool = false

# positional recoil (local space)
var original_position: Vector2
var recoil_offset: Vector2 = Vector2.ZERO

# --- Pickup variables ---
var is_equipped: bool = false
var player: Node2D = null
var is_player_nearby: bool = false


func _ready():
	original_position = position
	# Add to weapon pickup group for detection
	add_to_group("weapon_pickup")
	
	# Start as pickup if not equipped
	if not is_equipped:
		setup_as_pickup()
	
	print("M4A1 ready, equipped:", is_equipped)

func _process(delta: float) -> void:
	# Debug: Print occasionally to see if process is running
	if Engine.get_frames_drawn() % 180 == 0:
		print("M4A1 _process running. Equipped:", is_equipped, " Input 'fire':", Input.is_action_pressed("fire"))
	
	if not is_equipped:
		return
	
	# --- Apply recoil positional offset (local) and recover smoothly ---
	recoil_offset = recoil_offset.move_toward(Vector2.ZERO, recoil_recover_speed * delta)
	position = original_position + recoil_offset
	
	# Always aim toward mouse
	if Input.is_action_just_pressed("reload") and not is_reloading and current_ammo > 0 and current_ammo < magazine_size:
		reload()
	# Shooting logic
	if Input.is_action_pressed("fire") and not is_reloading:
		fire_timer -= delta
		if fire_timer <= 0.0:
			print("M4A1: Calling shoot() function")
			shoot()
			fire_timer = fire_rate
	else:
		fire_timer = max(fire_timer - delta, 0.0)

func shoot() -> void:
	if is_reloading or not is_equipped:
		print("M4A1: Cannot shoot - reloading:", is_reloading, " equipped:", is_equipped)
		return

	if current_ammo <= 0:
		print("M4A1: Out of ammo")
		reload()
		return

	current_ammo -= 1

	# 💥 Determine critical hit
	var is_crit = randf() < (crit_chance / 100.0)
	var final_damage = damage * (crit_multiplier if is_crit else 1.0)

	if is_crit:
		print("🔥 M4A1 CRITICAL HIT! Damage:", final_damage)
	else:
		print("M4A1: FIRING! Ammo left:", current_ammo, " Damage:", final_damage)

	# Debug: Check if bullet scene exists
	if not Bullet:
		print("❌ M4A1: Bullet scene is null!")
		return

	# Create and fire bullet
	var bullet_instance = Bullet.instantiate()
	if not bullet_instance:
		print("❌ M4A1: Failed to instantiate bullet!")
		return
	
	# Add to scene
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(bullet_instance)
		bullet_instance.global_position = marker_2d.global_position
		bullet_instance.rotation = marker_2d.global_rotation
		bullet_instance.damage = final_damage
		bullet_instance.speed = 1800.0
		
		# Set critical hit visual on the bullet only
		if is_crit and bullet_instance.has_method("set_critical"):
			bullet_instance.set_critical(true)
		
		print("✅ M4A1: Bullet fired from position:", marker_2d.global_position, " Crit:", is_crit)
	else:
		print("❌ M4A1: No current scene found!")

	# --- Horizontal-only recoil (local X axis) ---
	var strength = abs(recoil_strength)

	# Decide facing by parent's/global scale.x (if gun is child of hand, parent's scale affects global_scale)
	# If facing right (global_scale.x > 0) --> recoil should push left (negative X).
	# If facing left  (global_scale.x < 0) --> recoil should push right (positive X).
	if global_scale.x > 0:
		recoil_offset = Vector2(-strength, 0)
	else:
		recoil_offset = Vector2(strength, 0)

	# Play shot sound with pitch variation for critical hits
	if shooting:
		if is_crit:
			shooting.pitch_scale = randf_range(1.1, 1.3)  # Higher pitch for crits
		else:
			shooting.pitch_scale = randf_range(0.9, 1.1)
		shooting.play()
	else:
		print("❌ M4A1: No shooting audio node found!")

	if current_ammo <= 0:
		print("M4A1: Magazine empty")

func reload() -> void:
	if is_reloading or not is_equipped:
		return
	reloading.play()
	anim.play("reloading")
	is_reloading = true
	print("🔄 M4A1: Reloading...")
	
	await get_tree().create_timer(reload_time).timeout
	current_ammo = magazine_size
	is_reloading = false
	print("✅ M4A1: Reloaded! Ammo:", current_ammo)

# --- Pickup System ---
func setup_as_pickup():
	is_equipped = false
	visible = true
	set_process(false)
	
	# Enable pickup area collision
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	# Visual effect for pickup
	modulate = Color(1, 1, 1, 0.8)
	print("M4A1: Setup as pickup")

func on_picked_up(by_player: Node2D):
	if is_equipped:
		return
	
	player = by_player
	is_equipped = true
	is_player_nearby = false
	visible = true
	
	# Store original position for recoil system
	original_position = position
	
	# Disable pickup area collision
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Reset visual effects
	modulate = Color(1, 1, 1, 1)
	
	# Enable processing
	set_process(true)
	set_physics_process(true)
	
	print("M4A1: Picked up and equipped. Process:", is_processing())

func on_dropped():
	is_equipped = false
	player = null
	set_process(false)
	set_physics_process(false)
	setup_as_pickup()
	print("M4A1: Dropped")

func on_player_entered_detection():
	if not is_equipped and not is_player_nearby:
		is_player_nearby = true
		print("🔍 M4A1: Player detected me")
		modulate = Color(1.2, 1.2, 1.0, 0.9)

func on_player_exited_detection():
	if not is_equipped and is_player_nearby:
		is_player_nearby = false
		print("❌ M4A1: Player no longer detecting me")
		modulate = Color(1, 1, 1, 0.8)

# Getter for equipped status
func get_is_equipped() -> bool:
	return is_equipped

# Utility function for player
func set_weapon_enabled(enabled: bool):
	set_process(enabled)
	set_physics_process(enabled)
	if enabled:
		visible = true
		is_equipped = true
	else:
		is_equipped = false

# Get weapon stats for UI display
func get_weapon_stats() -> Dictionary:
	return {
		"name": "M4A1",
		"damage": damage,
		"crit_chance": crit_chance,
		"crit_multiplier": crit_multiplier,
		"fire_rate": fire_rate,
		"magazine_size": magazine_size,
		"current_ammo": current_ammo,
		"price": price  # Added price to stats
	}

# Get price for store system
func get_price() -> int:
	return price
