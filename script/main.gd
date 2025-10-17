extends Node2D

@onready var retryBTN: Button = %Button
@onready var player = $player
@onready var game_over_screen = %GameOver


enum GAME_STATES {
	BOSSFIGHT,
	MORNIG,
	NIGHT,
	PAUSED,
	PLAYER_DIED,
}


func _ready() -> void:
	game_over_screen.visible = false
	retryBTN.pressed.connect(_on_retry_pressed)

func _process(_delta: float) -> void:
	if player.health <= 0 and not game_over_screen.visible:
		show_game_over()

	if game_over_screen.visible and Input.is_action_just_pressed("ui_cancel"):
		_on_retry_pressed()
		

func show_game_over() -> void:
	game_over_screen.visible = true
	print("Game Over shown")

func _on_retry_pressed() -> void:
	print("Retry pressed!") # Debug check
	get_tree().reload_current_scene()
