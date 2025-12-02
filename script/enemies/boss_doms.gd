extends EnemyBase
class_name BossEnemy

# --- Boss Specific Stats ---
@export var rock_attack_damage: int = 20
@export var stomp_attack_damage: int = 30
@export var rock_attack_cooldown: float = 3.0
@export var stomp_attack_cooldown: float = 5.0
@export var rock_scene: PackedScene
@export var stomp_radius: float = 100.0
@export var rock_speed: float = 200.0
@export var attack_range: float = 150.0

# --- Boss Attack Timers ---
var rock_attack_timer: float = 0.0
var stomp_attack_timer: float = 0.0
var is_attacking: bool = false

# --- Boss State ---
enum BossState {
	CHASING,
	ROCK_ATTACK,
	STOMP_ATTACK,
	VULNERABLE
}
var current_boss_state: BossState = BossState.CHASING

# --- Visual Effects ---
@onready var attack_indicator: Sprite2D = $AttackIndicator
@onready var stomp_area: Area2D = $StompArea


func _ready():
	# Call parent _ready first
	super._ready()
	
	# Boss-specific initialization
	health = 500  # Boss has more health
	max_health = 500
	speed = 80    # Boss is slower but more powerful
	enemy_damage = 10  # Boss does more contact damage
	
	# Initialize timers with offsets so attacks don't happen simultaneously
	rock_attack_timer = rock_attack_cooldown * 0.5
	stomp_attack_timer = stomp_attack_cooldown
	
	# Set up stomp area if it exists
	if stomp_area:
		stomp_area.body_entered.connect(_on_stomp_body_entered)
	
	# Set up attack indicator
	if attack_indicator:
		attack_indicator.visible = false


func _physics_process(delta: float):
	# Call parent physics process
	super._physics_process(delta)
	
	if is_dead:
		return
	
	# Update boss state machine
	update_boss_state(delta)
	
	# Handle boss-specific behavior based on state
	match current_boss_state:
		BossState.CHASING:
			handle_chasing_state(delta)
		BossState.ROCK_ATTACK:
			handle_rock_attack_state(delta)
		BossState.STOMP_ATTACK:
			handle_stomp_attack_state(delta)
		BossState.VULNERABLE:
			handle_vulnerable_state(delta)


func update_boss_state(delta: float):
	if is_attacking:
		return
	
	# Update attack timers
	rock_attack_timer -= delta
	stomp_attack_timer -= delta
	
	# Check if player is in range for special attacks
	var player_distance = position.distance_to(player.position) if player else 9999
	
	# State transitions
	if current_boss_state == BossState.CHASING:
		# Check for attack opportunities
		if rock_attack_timer <= 0.0 and player_distance > attack_range:
			start_rock_attack()
		elif stomp_attack_timer <= 0.0 and player_distance <= attack_range:
			start_stomp_attack()
	
	# Return to chasing after vulnerable state
	elif current_boss_state == BossState.VULNERABLE:
		if not is_attacking:
			current_boss_state = BossState.CHASING


func handle_chasing_state(delta: float):
	# Normal movement behavior (handled by parent)
	pass


func handle_rock_attack_state(delta: float):
	# Stop moving during rock attack
	velocity = Vector2.ZERO
	
	# Look at player
	if player:
		var direction_to_player = (player.position - position).normalized()
		sprite.flip_h = direction_to_player.x < 0


func handle_stomp_attack_state(delta: float):
	# Stop moving during stomp attack
	velocity = Vector2.ZERO
	
	# Show attack indicator
	if attack_indicator:
		attack_indicator.visible = true
		attack_indicator.scale = Vector2.ONE * (stomp_radius / 50.0)  # Adjust scale based on radius


func handle_vulnerable_state(delta: float):
	# Boss is vulnerable after attacks - move slower
	velocity *= 0.5


#region Special Attacks
func start_rock_attack():
	if not player or is_attacking:
		return
	
	current_boss_state = BossState.ROCK_ATTACK
	is_attacking = true
	
	# Play rock attack animation
	sprite.play("rock_attack")
	await sprite.animation_finished
	
	# Throw rocks
	throw_rocks()
	
	# Reset timer and state
	rock_attack_timer = rock_attack_cooldown
	is_attacking = false
	current_boss_state = BossState.VULNERABLE


