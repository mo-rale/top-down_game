extends EnemyBase

func _ready():
	# Set basic enemy stats
	speed = 100
	health = 100
	max_health = 150
	enemy_damage = 5
	damage_interval = 0.5
	knockback_strength = 200.0
	
	min_currency_reward = 40
	max_currency_reward = 60
	
	# Initialize the base class
	super._ready()
	
	# Basic enemy specific initialization
	on_spawn()
