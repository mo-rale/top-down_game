extends EnemyBase
# Heavy Enemy Type
# A heavily armored enemy with high health but slower movement

func _ready():
	speed = 90  #
	health = 450
	max_health = 1200
	enemy_damage = 30  
	damage_interval = 2.0  
	knockback_strength = 15.0  
	armor = 10  
	armor_percentage = 0.3  
	armor_type = "heavy"
	
	min_currency_reward = 100
	max_currency_reward = 150  
	
	# Initialize the base class
	super._ready()
	
	# Heavy enemy specific initialization
	on_spawn()


func on_spawn() -> void:
	# Heavy enemy spawn behavior
	pass


func on_player_detected() -> void:
	# Heavy enemy player detection behavior
	pass


func on_attack() -> void:
	# Heavy enemy attack behavior
	pass