func start_stomp_attack():
	if not player or is_attacking:
		return
	
	current_boss_state = BossState.STOMP_ATTACK
	is_attacking = true
	
	# Play stomp animation
	sprite.play("stomp_attack")
	
	# Wait for the moment in animation to actually stomp
	await get_tree().create_timer(0.5).timeout
	
	# Perform stomp
	perform_stomp()
	
	# Wait for animation to finish
	await sprite.animation_finished
	
	# Reset timer and state
	stomp_attack_timer = stomp_attack_cooldown
	is_attacking = false
	current_boss_state = BossState.VULNERABLE
	
	# Hide attack indicator
	if attack_indicator:
		attack_indicator.visible = false

func throw_rocks():
	if not rock_scene or not player:
		return
	
	# Throw 3 rocks in a spread pattern
	var directions = []
	var player_direction = (player.position - position).normalized()
	
	# Create spread directions
	directions.append(player_direction)
	directions.append(player_direction.rotated(deg_to_rad(30)))
	directions.append(player_direction.rotated(deg_to_rad(-30)))
	
	for direction in directions:
		var rock = rock_scene.instantiate()
		get_parent().add_child(rock)
		rock.position = position
		
		# Set rock properties using the setup method
		if rock.has_method("setup"):
			rock.setup(direction, rock_speed, rock_attack_damage)
		else:
			# Fallback for basic setup
			rock.velocity = direction * rock_speed
			if "damage" in rock:
				rock.damage = rock_attack_damage

func perform_stomp():
	# Create stomp effect
	create_stomp_effect()
	
	# Damage players in stomp radius
	var bodies = stomp_area.get_overlapping_bodies() if stomp_area else []
	for body in bodies:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(stomp_attack_damage)
			
			# Apply knockback
			var knockback_dir = (body.position - position).normalized()
			if "knockback_velocity" in body:
				body.knockback_velocity = knockback_dir * knockback_strength * 1.5


func create_stomp_effect():
	# You can add visual effects here like screen shake, particles, etc.
	
	# Example: Create a simple circle effect
	var effect = CircleShape2D.new()
	effect.radius = stomp_radius
	
	# You could also spawn particles or play a screen shake effect
	print("BOSS STOMP! Radius: ", stomp_radius)


func _on_stomp_body_entered(body: Node2D):
	# This is called when bodies enter the stomp area
	# The actual damage is handled in perform_stomp()
	pass
#endregion

#region Override Parent Methods
func take_damage(damage: int, knockback_dir: Vector2 = Vector2.ZERO):
	# Boss takes reduced damage during attacks
	var damage_multiplier = 1.0
	if is_attacking:
		damage_multiplier = 0.5  # 50% damage reduction during attacks
	
	var actual_damage = int(damage * damage_multiplier)
	super.take_damage(actual_damage, knockback_dir)
	
	# Boss-specific damage reactions
	if health <= max_health * 0.3:  # Below 30% health
		# Enrage mode - attacks faster
		rock_attack_cooldown *= 0.7
		stomp_attack_cooldown *= 0.7


func on_death():
	# Boss-specific death behavior
	print("BOSS DEFEATED!")
	
	# Play boss death animation/sounds
	if dying:
		dying.pitch_scale = 0.8  # Lower pitch for boss death
	
	# Call parent on_death to handle base death behavior
	super.on_death()
	
	# Additional boss death effects could go here
	# Like spawning powerups, triggering events, etc.
#endregion

#region Utility Functions
func get_attack_cooldown_percentage() -> Vector2:
	return Vector2(
		1.0 - (rock_attack_timer / rock_attack_cooldown),
		1.0 - (stomp_attack_timer / stomp_attack_cooldown)
	)


func is_player_in_attack_range() -> bool:
	if not player:
		return false
	return position.distance_to(player.position) <= attack_range
#endregion
