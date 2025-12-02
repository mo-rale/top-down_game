extends BaseWeapon

@onready var anim: AnimatedSprite2D = $Sprite2D

func _ready() -> void:
	# Set weapon-specific properties
	weapon_name = "AK-47"
	fire_rate = 0.16  # ~6.6 shots per second (realistic for assault rifle)
	damage = 50       # Slightly lower damage but higher fire rate
	magazine_size = 30
	reload_time = 3.0  # Faster reload than current 3.2 seconds
	price = 700      # Matches the store price for assault rifles
	crit_chance = 16.0 # Lower crit chance than current 25%
	crit_multiplier = 2.0
	recoil_strength = -10.0  # Less recoil than current -8.0
	recoil_recover_speed = 14.0
	
	# Initialize the base class
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
