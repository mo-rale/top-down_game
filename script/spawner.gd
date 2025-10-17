extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0   # seconds between spawns
@export var max_enemies: int = 10         # limit how many enemies can exist
@export var spawn_radius: float = 200.0   # distance from spawner position

var timer: Timer

func _ready() -> void:
	# Create a timer for spawning
	timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(_on_spawn_timer_timeout)

func _on_spawn_timer_timeout() -> void:
	# Count how many enemies are currently in the scene
	var current_enemies = get_tree().get_nodes_in_group("enemies").size()
	if current_enemies >= max_enemies:
		return
	
	# Pick a random position around the spawner
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * spawn_radius
	var spawn_pos = position + offset

	# Spawn enemy
	var enemy = enemy_scene.instantiate()
	enemy.position = spawn_pos
	get_parent().add_child(enemy)
	enemy.add_to_group("enemies")
