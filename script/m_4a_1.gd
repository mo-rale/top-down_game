extends Node2D

const Bullet = preload("res://scene/bullet.tscn")

@export var fire_rate: float = 0.1
@export var damage: int = 20
@export var magazine_size: int = 30
@export var reload_time: float = 3.2
@export var crit_chance: float = 60.0
@export var crit_multiplier: float = 2.0

# --- Recoil Settings ---
@export var recoil_strength: float = 8.0          # how far the gun kicks
@export var recoil_return_speed: float = 15.0      # how fast it returns to normal

@onready var anim: AnimatedSprite2D = $Sprite2D
@onready var marker_2d: Marker2D = $Marker2D
@onready var reloading: AudioStreamPlayer2D = $reloading
@onready var shooting: AudioStreamPlayer2D = $shooting

var fire_timer: float = 0.0
var current_ammo: int = magazine_size
var is_reloading: bool = false

var original_position: Vector2
var recoil_offset: Vector2 = Vector2.ZERO


func _ready():
	original_position = position


func _process(delta: float) -> void:
	# --- Shooting logic ---
	if Input.is_action_pressed("fire") and not is_reloading:
		fire_timer -= delta
		if fire_timer <= 0.0:
			shoot()
			fire_timer = fire_rate
	else:
		fire_timer = max(fire_timer - delta, 0.0)

	if Input.is_action_just_pressed("reload") and not is_reloading and current_ammo > 0 and current_ammo < magazine_size:
		reload()

	# --- Smooth recoil recovery ---
	recoil_offset = recoil_offset.move_toward(Vector2.ZERO, recoil_return_speed * delta)
	position = original_position + recoil_offset


func shoot() -> void:
	if is_reloading:
		return

	if current_ammo <= 0:
		reload()
		return

	current_ammo -= 1

	var is_crit = randf() < (crit_chance / 100.0)
	var final_damage = damage * (crit_multiplier if is_crit else 1.0)

	if is_crit:
		print("🔥 CRITICAL HIT! Damage:", final_damage)
	else:
		print("Shots left:", current_ammo, "Damage:", final_damage)

	# --- Spawn bullet ---
	var bullet_instance = Bullet.instantiate()
	get_tree().current_scene.add_child(bullet_instance)
	bullet_instance.global_position = marker_2d.global_position
	bullet_instance.rotation = marker_2d.global_rotation
	bullet_instance.damage = final_damage
	bullet_instance.speed = 1800.0

	# --- Horizontal recoil ---
	# If scale.x > 0 → facing right → recoil goes left (negative X)
	# If scale.x < 0 → facing left → recoil goes right (positive X)
	if global_scale.x > 0:
		recoil_offset = Vector2(-recoil_strength, 0)
	else:
		recoil_offset = Vector2(recoil_strength, 0)

	# --- Play shooting SFX ---
	shooting.pitch_scale = randf_range(0.9, 1.1)
	shooting.play()

	if current_ammo <= 0:
		reload()


func reload() -> void:
	if is_reloading:
		return

	is_reloading = true
	anim.play("reloading")
	print("🔄 Reloading...")

	reloading.pitch_scale = randf_range(0.95, 1.05)
	reloading.play()

	await get_tree().create_timer(reload_time).timeout
	current_ammo = magazine_size
	is_reloading = false
	print("✅ Reloaded! Ammo back to:", current_ammo)
