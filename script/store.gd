extends StaticBody2D

# --- Store Settings ---
@export var store_name: String = "Gun Store"
@export var sell_multiplier: float = 0.7

# All available guns in one array
var available_guns: Array[Dictionary] = [
	{
		"name": "M4A1 AR", 
		"price": 500, 
		"damage": 25, 
		"fire_rate": 0.20, 
		"scene_path": "res://scene/weapons/m_4a_1.tscn",
		"icon_path": "res://assets/weapons/M4A1/M4A1-icon.png"  # Add this
	},
	{
		"name": "AK-47", 
		"price": 620, 
		"damage": 30, 
		"fire_rate": 0.15, 
		"scene_path": "res://scene/weapons/ak_47.tscn",
		"icon_path": "res://assets/weapons/AK-47/ak_47.png"  # Add this
	},
	{
		"name": "Revolver", 
		"price": 300, 
		"damage": 50, 
		"fire_rate": 0.8, 
		"scene_path": "res://scene/weapons/revolver.tscn",
		"icon_path": "res://assets/weapons/Revolver/revolver-icon.png"  # Add this
	}
]

# Node References
@onready var highlight_area: Area2D = $buying_area
@onready var collision_shape: CollisionShape2D = $buying_area/CollisionShape2D
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var opening: AudioStreamPlayer2D = $opening
@onready var closing: AudioStreamPlayer2D = $closing
@onready var light_1: PointLight2D = $light1
@onready var light_2: PointLight2D = $light2

# State Variables
var is_player_nearby: bool = false
var player: CharacterBody2D = null
var selected_gun_data: Dictionary = {}
var selected_weapon_index: int = -1


func _ready() -> void:
	add_to_group("store")
	highlight_area.connect("body_entered", Callable(self, "_on_highlight_area_body_entered"))
	highlight_area.connect("body_exited", Callable(self, "_on_highlight_area_body_exited"))

func _process(_delta: float) -> void:
	update_store_availability()

#region Store Availability
func update_store_availability() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("is_store_available"):
		var is_store_available = game_manager.is_store_available()
		
		if collision_shape:
			collision_shape.disabled = !is_store_available
		
		if sprite:
			if is_store_available:
				light_1.enabled = true
				light_2.enabled = true
				sprite.modulate = Color(1, 1, 1)
			else:
				sprite.modulate = Color(0.5, 0.5, 0.5)
				light_1.enabled = false
				light_2.enabled = false
		if not is_store_available and is_player_nearby:
			close_shop()
			light_1.enabled = false
			light_2.enabled = false
			show_store_notification("Store closed - Wave incoming!", false)

func is_store_open() -> bool:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("is_store_available"):
		return game_manager.is_store_available()
	return false

func show_store_notification(message: String, _is_success: bool) -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("show_notification"):
		game_manager.show_notification(message, 3.0)
#endregion

#region Public Functions
func open_shop() -> void:
	if not player or not is_store_open():
		return
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("open_store_ui"):
		game_manager.open_store_ui(self)
		populate_store_ui()

func close_shop() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("close_store_ui"):
		game_manager.close_store_ui()

func highlight_store(should_highlight: bool) -> void:
	if not sprite or not is_store_open():
		return
	
	var existing_tweens = get_tree().get_processed_tweens()
	for tween in existing_tweens:
		if tween.is_valid() and tween.get_object() == sprite:
			tween.kill()
	
	if should_highlight:
		sprite.modulate = Color(1.3, 1.3, 1.0)
	else:
		sprite.modulate = Color(1, 1, 1)
#endregion

#region Signal Handlers
func _on_highlight_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and is_store_open():
		is_player_nearby = true
		player = body
		
		if player.has_signal("weapons_updated"):
			player.weapons_updated.connect(_on_player_weapons_updated)
		
		highlight_store(true)
		open_shop()
	elif body.is_in_group("player") and not is_store_open():
		show_store_notification("Store closed - Come back during preparation phase!", false)

func _on_highlight_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
		
		if player and player.has_signal("weapons_updated"):
			player.weapons_updated.disconnect(_on_player_weapons_updated)
		
		player = null
		highlight_store(false)
		close_shop()

func _on_player_weapons_updated() -> void:
	if is_player_nearby and is_store_open():
		populate_store_ui()

# Store UI button handlers
func _on_buy_button_pressed() -> void:
	if not is_store_open():
		show_store_notification("Cannot buy during active wave!", false)
		return
	
	if selected_gun_data.is_empty():
		show_purchase_notification("❌ Please select a weapon to buy", false)
		return
	
	var price = selected_gun_data.get("price", 0)
	var gun_name = selected_gun_data.get("name", "Unknown")
	
	print("=== BUY ATTEMPT ===")
	print("Trying to buy: ", gun_name)
	print("Price: $", price)
	
	if player_has_weapon(gun_name):
		show_purchase_notification("❌ You already own " + gun_name, false)
		return
	
	if player_has_enough_money(price):
		if deduct_player_money(price):
			give_gun_to_player(selected_gun_data)
			show_purchase_notification("✅ Purchased " + gun_name + " for $" + str(price), true)
			_on_player_weapons_updated()
	else:
		show_purchase_notification("❌ Not enough money for " + gun_name, false)

