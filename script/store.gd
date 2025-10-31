extends StaticBody2D

# --- Store Settings ---
@export var store_name: String = "Gun Store"
@export var guns_for_sale: Array[PackedScene] = []  # Add gun scenes here in the inspector
@export var sell_multiplier: float = 0.7  # Players get 70% of original price when selling

@onready var highlight_area: Area2D = $buying_area
@onready var collision_shape: CollisionShape2D = $buying_area/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

var is_player_nearby: bool = false
var player: CharacterBody2D = null

# UI references
@onready var shop_ui: Control = %ShopUI
@onready var item_container: VBoxContainer = $CanvasLayer/ShopUI/Panel/ItemContainer
@onready var player_weapons_container: VBoxContainer = $CanvasLayer/ShopUI/Panel/PlayerWeaponsContainer
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	# Add to store group for detection
	add_to_group("store")
	
	# Connect signals
	highlight_area.connect("body_entered", Callable(self, "_on_highlight_area_body_entered"))
	highlight_area.connect("body_exited", Callable(self, "_on_highlight_area_body_exited"))
	
	# Initialize UI (hide it at start)
	if shop_ui:
		shop_ui.visible = false
	
	# Connect close button if it exists
	if close_button:
		close_button.connect("pressed", Callable(self, "_on_close_button_pressed"))
func _process(_delta: float) -> void:
	# Allow closing shop with Escape key when UI is visible
	if shop_ui and shop_ui.visible and Input.is_action_just_pressed("ui_cancel"):
		close_shop()

#-----REALTIME FUNCTIONS--------#
func _on_highlight_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true
		player = body
		
		# Connect to player's weapons_updated signal
		if player.has_signal("weapons_updated"):
			player.weapons_updated.connect(_on_player_weapons_updated)
		
		highlight_store(true)
		open_shop()
		print("🏪 Player entered store:", store_name)
func _on_highlight_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
		
		# Disconnect from player's weapons_updated signal
		if player and player.has_signal("weapons_updated"):
			player.weapons_updated.disconnect(_on_player_weapons_updated)
		
		player = null
		highlight_store(false)
		close_shop()
		print("❌ Player left store:", store_name)
func _on_player_weapons_updated() -> void:
	print("🔄 Player weapons updated - refreshing shop UI")
	if shop_ui and shop_ui.visible:
		populate_player_weapons()
func _on_buy_button_pressed(gun_index: int) -> void:
	if gun_index < 0 or gun_index >= guns_for_sale.size():
		print("❌ Invalid gun index")
		return
	
	var gun_scene = guns_for_sale[gun_index]
	var price = get_gun_price(gun_scene)
	var gun_name = get_gun_name(gun_scene)
	
	if player_has_enough_money(price):
		if deduct_player_money(price):
			give_gun_to_player(gun_scene)
			show_purchase_notification("✅ Purchased " + gun_name + " for $" + str(price), true)
			print("✅ Purchased:", gun_scene.resource_path, " for $", price)
			
			if shop_ui and shop_ui.visible:
				populate_player_weapons()
		else:
			show_purchase_notification("❌ Failed to purchase " + gun_name, false)
	else:
		show_purchase_notification("❌ Not enough money for " + gun_name + " ($" + str(price) + ")", false)
		print("❌ Not enough money to buy:", gun_scene.resource_path)
func _on_close_button_pressed() -> void:
	close_shop()
func _on_sell_button_pressed(weapon_index: int, sell_price: int) -> void:
	if not player:
		return
	
	if player.has_method("get_weapon_count"):
		var weapon_count = player.get_weapon_count()
		if weapon_count <= 1:
			show_purchase_notification("❌ Need at least 2 weapons to sell", false)
			return
	
	var weapon_to_sell = get_player_weapon_at_index(weapon_index)
	if not weapon_to_sell:
		show_purchase_notification("❌ Weapon not found", false)
		return
	
	var weapon_name = weapon_to_sell.name
	
	if sell_player_weapon(weapon_index):
		add_player_money(sell_price)
		show_purchase_notification("💰 Sold " + weapon_name + " for $" + str(sell_price), true)
		populate_player_weapons()
	else:
		show_purchase_notification("❌ Failed to sell " + weapon_name, false)

