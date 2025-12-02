extends BaseWeapon
@onready var anim: AnimatedSprite2D = $Sprite2D

func _ready() -> void:
	is_equipped = true
	# Set weapon-specific properties
	weapon_name = "Revolver"
	fire_rate = 0.4
	damage = 50
	magazine_size = 8
	reload_time = 3.5
	crit_chance = 60.0
	crit_multiplier = 2.0
	recoil_strength = -30
	recoil_recover_speed = 50
	
	
	# Initialize the base class
	super._ready()
	

func _process(delta: float) -> void:
	super._process(delta)

func on_reload_start() -> void:
	if anim:
		anim.play("reloading")

func on_reload_stop() -> void:
	if anim and anim.animation == "reloading":
		anim.stop()

func on_reload_complete() -> void:
	if anim:
		anim.stop()