func _on_sell_button_pressed() -> void:
	if not is_store_open():
		show_store_notification("Cannot sell during active wave!", false)
		return
	
	if not player or selected_weapon_index == -1:
		show_purchase_notification("❌ Please select a weapon to sell", false)
		return
	
	if player.has_method("get_weapon_count"):
		var weapon_count = player.get_weapon_count()
		if weapon_count <= 1:
			show_purchase_notification("❌ Need at least 2 weapons to sell", false)
			return
	
	var weapon_to_sell = get_player_weapon_at_index(selected_weapon_index)
	if not weapon_to_sell:
		show_purchase_notification("❌ Invalid weapon selection", false)
		return
	
	var weapon_name = get_weapon_display_name(weapon_to_sell)
	var sell_price = calculate_sell_price(weapon_to_sell)
	
	if sell_player_weapon(selected_weapon_index):
		add_player_money(sell_price)
		show_purchase_notification("💰 Sold " + weapon_name + " for $" + str(sell_price), true)
		
		# Reset selection and update UI
		selected_weapon_index = -1
		
		# Update the sell list after selling
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if game_manager:
			game_manager.populate_sell_list()
		
		_on_player_weapons_updated()

# NEW: Simplified gun selection from single list
func _on_gun_selected(index: int) -> void:
	if index >= 0 and index < available_guns.size():
		selected_gun_data = available_guns[index]
		selected_weapon_index = -1  # Clear weapon selection when gun is selected
		print("Selected gun: ", selected_gun_data["name"])
	else:
		selected_gun_data = {}

# Sell list selection
func _on_sell_item_selected(index: int) -> void:
	selected_weapon_index = index
	selected_gun_data = {}  # Clear gun selection when weapon is selected
	
	var weapon = get_player_weapon_at_index(index)
	if weapon:
		var weapon_name = get_weapon_display_name(weapon)
		var sell_price = calculate_sell_price(weapon)
		print("Selected weapon for selling: ", weapon_name, " - $", sell_price)
#endregion

#region Data Getters
func get_player_weapon_at_index(index: int) -> Node2D:
	if player and player.has_method("get_weapon_at_index"):
		return player.get_weapon_at_index(index)
	return null

func get_gun_price(gun_data: Dictionary) -> int:
	return gun_data.get("price", 100)

func get_gun_name(gun_data: Dictionary) -> String:
	return gun_data.get("name", "Unknown Gun")

func calculate_sell_price(weapon: Node2D) -> int:
	if weapon and weapon.has_method("get_price"):
		var original_price = weapon.get_price()
		return int(original_price * sell_multiplier)
	elif weapon and weapon.has_property("price"):
		var original_price = weapon.price
		return int(original_price * sell_multiplier)
	return 50

func get_available_guns() -> Array[Dictionary]:
	return available_guns

func get_player() -> CharacterBody2D:
	return player

func player_has_weapon(weapon_name: String) -> bool:
	if not player:
		return false
	
	for i in range(player.get_weapon_count()):
		var weapon = player.get_weapon_at_index(i)
		if weapon:
			var current_weapon_name = get_weapon_display_name(weapon)
			if current_weapon_name == weapon_name:
				return true
	return false

func get_weapon_display_name(weapon: Node2D) -> String:
	if not weapon:
		return "Unknown"
	
	# Use the weapon_name property if it exists
	if "weapon_name" in weapon:
		return weapon.weapon_name
	
	# Otherwise use the node name and clean it up
	var node_name = weapon.name
	node_name = node_name.replace("@", "").replace(".remap", "").replace(".tscn", "")
	return node_name

func get_current_currency() -> int:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("get_current_currency"):
		return game_manager.get_current_currency()
	return 0
#endregion

#region Shop Transactions
func sell_player_weapon(weapon_index: int) -> bool:
	if player and player.has_method("remove_weapon"):
		return player.remove_weapon(weapon_index)
	return false

func give_gun_to_player(gun_data: Dictionary) -> void:
	if not player:
		return
	
	var gun_scene_path = gun_data.get("scene_path", "")
	if gun_scene_path == "":
		return
	
	var gun_scene = load(gun_scene_path)
	if gun_scene:
		var gun_instance = gun_scene.instantiate()
		
		if player.has_method("collect_weapon"):
			player.collect_weapon(gun_instance)
		else:
			gun_instance.queue_free()

func add_player_money(amount: int) -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("add_currency"):
		game_manager.add_currency(amount)

func deduct_player_money(amount: int) -> bool:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("spend_currency"):
		return game_manager.spend_currency(amount)
	return false

func player_has_enough_money(amount: int) -> bool:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("get_current_currency"):
		return game_manager.get_current_currency() >= amount
	return false
#endregion

#region Utility Functions
func show_purchase_notification(message: String, _is_success: bool) -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("show_notification"):
		game_manager.show_notification(message, 3.0)

# In Store script, update the populate_store_ui method:
func populate_store_ui() -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if not game_manager:
		return

	# Populate buy list with all available guns and icons
	if game_manager.buy_list:
		game_manager.buy_list.clear()
		for gun_data in available_guns:
			var display_text = "%s - $%d" % [gun_data["name"], gun_data["price"]]
			var icon = null
			
			# Load icon if path is provided
			if "icon_path" in gun_data and gun_data["icon_path"] != "":
				icon = load(gun_data["icon_path"])
			else:
				# Fallback to the helper method
				icon = game_manager.get_weapon_icon(gun_data["name"])
			
			game_manager.buy_list.add_item(display_text, icon)
		print("Populated buy list with ", available_guns.size(), " weapons")
	
	# Populate sell list with player weapons
	game_manager.populate_sell_list()
#endregion

#region Store Animation Control
func play_opening_animation() -> void:
	if sprite:
		sprite.play("opening")
		opening.play()
		await sprite.animation_finished
		sprite.play("open")

func play_closing_animation() -> void:
	if sprite:
		sprite.play("closing")
		closing.play()
		await sprite.animation_finished
		sprite.play("close")
#endregion
