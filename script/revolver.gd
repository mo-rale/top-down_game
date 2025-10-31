extends Node2D

const Bullet = preload("res://scene/bullet.tscn")

@export var fire_rate: float = 0.4
@export var damage: int = 50
@export var magazine_size: int = 8
@export var reload_time: float = 3.5

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
var is_equipped: bool = true
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

var current_status: WeaponStatus = WeaponStatus.ACTIVE

# --- Reload Interruption System ---
var reload_timer: Timer

func _ready() -> void:
	original_position = position
	add_to_group("weapon_pickup")
	
	# Create reload timer
	reload_timer = Timer.new()
	reload_timer.one_shot = true
	add_child(reload_timer)
	
	is_equipped = true
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	set_status(WeaponStatus.ACTIVE)
func _process(delta: float) -> void:
	if not is_equipped:
		return
	
	# Always aim toward mouse
	look_at(get_global_mouse_position())
	rotation_degrees = wrap(rotation_degrees, 0, 360)

	# Flip gun vertically
	if rotation_degrees > 90 and rotation_degrees < 270:
		scale.y = -1
	else:
		scale.y = 1

	# Apply recoil recovery
	recoil_offset = recoil_offset.move_toward(Vector2.ZERO, recoil_recover_speed * delta)
	position = original_position + recoil_offset

	# Update status based on ammo
	if current_ammo <= 0 and current_status != WeaponStatus.RELOADING:
		set_status(WeaponStatus.EMPTY)
	elif current_ammo > 0 and current_status == WeaponStatus.EMPTY:
		set_status(WeaponStatus.ACTIVE)

	# Shooting timing - Only check reloading
	if Input.is_action_pressed("fire") and not is_reloading:
		fire_timer -= delta
		if fire_timer <= 0.0:
			shoot()
			fire_timer = fire_rate
	else:
		fire_timer = max(fire_timer - delta, 0.0)
		
		if current_status == WeaponStatus.FIRING:
			set_status(WeaponStatus.ACTIVE)

	# Manual reload - Allow reload even when ammo is 0
	if Input.is_action_just_pressed("reload") and not is_reloading and current_ammo < magazine_size:
		reload()

func shoot() -> void:
	if is_reloading or not is_equipped or current_ammo <= 0:
		print("❌ Revolver: Cannot shoot - reloading:", is_reloading, " equipped:", is_equipped, " ammo:", current_ammo)
		return
	set_status(WeaponStatus.FIRING)
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
	
	print("🔄 Reloading revolver...")
	reloading.pitch_scale = randf_range(0.95, 1.05)
	reloading.play()

	reload_timer.start(reload_time)
	await reload_timer.timeout
	
	# Only complete reload if we're still reloading AND equipped
	if is_reloading and is_equipped:
		complete_reload()
	else:
		# If we were interrupted, stop everything
		stop_reload()
func stop_reload() -> void:
	if is_reloading:
		print("⏸️ Revolver: Reload interrupted - must restart")
		
		# Stop timer and reset state
		if reload_timer and reload_timer.time_left > 0:
			reload_timer.stop()
		
		is_reloading = false
		
		# STOP AUDIO
		if reloading and reloading.playing:
			reloading.stop()
		
		set_status(WeaponStatus.ACTIVE)
func complete_reload() -> void:
	current_ammo = magazine_size
	is_reloading = false
	set_status(WeaponStatus.ACTIVE)
	print("✅ Revolver reloaded! Ammo:", current_ammo)


# --- Status Management ---
func set_status(new_status: WeaponStatus):
	if current_status == new_status:
		return
	
	current_status = new_status
	
	match new_status:
		WeaponStatus.DROPPED:
			set_process(false)
			stop_reload()
			
		WeaponStatus.EQUIPPED:
			set_process(false)
			stop_reload()
			
		WeaponStatus.ACTIVE:
			set_process(true)
			# No resume functionality - must restart reload manually
			
		WeaponStatus.FIRING:
			pass
			
		WeaponStatus.RELOADING:
			print("🔄 Revolver: Started reloading")
			
		WeaponStatus.EMPTY:
			pass
			
		WeaponStatus.JAMMED:
			print("⚠️ Revolver: Weapon jammed!")
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
	stop_reload()
	
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	modulate = Color(1, 1, 1, 0.8)
	print("Revolver set as pickup")
func on_picked_up(by_player: Node2D):
	if is_equipped:
		return
	
	player = by_player
	is_equipped = true
	is_player_nearby = false
	
	# Reset position when equipped
	position = Vector2.ZERO
	original_position = Vector2.ZERO
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	modulate = Color(1, 1, 1, 1)
	set_status(WeaponStatus.EQUIPPED)
	print("🎯 Revolver picked up and equipped")
func on_dropped():
	is_equipped = false
	player = null
	stop_reload()
	set_status(WeaponStatus.DROPPED)
	print("🗑️ Revolver dropped")


# --- Detection functions called by player ---
func on_player_entered_detection():
	if not is_equipped and not is_player_nearby:
		is_player_nearby = true
		print("🔍 Revolver detected by player")
		modulate = Color(1.2, 1.2, 1.0, 0.9)
func on_player_exited_detection():
	if not is_equipped and is_player_nearby:
		is_player_nearby = false
		print("❌ Revolver no longer detected")
		modulate = Color(1, 1, 1, 0.8)


# --- Utility functions ---
func get_weapon_data() -> Dictionary:
	return {
		"name": "Revolver",
		"current_ammo": current_ammo,
		"magazine_size": magazine_size,
		"damage": damage,
		"fire_rate": fire_rate,
		"crit_chance": crit_chance,
		"crit_multiplier": crit_multiplier,
		"current_status": get_status_text(),
		"price": 0
	}


func refill_ammo():
	current_ammo = magazine_size
	if current_status == WeaponStatus.EMPTY:
		set_status(WeaponStatus.ACTIVE)
func get_current_status() -> WeaponStatus:
	return current_status
func on_weapon_unequipped():
	"""Called by player when this weapon is being unequipped"""
	print("🔌 Revolver: Weapon unequipped - stopping reload if any")
	stop_reload()
	set_status(WeaponStatus.EQUIPPED)
func set_weapon_active(active: bool):
	if active:
		set_status(WeaponStatus.ACTIVE)
		set_process(true)
	else:
		# When deactivating, stop any ongoing reload
		stop_reload()
		set_status(WeaponStatus.EQUIPPED)
		set_process(false)
