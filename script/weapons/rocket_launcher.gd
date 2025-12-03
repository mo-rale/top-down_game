extends BaseWeapon
const Rocket = preload("res://scene/rock_proj.tscn")  # Load your rocket scene

@onready var launch_flash: CPUParticles2D = $LaunchFlash
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	weapon_name = "Rocket Launcher"
	fire_rate = 1.5
	damage = 120
	magazine_size = 4
	reload_time = 3.5
	price = 2500
	crit_chance = 10.0
	crit_multiplier = 3.0
	recoil_strength = -25.0
	recoil_recover_speed = 12
	
	# Rocket-specific projectile settings
	projectile_scene = Rocket  # Use rockets instead of bullets
	projectile_speed = 600.0   # Slower than bullets
	projectile_gravity = 0.0   # NO GRAVITY - rockets fly straight
	
	super._ready()
	
	# Hide launch flash initially
	if launch_flash:
		launch_flash.emitting = false

func _process(delta: float) -> void:
	super._process(delta)

# Optional: Override shoot for rocket-specific effects
func shoot() -> void:
	if is_reloading or not is_equipped or current_ammo <= 0:
		return
	
	set_status(WeaponStatus.FIRING)
	current_ammo -= 1
	
	var is_crit = randf() < (crit_chance / 100.0)
	var final_damage = damage * (crit_multiplier if is_crit else 1.0)
	
	# Use parent's create_projectile
	super.create_projectile(final_damage, is_crit)
	
	# Rocket-specific effects
	apply_rocket_recoil()
	play_rocket_sound(is_crit)
	show_muzzle_flash()
	
	if current_ammo <= 0:
		set_status(WeaponStatus.EMPTY)
		# Rocket launcher could auto-reload
		reload()

func apply_rocket_recoil() -> void:
	var strength = abs(recoil_strength)
	# Rocket launcher has stronger vertical recoil
	if global_scale.x > 0:
		recoil_offset = Vector2(-strength, randf_range(-strength * 0.3, -strength * 0.1))
	else:
		recoil_offset = Vector2(strength, randf_range(-strength * 0.3, -strength * 0.1))

func play_rocket_sound(is_critical: bool) -> void:
	if shooting_sound:
		# Lower pitch for heavy weapon sound
		if is_critical:
			shooting_sound.pitch_scale = randf_range(0.8, 0.9)
		else:
			shooting_sound.pitch_scale = randf_range(0.7, 0.8)
		shooting_sound.play()

func show_muzzle_flash() -> void:
	if launch_flash:
		launch_flash.emitting = true
		await get_tree().create_timer(0.1).timeout
		launch_flash.emitting = false

# Optional: Add screen shake for rocket launch
func trigger_screen_shake() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(1.5, 0.3)
