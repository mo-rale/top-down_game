extends Node2D

@onready var label: Label = $Label
@onready var timer: Timer = $AutoRemoveTimer

var velocity: Vector2 = Vector2(0, -50)  # Rise upward
var gravity: float = 30

func _ready():
	timer.timeout.connect(queue_free)
	
	# Animate the damage text
	var tween = create_tween()
	
	# Rise and fade
	tween.tween_property(self, "position", position + Vector2(0, -40), 0.8)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.8)
	
	# Optional: Scale effect
	label.scale = Vector2(0.8, 0.8)
	tween.parallel().tween_property(label, "scale", Vector2(1.0, 1.0), 0.3)
	tween.tween_property(label, "scale", Vector2(0.9, 0.9), 0.5)

func set_damage(damage: int):
	label.text = str(damage)

func set_color(color: Color):
	label.modulate = color

func set_critical(is_critical: bool):
	if is_critical:
		# Add "!" or make text larger for crits
		label.text = label.text + "!"
		label.scale = Vector2(1.2, 1.2)
