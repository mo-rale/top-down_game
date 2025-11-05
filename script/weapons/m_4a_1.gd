extends BaseWeapon

@onready var anim: AnimatedSprite2D = $Sprite2D

func _ready() -> void:
	# Set weapon-specific properties
	weapon_name = "M4A1"
	fire_rate = 0.05
	damage = 30
	magazine_size = 30
	reload_time = 3.2
	price = 2100
	crit_chance = 25.0
	crit_multiplier = 2.0
	recoil_strength = -8.0
	recoil_recover_speed = 15.0
	
	# Initialize the base class
	super._ready()


	
func on_reload_start() -> void:
	if anim:
		anim.play("reloading")

func on_reload_stop() -> void:
	if anim and anim.animation == "reloading":
		anim.stop()

func on_reload_complete() -> void:
	if anim:
		anim.stop() 
