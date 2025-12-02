extends EnemyBase
# Basic Enemy Type
# A standard enemy with balanced stats


func _ready():
	# Set basic enemy stats
	speed = 200
	health = 90
	max_health = 600
	enemy_damage = 5
	damage_interval = 1
	knockback_strength = 200.0
	
	min_currency_reward = 25
	max_currency_reward = 40
	
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
