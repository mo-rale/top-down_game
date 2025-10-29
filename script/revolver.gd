extends Node2D

const Bullet = preload("res://scene/bullet.tscn")

@export var fire_rate: float = 0.4
@export var damage: int = 50
@export var magazine_size: int = 8
@export var reload_time: float = 3.5

# note: recoil_strength can be negative in your current values; we'll use abs() internally
@export var recoil_strength: float = -10
@export var recoil_recover_speed: float = 12

# 💥 Critical hit system
@export var crit_chance: float = 60.0
@export var crit_multiplier: float = 2.0

@onready var marker_2d: Marker2D = $Marker2D
@onready var reloading: AudioStreamPlayer2D = $reloading
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
var is_equipped: bool = true  # Start as equipped by default
var player: Node2D = null
var is_player_nearby: bool = false


func _ready() -> void:
	original_position = position
	# Add to weapon pickup group for detection
	add_to_group("weapon_pickup")
	
	# If this is the starting weapon, it should be equipped
	is_equipped = true
	if collision_shape:
		collision_shape.set_deferred("disabled", true)


func _process(delta: float) -> void:
	# --- Always aim the gun toward the mouse regardless of equipped state ---
	look_at(get_global_mouse_position())
	rotation_degrees = wrap(rotation_degrees, 0, 360)

	# Flip gun vertically depending on direction (keeps previous behavior)
	if rotation_degrees > 90 and rotation_degrees < 270:
		scale.y = -1
	else:
		scale.y = 1

	# --- Apply recoil positional offset (local) and recover smoothly ---
	recoil_offset = recoil_offset.move_toward(Vector2.ZERO, recoil_recover_speed * delta)
	position = original_position + recoil_offset

	# Only process shooting logic if equipped
	if not is_equipped:
		return

	# --- Shooting timing ---
	if Input.is_action_pressed("fire") and not is_reloading:
		fire_timer -= delta
		if fire_timer <= 0.0:
			shoot()
			fire_timer = fire_rate
	else:
		fire_timer = max(fire_timer - delta, 0.0)

	# --- Manual reload (only if ammo > 0) ---
	if Input.is_action_just_pressed("reload") and not is_reloading and current_ammo > 0 and current_ammo < magazine_size:
		reload()


func shoot() -> void:
	if is_reloading or not is_equipped:
		print("Cannot shoot: is_reloading=", is_reloading, " is_equipped=", is_equipped)
		return

	if current_ammo <= 0:
		reload()
		return

	current_ammo -= 1

	# 💥 Determine critical hit
	var is_crit = randf() < (crit_chance / 100.0)
	var final_damage = damage * (crit_multiplier if is_crit else 1.0)

	if is_crit:
		print("🔥 REVOLVER CRITICAL HIT! Damage:", final_damage)
	else:
		print("Revolver shots left:", current_ammo, " Damage:", final_damage)

	# Create and fire bullet
	var bullet_instance = Bullet.instantiate()
	get_tree().current_scene.add_child(bullet_instance)
	bullet_instance.global_position = marker_2d.global_position
	bullet_instance.rotation = marker_2d.global_rotation
	bullet_instance.damage = final_damage
	bullet_instance.speed = 1800.0
	
	# Set critical hit visual on the bullet only
	if is_crit and bullet_instance.has_method("set_critical"):
		bullet_instance.set_critical(true)

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

	if current_ammo <= 0:
		reload()


func reload() -> void:
	if is_reloading or not is_equipped:
		print("Cannot reload: is_reloading=", is_reloading, " is_equipped=", is_equipped)
		return

	is_reloading = true
	print("🔄 Reloading revolver...")

	# 🎵 Play reload SFX
	reloading.pitch_scale = randf_range(0.95, 1.05)
	reloading.play()

	await get_tree().create_timer(reload_time).timeout
	current_ammo = magazine_size
	is_reloading = false
	print("✅ Revolver reloaded! Ammo:", current_ammo)


# --- Pickup System ---
func setup_as_pickup():
	"""Setup the weapon as a pickup (not equipped)"""
	is_equipped = false
	visible = true
	
	# Enable pickup area collision
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	# Optional: Add some visual effect for pickup weapons
	modulate = Color(1, 1, 1, 0.8)  # Slightly transparent when on ground
	print("Revolver set as pickup")


func on_picked_up(by_player: Node2D):
	"""Called when player picks up this weapon"""
	if is_equipped:
		return
	
	player = by_player
	is_equipped = true
	is_player_nearby = false
	
	# Disable pickup area collision
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Reset visual effects
	modulate = Color(1, 1, 1, 1)  # Full opacity when equipped
	
	print("🎯 Revolver picked up and equipped:", name)


func on_dropped():
	"""Called when player drops this weapon"""
	is_equipped = false
	player = null
	
	# Enable pickup area collision
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	# Setup as pickup again
	setup_as_pickup()
	
	print("🗑️ Revolver dropped:", name)


# --- Detection functions called by player ---
func on_player_entered_detection():
	"""Called by player when this weapon enters detection range"""
	if not is_equipped and not is_player_nearby:
		is_player_nearby = true
		print("🔍 Revolver detected by player:", name)
		# Optional: Add visual feedback like glow or outline
		modulate = Color(1.2, 1.2, 1.0, 0.9)  # Slightly brighter when detected


func on_player_exited_detection():
	"""Called by player when this weapon exits detection range"""
	if not is_equipped and is_player_nearby:
		is_player_nearby = false
		print("❌ Revolver no longer detected:", name)
		# Reset visual effects
		modulate = Color(1, 1, 1, 0.8)  # Back to normal pickup appearance


# --- Utility functions ---
func get_weapon_data() -> Dictionary:
	"""Return weapon stats for UI display"""
	return {
		"name": name,
		"current_ammo": current_ammo,
		"magazine_size": magazine_size,
		"damage": damage,
		"fire_rate": fire_rate,
		"crit_chance": crit_chance,
		"crit_multiplier": crit_multiplier
	}


func refill_ammo():
	"""Refill ammo to full (can be called from player)"""
	current_ammo = magazine_size
	print("🔋 Revolver ammo refilled:", current_ammo)


# Debug function to check weapon state
func _input(event):
	if event.is_action_pressed("debug"):
		print("Revolver State - Equipped:", is_equipped, " Ammo:", current_ammo, " Reloading:", is_reloading)
