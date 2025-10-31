extends Node2D

const Bullet = preload("res://scene/bullet.tscn")

@export var fire_rate: float = 0.1
@export var damage: int = 30
@export var magazine_size: int = 30
@export var reload_time: float = 3.2

# 💥 Critical hit system
@export var crit_chance: float = 25.0
@export var crit_multiplier: float = 2.0

# --- Store Price ---
@export var price: int = 2100

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

# --- Weapon Status System ---
enum WeaponStatus {
	DROPPED,
	EQUIPPED,
	ACTIVE,
	FIRING,
	RELOADING,
	EMPTY,
	JAMMED
}

var current_status: WeaponStatus = WeaponStatus.DROPPED

# --- Reload Interruption System ---
var reload_timer: Timer


func _ready():
	original_position = position
	add_to_group("weapon_pickup")
	
	# Create reload timer
	reload_timer = Timer.new()
	reload_timer.one_shot = true
	add_child(reload_timer)
	
	if not is_equipped:
		setup_as_pickup()
	else:
		set_status(WeaponStatus.ACTIVE)
func _process(delta: float) -> void:
	if not is_equipped:
		return
	
	# Update status based on ammo
	if current_ammo <= 0 and current_status != WeaponStatus.RELOADING:
		set_status(WeaponStatus.EMPTY)
	elif current_ammo > 0 and current_status == WeaponStatus.EMPTY:
		set_status(WeaponStatus.ACTIVE)
	
	# Apply recoil recovery
	recoil_offset = recoil_offset.move_toward(Vector2.ZERO, recoil_recover_speed * delta)
	position = original_position + recoil_offset
	
	# Handle reload input
	if Input.is_action_just_pressed("reload") and not is_reloading and current_ammo < magazine_size:
		reload()
	
	# Shooting logic
	if Input.is_action_pressed("fire") and not is_reloading and current_status != WeaponStatus.EMPTY:
		fire_timer -= delta
		if fire_timer <= 0.0:
			shoot()
			fire_timer = fire_rate
	else:
		fire_timer = max(fire_timer - delta, 0.0)
		
		# Return to active status after firing
		if current_status == WeaponStatus.FIRING:
			set_status(WeaponStatus.ACTIVE)
func shoot() -> void:
	if is_reloading or not is_equipped or current_ammo <= 0:
		return

	set_status(WeaponStatus.FIRING)
	current_ammo -= 1

	# 💥 Determine critical hit
	var is_crit = randf() < (crit_chance / 100.0)
	var final_damage = damage * (crit_multiplier if is_crit else 1.0)
	
	# Create and fire bullet
	var bullet_instance = Bullet.instantiate()
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(bullet_instance)
		bullet_instance.global_position = marker_2d.global_position
		bullet_instance.rotation = marker_2d.global_rotation
		bullet_instance.damage = final_damage
		bullet_instance.speed = 1800.0
		
		if is_crit and bullet_instance.has_method("set_critical"):
			bullet_instance.set_critical(true)

	# Recoil
	var strength = abs(recoil_strength)
	if global_scale.x > 0:
		recoil_offset = Vector2(-strength, 0)
	else:
		recoil_offset = Vector2(strength, 0)

	# Play shot sound
	if shooting:
		if is_crit:
			shooting.pitch_scale = randf_range(1.1, 1.3)
		else:
			shooting.pitch_scale = randf_range(0.9, 1.1)
		shooting.play()

	# Auto-reload when empty
	if current_ammo <= 0:
		set_status(WeaponStatus.EMPTY)
		reload()


func reload() -> void:
	if is_reloading or not is_equipped or current_ammo == magazine_size:
		return
	
	# Stop any existing reload
	stop_reload()
	
	set_status(WeaponStatus.RELOADING)
	is_reloading = true
	
	reloading.play()
	anim.play("reloading")
	
	# Start reload timer
	reload_timer.start(reload_time)
	await reload_timer.timeout
	
	# Only complete reload if we're still reloading (not interrupted)
	if is_reloading and is_equipped:
		complete_reload()
	else:
		# If we were interrupted, stop everything
		stop_reload()
