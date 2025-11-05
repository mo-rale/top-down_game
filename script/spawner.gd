extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var max_enemies: int = 10
@export var spawn_radius: float = 200.0

@onready var timer: Timer = $Timer

var is_active: bool = false
var current_wave: int = 1

func _ready() -> void:
	add_to_group("spawners")
	
	timer.wait_time = spawn_interval
	timer.autostart = false
	timer.one_shot = false
	timer.timeout.connect(_on_spawn_timer_timeout)
	
	set_active(false)

func set_active(active: bool) -> void:
	is_active = active
	if active:
		timer.start()
	else:
		timer.stop()

func set_spawning_active(active: bool) -> void:
	set_active(active)

func increase_difficulty(wave: int) -> void:
	current_wave = wave
	spawn_interval = max(0.5, spawn_interval * 0.95)
	max_enemies += 1
	
	if timer and timer.time_left > 0:
		timer.wait_time = spawn_interval

func _on_spawn_timer_timeout() -> void:
	if !is_active:
		return
	
	var current_enemies = get_tree().get_nodes_in_group("enemies").size()
	if current_enemies >= max_enemies:
		return
	
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * spawn_radius
	var spawn_pos = global_position + offset

	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	get_parent().add_child(enemy)
	enemy.add_to_group("enemies")