#------SHOP INTERACTIONS-----#
func open_shop() -> void:
	if not player:
		return
	
	print("🛒 Opening shop:", store_name)
	
	# Show UI
	if shop_ui:
		shop_ui.visible = true
		populate_shop_items()
		populate_player_weapons()
func close_shop() -> void:
	print("🚪 Closing shop:", store_name)
	
	# Hide UI
	if shop_ui:
		shop_ui.visible = false

#-------POPULATOR-----#
func populate_shop_items() -> void:
	if not item_container:
		return
	
	# Clear existing items
	for child in item_container.get_children():
		child.queue_free()
	
	# Add section title for buying
	var buy_title = Label.new()
	buy_title.text = "Weapons for Sale:"
	buy_title.modulate = Color(1, 1, 0.8)
	item_container.add_child(buy_title)
	
	# Create shop items for each gun
	for i in range(guns_for_sale.size()):
		var gun_scene = guns_for_sale[i]
		var price = get_gun_price(gun_scene)
		var shop_item = create_shop_item(gun_scene, price, i)
		item_container.add_child(shop_item)
func populate_player_weapons() -> void:
	if not player_weapons_container:
		print("❌ No player_weapons_container found!")
		return
	
	# Clear existing items
	for child in player_weapons_container.get_children():
		child.queue_free()
	
	print("🔍 Store: Checking player weapons...")
	
	# Debug: Print player inventory state
	if player and player.has_method("print_inventory_state"):
		player.print_inventory_state()
	
	# Check if player has weapons to sell
	if player and player.has_method("get_weapon_count"):
		var weapon_count = player.get_weapon_count()
		print("🔍 Store: Player has", weapon_count, "weapons")
		
		# Add section title for selling
		var sell_title = Label.new()
		sell_title.text = "Your Weapons (Sell):"
		sell_title.modulate = Color(0.8, 0.8, 1.0)
		player_weapons_container.add_child(sell_title)
		
		# Don't allow selling if player has 1 or fewer weapons
		if weapon_count <= 1:
			var warning_label = Label.new()
			warning_label.text = "Need at least 2 weapons to sell"
			warning_label.modulate = Color(1, 0.5, 0.5)
			player_weapons_container.add_child(warning_label)
			return
		
		# Get player's current weapon for reference
		var current_weapon = null
		if player.has_method("get_current_weapon"):
			current_weapon = player.get_current_weapon()
			print("🔍 Store: Current weapon:", current_weapon.name if current_weapon else "None")
		
		# Create sell items for each weapon in player's inventory
		for i in range(weapon_count):
			var weapon = get_player_weapon_at_index(i)
			print("🔍 Store: Weapon at index", i, ":", weapon.name if weapon else "None")
			
			if weapon and weapon != current_weapon:
				var sell_price = calculate_sell_price(weapon)
				var sell_item = create_sell_item(weapon, sell_price, i)
				player_weapons_container.add_child(sell_item)
				print("✅ Added sell item for:", weapon.name)
			elif weapon and weapon == current_weapon:
				var current_item = create_current_weapon_item(weapon)
				player_weapons_container.add_child(current_item)
				print("ℹ️  Added current weapon item:", weapon.name)
	else:
		print("❌ Store: Player doesn't have get_weapon_count method")
		var no_weapons_label = Label.new()
		no_weapons_label.text = "No weapons to sell"
		no_weapons_label.modulate = Color(0.7, 0.7, 0.7)
		player_weapons_container.add_child(no_weapons_label)

#------GETTERS-----#
func get_player_weapon_at_index(index: int) -> Node2D:
	if player and player.has_method("get_weapon_at_index"):
		return player.get_weapon_at_index(index)
	return null
func get_gun_price(gun_scene: PackedScene) -> int:
	var gun_instance = gun_scene.instantiate()
	var price = 100  # Default price
	
	if gun_instance.has_method("get_price"):
		price = gun_instance.get_price()
	elif "price" in gun_instance:
		price = gun_instance.price
	
	gun_instance.free()
	print("💰 Gun", gun_scene.resource_path, "price:", price)
	return price
func get_gun_name(gun_scene: PackedScene) -> String:
	var gun_instance = gun_scene.instantiate()
	var gun_name = gun_instance.name
	gun_instance.free()
	return gun_name


func calculate_sell_price(weapon: Node2D) -> int:
	if weapon and weapon.has_method("get_price"):
		var original_price = weapon.get_price()
		return int(original_price * sell_multiplier)
	return 50  # Default sell price

