class_name EnemyBase
extends CharacterBody2D

# --- Enemy Stats ---
@export var speed: float = 100
@export var health: int = 100
@export var max_health: int = 100
@export var enemy_damage: int = 5
@export var damage_interval: float = 0.5
@export var knockback_strength: float = 200.0

# --- Currency System ---
@export var min_currency_reward: int = 10
@export var max_currency_reward: int = 25

# --- Node References ---
@onready var healthbar: ProgressBar = $ProgressBar
@onready var sprite: Node2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D

# --- Enemy State ---
var player: Node2D = null
var player_in_area: Node2D = null
var damage_timer: float = 0.0
var currency_reward: int = 0
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_friction: float = 8.0


func _ready():
	add_to_group("enemies")
	
	currency_reward = randi_range(min_currency_reward, max_currency_reward)
	player = get_tree().get_first_node_in_group("player")
	
	if not area_2d.body_entered.is_connected(_on_body_entered):
		area_2d.body_entered.connect(_on_body_entered)
	if not area_2d.body_exited.is_connected(_on_body_exited):
		area_2d.body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	healthbar.value = health
	
	if not player:
		player = get_tree().get_first_node_in_group("player")
		return
	
	handle_movement()
	handle_knockback()
	handle_continuous_damage(delta)
	
	move_and_slide()


#region Core Enemy Functions
func handle_movement() -> void:
	if player and health > 0:
		var move_dir = (player.position - position).normalized()
		
		if position.distance_to(player.position) > 3:
			velocity = move_dir * speed
		else:
			velocity = Vector2.ZERO
		
		if move_dir.x != 0:
			sprite.flip_h = move_dir.x < 0


func handle_knockback() -> void:
	if knockback_velocity.length() > 1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction)


func handle_continuous_damage(delta: float) -> void:
	if player_in_area:
		damage_timer -= delta
		if damage_timer <= 0.0:
			if player_in_area and player_in_area.has_method("take_damage"):
				player_in_area.take_damage(enemy_damage)
			damage_timer = damage_interval
#endregion


#region Combat System
func take_damage(damage: int, _knockback_dir: Vector2 = Vector2.ZERO) -> void:
	health -= damage
	health = clamp(health, 0, max_health)
	healthbar.value = health

	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if player:
		var move_dir = (player.position - position).normalized()
		knockback_velocity = -move_dir * knockback_strength
	
	if health <= 0:
		reward_currency()
		on_death()


func on_death() -> void:
	queue_free()
#endregion


#region Currency System
func reward_currency() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("enemy_killed_reward"):
		game_manager.enemy_killed_reward(currency_reward)
	elif game_manager and game_manager.has_method("add_currency"):
		game_manager.add_currency(currency_reward)
	else:
		var nodes = get_tree().get_nodes_in_group("currency_manager")
		if nodes.size() > 0:
			var currency_manager = nodes[0]
			if currency_manager.has_method("enemy_killed_reward"):
				currency_manager.enemy_killed_reward(currency_reward)
			elif currency_manager.has_method("add_currency"):
				currency_manager.add_currency(currency_reward)
#endregion


#region Area Detection
func _on_body_entered(body: Node2D) -> void:
	if body and body.is_in_group("player"):
		player_in_area = body
		damage_timer = 0.0


func _on_body_exited(body: Node2D) -> void:
	if body == player_in_area:
		player_in_area = null
#endregion


#region Hooks (Override in Child Classes)
# Override these functions in child enemy classes for custom behavior
func on_spawn() -> void:
	pass


func on_player_detected() -> void:
	pass


func on_attack() -> void:
	pass
#endregion
