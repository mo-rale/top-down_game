class_name BaseWeapon
extends Node2D

const Bullet = preload("res://scene/bullet.tscn")

# --- Weapon Stats ---
@export var weapon_name: String = "Base Weapon"
@export var fire_rate: float = 0.5
@export var damage: int = 40
@export var magazine_size: int = 10
@export var reload_time: float = 2.0
@export var price: int = 0

# --- Critical Hit System ---
@export var crit_chance: float = 10.0
@export var crit_multiplier: float = 2.0

# --- Recoil Settings ---
@export var recoil_strength: float = -5.0
@export var recoil_recover_speed: float = 10.0

# --- Node References ---
@onready var marker_2d: Marker2D = $Marker2D
@onready var shooting_sound: AudioStreamPlayer2D = $shooting
@onready var reloading_sound: AudioStreamPlayer2D = $reloading
@onready var pickable_area: Area2D = $pickable_area
@onready var collision_shape: CollisionShape2D = $pickable_area/CollisionShape2D

# --- Weapon State ---
var fire_timer: float = 0.0
var current_ammo: int = 0
var is_reloading: bool = false
var is_equipped: bool = false
var is_player_nearby: bool = false
var player: Node2D = null

# --- Recoil System ---
var original_position: Vector2
var recoil_offset: Vector2 = Vector2.ZERO

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
var reload_timer: Timer


func _ready() -> void:
	original_position = position
	add_to_group("weapon_pickup")
	
	reload_timer = Timer.new()
	reload_timer.one_shot = true
	add_child(reload_timer)
	
	current_ammo = magazine_size
	
	if not is_equipped:
		setup_as_pickup()
	else:
		set_status(WeaponStatus.ACTIVE)
func _process(delta: float) -> void:
	if not is_equipped:
		return
	
	
	recoil_offset = recoil_offset.move_toward(Vector2.ZERO, recoil_recover_speed * delta)
	position = original_position + recoil_offset
	
	update_ammo_status()
	
	if Input.is_action_pressed("fire") and not is_reloading:
		fire_timer -= delta
		if fire_timer <= 0.0:
			shoot()
			fire_timer = fire_rate
	else:
		fire_timer = max(fire_timer - delta, 0.0)
		if current_status == WeaponStatus.FIRING:
			set_status(WeaponStatus.ACTIVE)
	
	if Input.is_action_just_pressed("reload") and not is_reloading and current_ammo < magazine_size:
		reload()


#region Core Weapon Functions

func shoot() -> void:
	if is_reloading or not is_equipped or current_ammo <= 0:
		return
	
	set_status(WeaponStatus.FIRING)
	current_ammo -= 1
	
	var is_crit = randf() < (crit_chance / 100.0)
	var final_damage = damage * (crit_multiplier if is_crit else 1.0)
	
	create_bullet(final_damage, is_crit)
	apply_recoil()
	play_shoot_sound(is_crit)
	
	if current_ammo <= 0:
		set_status(WeaponStatus.EMPTY)
		reload()
func create_bullet(bullet_damage: int, is_critical: bool) -> void:
	var bullet_instance = Bullet.instantiate()
	get_tree().current_scene.add_child(bullet_instance)
	bullet_instance.global_position = marker_2d.global_position
	bullet_instance.rotation = marker_2d.global_rotation
	bullet_instance.damage = bullet_damage
	bullet_instance.speed = 1800.0
	
	if is_critical and bullet_instance.has_method("set_critical"):
		bullet_instance.set_critical(true)
func apply_recoil() -> void:
	var strength = abs(recoil_strength)
	if global_scale.x > 0:
		recoil_offset = Vector2(-strength, 0)
	else:
		recoil_offset = Vector2(strength, 0)
func play_shoot_sound(is_critical: bool) -> void:
	if shooting_sound:
		if is_critical:
			shooting_sound.pitch_scale = randf_range(1.1, 1.3)
		else:
			shooting_sound.pitch_scale = randf_range(0.9, 1.1)
		shooting_sound.play()
#endregion

