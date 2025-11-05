extends EnemyBase
# Basic Enemy Type
# A standard enemy with balanced stats

func _ready():
	# Set basic enemy stats
	speed = 100
	health = 100
	max_health = 100
	enemy_damage = 5
	damage_interval = 0.5
	knockback_strength = 200.0
	
	min_currency_reward = 10
	max_currency_reward = 25
	
	# Initialize the base class
	super._ready()
	
	# Basic enemy specific initialization
	on_spawn()


func on_spawn() -> void:
	# Basic enemy spawn behavior
	pass


func on_player_detected() -> void:
	# Basic enemy player detection behavior
	pass


func on_attack() -> void:
	# Basic enemy attack behavior
	pass
