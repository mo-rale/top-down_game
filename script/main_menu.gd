extends Node2D

@onready var start: Button = $Control/start
@onready var settings: Button = $Control/settings
@onready var quit: Button = $Control/quit
@onready var fade_rect: ColorRect = $Control/FadeRect

@onready var high_kill: Label = $Control/NinePatchRect/HighKill
@onready var high_time: Label = $Control/NinePatchRect/HighTime
@onready var high_wave: Label = $Control/NinePatchRect/HighWave
@onready var high_money: Label = $Control/NinePatchRect/HighMoney

# Export the scene to load in the Inspector
@export var target_scene: PackedScene

# Fallback scene path if target_scene is not set
const FALLBACK_SCENE_PATH = "res://scene/main.tscn"

func _ready() -> void:
	# Connect button signals
	fade_rect.visible = false
	start.pressed.connect(_on_start_pressed)
	settings.pressed.connect(_on_settings_pressed)
	
	# Connect quit button if it exists
	if quit:
		quit.pressed.connect(_on_quit_pressed)
	
	# Initialize fade effect if it exists
	if fade_rect:
		fade_rect.visible = true
		fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
		await get_tree().create_timer(0.5).timeout
		fade_out()
	
	# Update high score display
	update_high_scores_display()

func update_high_scores_display() -> void:
	# Check if SaveSystem exists and get high scores
	if Engine.has_singleton("SaveSystem"):
		var save_system = Engine.get_singleton("SaveSystem")
		if save_system:
			# Get high scores
			var high_kills = save_system.get_high_kills()
			var high_wave_val = save_system.get_high_wave()
			var high_time_val = save_system.get_high_time()
			var high_money_val = save_system.get_high_money()
			
			# Update labels
			if high_kill:
				high_kill.text = "HIGH KILLS: %d" % high_kills
			
			if high_wave:
				high_wave.text = "HIGH WAVE: %d" % high_wave_val
			
			if high_time:
				high_time.text = "BEST TIME: %s" % format_time(high_time_val)
			
			if high_money:
				high_money.text = "MOST MONEY: $%d" % high_money_val
	else:
		# If SaveSystem doesn't exist yet, show zeros
		print("SaveSystem not found, showing default scores")
		if high_kill:
			high_kill.text = "HIGH KILLS: 0"
		if high_wave:
			high_wave.text = "HIGH WAVE: 0"
		if high_time:
			high_time.text = "BEST TIME: 00:00"
		if high_money:
			high_money.text = "MOST MONEY: $0"

func format_time(seconds: float) -> String:
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]

func _on_start_pressed() -> void:
	print("Start button pressed")
	
	# Play button click sound (optional)
	play_button_sound()
	
	# Disable button to prevent double-clicking
	start.disabled = true
	
	# Optional: Fade out effect
	if fade_rect:
		await fade_in()
	
	# Load and change to target scene (ONLY CALL THIS ONCE!)
	load_target_scene()

func _on_settings_pressed() -> void:
	print("Settings button pressed")
	play_button_sound()
	# Add settings menu logic here

func _on_quit_pressed() -> void:
	print("Quit button pressed")
	play_button_sound()
	get_tree().quit()

func load_target_scene() -> void:
	# Check if tree is still valid
	if not is_inside_tree() or not get_tree():
		print("Warning: Node is being removed, skipping scene change")
		return
	
	# Use exported scene if set, otherwise use fallback
	if target_scene:
		print("Loading exported scene: ", target_scene.resource_path)
		var error = get_tree().change_scene_to_packed(target_scene)
		if error != OK:
			print("Error changing scene: ", error)
			# Fallback
			get_tree().change_scene_to_file(FALLBACK_SCENE_PATH)
	else:
		print("No exported scene set, using fallback: ", FALLBACK_SCENE_PATH)
		get_tree().change_scene_to_file(FALLBACK_SCENE_PATH)

func fade_in() -> void:
	if not fade_rect:
		return
	
	if not is_inside_tree():
		return
	
	fade_rect.visible = true
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
	await tween.finished

func fade_out() -> void:
	if not fade_rect:
		return
	
	if not is_inside_tree():
		return
	
	fade_rect.visible = true
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5)
	await tween.finished
	fade_rect.visible = false

func play_button_sound() -> void:
	var button_sound = $ButtonSound if has_node("ButtonSound") else null
	if button_sound and is_inside_tree():
		button_sound.pitch_scale = randf_range(0.9, 1.1)
		button_sound.play()
