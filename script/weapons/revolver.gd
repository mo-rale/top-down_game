extends BaseWeapon

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
	recoil_strength = -10
	recoil_recover_speed = 12
	
	
	# Initialize the base class
	super._ready()
	
	

func _process(delta: float) -> void:
	super._process(delta)
