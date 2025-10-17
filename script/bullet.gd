extends Node2D
@export var speed: float = 1800.0     # bullet speed
@export var damage = 0       # bullet damage
@export var lifetime: float = 4.0    # seconds before bullet auto-despawns

var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	velocity = transform.x * speed
	
	# Auto delete after a while (avoid infinite bullets in memory)
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()

func _process(delta: float) -> void:
	position += transform.x * speed * delta

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage, velocity)
	queue_free()