func stop_reload() -> void:
	if is_reloading:
		print("⏸️ M4A1: Reload interrupted - must restart")
		
		# Stop timer and reset state
		if reload_timer and reload_timer.time_left > 0:
			reload_timer.stop()
		
		is_reloading = false
		
		# STOP AUDIO - IMPORTANT!
		if reloading and reloading.playing:
			reloading.stop()
		
		# Stop animation
		if anim and anim.animation == "reloading":
			anim.stop()
		
		set_status(WeaponStatus.ACTIVE)
func complete_reload() -> void:
	current_ammo = magazine_size
	is_reloading = false
	set_status(WeaponStatus.ACTIVE)
	print("✅ M4A1: Reload complete")


# --- Status Management ---
func set_status(new_status: WeaponStatus):
	if current_status == new_status:
		return
	
	current_status = new_status
	
	match new_status:
		WeaponStatus.DROPPED:
			set_process(false)
			stop_reload()  # Force stop reload when dropped
			
		WeaponStatus.EQUIPPED:
			set_process(false)
			stop_reload()  # Force stop reload when unequipped
			
		WeaponStatus.ACTIVE:
			set_process(true)
			# No resume functionality - must restart reload manually
			
		WeaponStatus.FIRING:
			pass
			
		WeaponStatus.RELOADING:
			pass
			
		WeaponStatus.EMPTY:
			pass
			
		WeaponStatus.JAMMED:
			print("⚠️ M4A1: Weapon jammed!")
func get_status_text() -> String:
	match current_status:
		WeaponStatus.DROPPED: return "DROPPED"
		WeaponStatus.EQUIPPED: return "EQUIPPED"
		WeaponStatus.ACTIVE: return "ACTIVE"
		WeaponStatus.FIRING: return "FIRING"
		WeaponStatus.RELOADING: return "RELOADING"
		WeaponStatus.EMPTY: return "EMPTY"
		WeaponStatus.JAMMED: return "JAMMED"
		_: return "UNKNOWN"


# --- Pickup System ---
func setup_as_pickup():
	is_equipped = false
	visible = true
	set_status(WeaponStatus.DROPPED)
	stop_reload()  # Ensure no reload is happening
	
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	modulate = Color(1, 1, 1, 0.8)
func on_picked_up(by_player: Node2D):
	if is_equipped:
		return
	
	player = by_player
	is_equipped = true
	is_player_nearby = false
	
	position = Vector2.ZERO  # Reset to center of hand
	original_position = Vector2.ZERO
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	modulate = Color(1, 1, 1, 1)
	set_status(WeaponStatus.EQUIPPED)
func on_dropped():
	is_equipped = false
	player = null
	stop_reload()  # Force stop reload when dropped
	set_status(WeaponStatus.DROPPED)


func on_player_entered_detection():
	if not is_equipped and not is_player_nearby:
		is_player_nearby = true
		modulate = Color(1.2, 1.2, 1.0, 0.9)
func on_player_exited_detection():
	if not is_equipped and is_player_nearby:
		is_player_nearby = false
		modulate = Color(1, 1, 1, 0.8)


# Getter for equipped status
func get_is_equipped() -> bool:
	return is_equipped


func set_weapon_active(active: bool):
	if active:
		set_status(WeaponStatus.ACTIVE)
		set_process(true)
	else:
		# When deactivating, stop any ongoing reload
		stop_reload()
		set_status(WeaponStatus.EQUIPPED)
		set_process(false)


# Get weapon stats for UI display
func get_weapon_stats() -> Dictionary:
	return {
		"name": "M4A1",
		"damage": damage,
		"current_status": get_status_text(),
		"crit_chance": crit_chance,
		"crit_multiplier": crit_multiplier,
		"fire_rate": fire_rate,
		"magazine_size": magazine_size,
		"current_ammo": current_ammo,
		"price": price
	}


func get_price() -> int:
	return price


func get_current_status() -> WeaponStatus:
	return current_status


func clear_jam():
	if current_status == WeaponStatus.JAMMED:
		set_status(WeaponStatus.ACTIVE)
		print("✅ M4A1: Jam cleared")