#region Reload System
func reload() -> void:
	if is_reloading or not is_equipped or current_ammo == magazine_size:
		return
	
	stop_reload()
	
	set_status(WeaponStatus.RELOADING)
	is_reloading = true
	
	if reloading_sound:
		reloading_sound.pitch_scale = randf_range(0.95, 1.05)
		reloading_sound.play()
	
	on_reload_start()
	
	reload_timer.start(reload_time)
	await reload_timer.timeout
	
	if is_reloading and is_equipped:
		complete_reload()
	else:
		stop_reload()
func stop_reload() -> void:
	if is_reloading:
		if reload_timer and reload_timer.time_left > 0:
			reload_timer.stop()
		
		is_reloading = false
		
		if reloading_sound and reloading_sound.playing:
			reloading_sound.stop()
		
		on_reload_stop()
		set_status(WeaponStatus.ACTIVE)
func complete_reload() -> void:
	current_ammo = magazine_size
	is_reloading = false
	on_reload_complete()
	set_status(WeaponStatus.ACTIVE)
#endregion

#region Status Management
func set_status(new_status: WeaponStatus) -> void:
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
		WeaponStatus.FIRING:
			pass
		WeaponStatus.RELOADING:
			pass
		WeaponStatus.EMPTY:
			pass
		WeaponStatus.JAMMED:
			pass
func update_ammo_status() -> void:
	if current_ammo <= 0 and current_status != WeaponStatus.RELOADING:
		set_status(WeaponStatus.EMPTY)
	elif current_ammo > 0 and current_status == WeaponStatus.EMPTY:
		set_status(WeaponStatus.ACTIVE)
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
#endregion

#region Pickup System
func setup_as_pickup() -> void:
	is_equipped = false
	visible = true
	set_status(WeaponStatus.DROPPED)
	stop_reload()
	
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	modulate = Color(1, 1, 1, 0.8)
func on_picked_up(by_player: Node2D) -> void:
	if is_equipped:
		return
	
	player = by_player
	is_equipped = true
	is_player_nearby = false
	
	position = Vector2.ZERO
	original_position = Vector2.ZERO
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	modulate = Color(1, 1, 1, 1)
	set_status(WeaponStatus.EQUIPPED)
func on_dropped() -> void:
	is_equipped = false
	player = null
	stop_reload()
	set_status(WeaponStatus.DROPPED)
func on_player_entered_detection() -> void:
	if not is_equipped and not is_player_nearby:
		is_player_nearby = true
		modulate = Color(1.2, 1.2, 1.0, 0.9)
func on_player_exited_detection() -> void:
	if not is_equipped and is_player_nearby:
		is_player_nearby = false
		modulate = Color(1, 1, 1, 0.8)
#endregion

#region Utility Functions
func get_weapon_data() -> Dictionary:
	return {
		"name": weapon_name,
		"current_ammo": current_ammo,
		"magazine_size": magazine_size,
		"damage": damage,
		"fire_rate": fire_rate,
		"crit_chance": crit_chance,
		"crit_multiplier": crit_multiplier,
		"current_status": get_status_text(),
		"price": price
	}
func refill_ammo() -> void:
	current_ammo = magazine_size
	if current_status == WeaponStatus.EMPTY:
		set_status(WeaponStatus.ACTIVE)
func get_price() -> int:
	return price
func get_current_status() -> WeaponStatus:
	return current_status
func on_weapon_unequipped() -> void:
	stop_reload()
	set_status(WeaponStatus.EQUIPPED)
func set_weapon_active(active: bool) -> void:
	if active:
		set_status(WeaponStatus.ACTIVE)
		set_process(true)
	else:
		stop_reload()
		set_status(WeaponStatus.EQUIPPED)
		set_process(false)
func clear_jam() -> void:
	if current_status == WeaponStatus.JAMMED:
		set_status(WeaponStatus.ACTIVE)
#endregion

#region Hooks (Override in Child Classes)
func on_reload_start() -> void:
	pass
func on_reload_stop() -> void:
	pass
func on_reload_complete() -> void:
	pass
#endregion
