extends BaseWeapon

@onready var anim: AnimatedSprite2D = $Sprite2D

func _ready() -> void:
	# Set weapon-specific properties
	weapon_name = "M4A1 AR"
	fire_rate = 0.10  # ~6.6 shots per second (realistic for assault rifle)
	damage = 25       # Slightly lower damage but higher fire rate
	magazine_size = 30
	reload_time = 2.5  # Faster reload than current 3.2 seconds
	price = 500       # Matches the store price for assault rifles
	crit_chance = 15.0 # Lower crit chance than current 25%
	crit_multiplier = 2.0
	recoil_strength = -8.0  # Less recoil than current -8.0
	recoil_recover_speed = 12.0
	
	# Initialize the base class
	super._ready()

func on_picked_up(by_player: Node2D) -> void:
	if is_equipped:
		return
	if anim:
		anim.play("idle")
	player = by_player
	is_equipped = true
	is_player_nearby = false
	
	position = Vector2.ZERO
	original_position = Vector2.ZERO
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	modulate = Color(1, 1, 1, 1)
	set_status(WeaponStatus.EQUIPPED)

func on_reload_start() -> void:
	if anim:
		anim.play("reloading")

func on_reload_stop() -> void:
	if anim and anim.animation == "reloading":
		anim.stop()

func on_reload_complete() -> void:
	if anim:
		anim.stop()
