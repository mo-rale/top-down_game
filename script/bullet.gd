extends Node2D
@export var speed: float = 1800.0     # bullet speed
@export var damage = 0       # bullet damage
@export var lifetime: float = 4.0    # seconds before bullet auto-despawns

var velocity: Vector2 = Vector2.ZERO
var is_critical: bool = false

@onready var sprite: Sprite2D = $Sprite2D  # Reference to your bullet sprite

func _ready() -> void:
	velocity = transform.x * speed
	
	# Auto delete after a while (avoid infinite bullets in memory)
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()

func _process(delta: float) -> void:
	position += transform.x * speed * delta

# Call this function to set critical hit visual
func set_critical(critical: bool) -> void:
	is_critical = critical
	if is_critical and sprite:
		# Change to red color for critical hits
		sprite.modulate = Color(1.868, 0.001, 1.511, 1.0)  # Bright red
		# Optional: Add a glow effect or scale for critical hits
		sprite.scale = Vector2(0.379, 0.5)  # Slightly larger for crits
	else:
		# Reset to normal color
		if sprite:
			sprite.modulate = Color(1, 1, 1)
			sprite.scale = Vector2(1, 1)



func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, velocity)
		queue_free()


func _on_area_2d_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	print("naigo sa aread")
	if parent.has_method("take_damage"):
		parent.take_damage(damage, velocity)
		queue_free()
