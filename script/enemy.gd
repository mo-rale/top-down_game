extends Area2D

var speed: float = 100
var health: int = 100
var max_health: int = 100
var enemy_damage: int = 5   # per tick of damage
var damage_interval: float = 0.5 # seconds between damage ticks

@export var knockback_strength: float = 200.0
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_friction: float = 8.0

@onready var healthbar: ProgressBar = $ProgressBar
@onready var sprite_holder: Node2D = $SpriteHolder
@onready var player: Node2D = get_parent().get_node("player")

# --- New variables ---
var player_in_area: Node2D = null
var damage_timer: float = 0.0

func take_damage(damage: int, _knockback_dir: Vector2 = Vector2.ZERO) -> void:
	health -= damage
	health = clamp(health, 0, max_health)
	healthbar.value = health
	print("Enemy Health:", health)

	if player:
		var move_dir = (player.position - position).normalized()
		knockback_velocity = -move_dir * knockback_strength

	if health <= 0:
		queue_free()

func _process(delta: float) -> void:
	var move_dir := Vector2.ZERO
	healthbar.value = health
	
	# Basic chasing behavior
	if player and health > 0:
		move_dir = (player.position - position).normalized()
		if position.distance_to(player.position) > 3:
			position += move_dir * speed * delta

	# Knockback effect
	if knockback_velocity.length() > 1:
		position += knockback_velocity * delta
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction)
	
	# Flip sprite holder horizontally (only sprite, not health bar)
	if move_dir.x != 0:
		sprite_holder.scale.x = -1 if move_dir.x < 0 else 1

	# --- Continuous damage logic ---
	if player_in_area:
		damage_timer -= delta
		if damage_timer <= 0.0:
			player_in_area.take_damage(enemy_damage)
			damage_timer = damage_interval

func _on_body_entered(body: Node2D) -> void:
	if body and body.is_in_group("player"):
		player_in_area = body
		damage_timer = 0.0  # damage immediately on contact

func _on_body_exited(body: Node2D) -> void:
	if body == player_in_area:
		player_in_area = null
