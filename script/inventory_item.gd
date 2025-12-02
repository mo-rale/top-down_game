@tool
extends Node2D

@export var item_type = ""
@export var item_name = "new("
@export var item_texture = Texture 
@export var item_effect = ""
var scene_path: String = "res://scene/inventory_item.tscn"

var is_player_in_range = false

@onready var color_rect: ColorRect = $ColorRect
@onready var icon_sprite = $Sprite2D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	color_rect.visible = false
	if not Engine.is_editor_hint():
			icon_sprite.texture = item_texture


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:

	if Engine.is_editor_hint():
		icon_sprite.texture = item_texture
	if is_player_in_range and Input.is_action_just_pressed("interact"):
		pick_item()
func pick_item():
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	var item = {
		"quantity": 1,
		"type": item_type,
		"name": item_name,
		"effect": item_effect,
		"texture": item_texture,
		"scene_path": scene_path
	}
	if game_manager:
		game_manager.add_item(item)
		self.queue_free()

func _on_area_2d_body_entered(body: Node2D) -> void:
	var player = body
	if player.is_in_group("player"):
		color_rect.visible = true
		is_player_in_range = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	var player = body
	if player.is_in_group("player"):
		color_rect.visible = false
		is_player_in_range = false