#------CREATORS------#
func create_sell_item(weapon: Node2D, sell_price: int, weapon_index: int) -> Control:
	var sell_item = HBoxContainer.new()
	sell_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var weapon_name_label = Label.new()
	weapon_name_label.text = weapon.name
	weapon_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var price_label = Label.new()
	price_label.text = "Sell: $" + str(sell_price)
	price_label.modulate = Color(0.5, 1, 0.5)
	
	var sell_button = Button.new()
	sell_button.text = "Sell"
	sell_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	sell_button.connect("pressed", Callable(self, "_on_sell_button_pressed").bind(weapon_index, sell_price))
	
	sell_item.add_child(weapon_name_label)
	sell_item.add_child(price_label)
	sell_item.add_child(sell_button)
	
	return sell_item
func create_current_weapon_item(weapon: Node2D) -> Control:
	var current_item = HBoxContainer.new()
	current_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var weapon_name_label = Label.new()
	weapon_name_label.text = weapon.name + " (Equipped)"
	weapon_name_label.modulate = Color(0.8, 0.8, 0.8)
	
	var info_label = Label.new()
	info_label.text = "Currently using"
	info_label.modulate = Color(0.8, 0.8, 0.8)
	
	current_item.add_child(weapon_name_label)
	current_item.add_child(info_label)
	
	return current_item
func create_shop_item(gun_scene: PackedScene, price: int, index: int) -> Control:
	var shop_item = HBoxContainer.new()
	shop_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var gun_name_label = Label.new()
	var gun_instance = gun_scene.instantiate()
	gun_name_label.text = gun_instance.name
	gun_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gun_instance.free()
	
	var price_label = Label.new()
	price_label.text = "$" + str(price)
	
	var buy_button = Button.new()
	buy_button.text = "Buy"
	buy_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	buy_button.connect("pressed", Callable(self, "_on_buy_button_pressed").bind(index))
	
	shop_item.add_child(gun_name_label)
	shop_item.add_child(price_label)
	shop_item.add_child(buy_button)
	
	return shop_item

#-----SELL AND BUY GUNS------#
func sell_player_weapon(weapon_index: int) -> bool:
	if player and player.has_method("drop_weapon"):
		player.drop_weapon(weapon_index)
		return true
	return false
func give_gun_to_player(gun_scene: PackedScene) -> void:
	if not player:
		return
	
	var gun_instance = gun_scene.instantiate()
	
	if player.has_method("collect_weapon"):
		player.collect_weapon(gun_instance)
	else:
		print("❌ Player doesn't have collect_weapon method")
		gun_instance.free()

#------PLAYERS MONEY FEEDBACK--------#
func add_player_money(amount: int) -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("add_currency"):
		game_manager.add_currency(amount)
		print("💰 Store: Added $", amount, " to player from weapon sale")
func deduct_player_money(amount: int) -> bool:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("spend_currency"):
		if game_manager.spend_currency(amount):
			print("💵 Store: Successfully deducted $", amount, " from player")
			return true
		else:
			print("❌ Store: Failed to deduct $", amount, " - not enough money")
			return false
	else:
		print("❌ Store: No game manager found to deduct currency")
		return false
func player_has_enough_money(amount: int) -> bool:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("get_current_currency"):
		var player_money = game_manager.get_current_currency()
		var can_afford = player_money >= amount
		print("💳 Store: Player has $", player_money, ", needs $", amount, ":", can_afford)
		return can_afford
	else:
		print("❌ Store: No game manager found to check currency")
		return false

#------UI FEEDBACK-------#
func highlight_store(should_highlight: bool) -> void:
	if not sprite:
		return
	
	# Stop any existing tweens
	var existing_tweens = get_tree().get_processed_tweens()
	for tween in existing_tweens:
		if tween.is_valid() and tween.get_object() == sprite:
			tween.kill()
	
	if should_highlight:
		# Simple constant glow
		sprite.modulate = Color(1.3, 1.3, 1.0)  # Yellowish glow
	else:
		# Reset to normal
		sprite.modulate = Color(1, 1, 1)
func show_purchase_notification(message: String, _is_success: bool) -> void:
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager and game_manager.has_method("show_notification"):
		game_manager.show_notification(message, 5.0)
	else:
		print("❌ Store: No game manager found to show notification:", message)
