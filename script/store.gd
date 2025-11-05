extends StaticBody2D

# --- Store Settings ---
@export var store_name: String = "Gun Store"
@export var guns_for_sale: Array[PackedScene] = []
@export var sell_multiplier: float = 0.7

# Node References
@onready var highlight_area: Area2D = $buying_area
@onready var collision_shape: CollisionShape2D = $buying_area/CollisionShape2D
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var opening: AudioStreamPlayer2D = $opening
@onready var closing: AudioStreamPlayer2D = $closing


# State Variables
var is_player_nearby: bool = false
var player: CharacterBody2D = null
var gun_data_cache: Dictionary = {}


func _ready() -> void:
	add_to_group("store")
	highlight_area.connect("body_entered", Callable(self, "_on_highlight_area_body_entered"))
	highlight_area.connect("body_exited", Callable(self, "_on_highlight_area_body_exited"))
	
	cache_gun_data()

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
				sprite.modulate = Color(1, 1, 1)
			else:
				sprite.modulate = Color(1, 1, 1)
		
		if not is_store_available and is_player_nearby:
			close_shop()
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
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if game_manager and game_manager.has_method("update_store_ui"):
			game_manager.update_store_ui()

func _on_buy_button_pressed(gun_index: int) -> void:
	if not is_store_open():
		show_store_notification("Cannot buy during active wave!", false)
		return
	
	if gun_index < 0 or gun_index >= guns_for_sale.size():
		return
	
	var gun_scene = guns_for_sale[gun_index]
	var price = get_gun_price(gun_scene)
	var gun_name = get_gun_name(gun_scene)
	
	if player_has_enough_money(price):
		if deduct_player_money(price):
			give_gun_to_player(gun_scene)
			show_purchase_notification("✅ Purchased " + gun_name + " for $" + str(price), true)
			_on_player_weapons_updated()
	else:
		show_purchase_notification("❌ Not enough money for " + gun_name, false)

func _on_sell_button_pressed(weapon_index: int, sell_price: int) -> void:
	if not is_store_open():
		show_store_notification("Cannot sell during active wave!", false)
		return
	
	if not player:
		return
	
	if player.has_method("get_weapon_count"):
		var weapon_count = player.get_weapon_count()
		if weapon_count <= 1:
			show_purchase_notification("❌ Need at least 2 weapons to sell", false)
			return
	
	var weapon_to_sell = get_player_weapon_at_index(weapon_index)
	if not weapon_to_sell:
		return
	
	var weapon_name = weapon_to_sell.name
	
	if sell_player_weapon(weapon_index):
		add_player_money(sell_price)
		show_purchase_notification("💰 Sold " + weapon_name + " for $" + str(sell_price), true)
		_on_player_weapons_updated()
#endregion

#region Data Getters
func get_player_weapon_at_index(index: int) -> Node2D:
	if player and player.has_method("get_weapon_at_index"):
		return player.get_weapon_at_index(index)
	return null

func get_gun_price(gun_scene: PackedScene) -> int:
	if gun_scene in gun_data_cache:
		return gun_data_cache[gun_scene].price
	
	var gun_instance = gun_scene.instantiate()
	var price = 100
	
	if gun_instance.has_method("get_price"):
		price = gun_instance.get_price()
	elif gun_instance.has_property("price"):
		price = gun_instance.price
	
	gun_instance.queue_free()
	return price

func get_gun_name(gun_scene: PackedScene) -> String:
	if gun_scene in gun_data_cache:
		return gun_data_cache[gun_scene].name
	
	var gun_instance = gun_scene.instantiate()
	var gun_name = "Unknown Gun"
	
	if gun_instance:
		gun_name = gun_instance.name
		gun_instance.queue_free()
	
	return gun_name

func calculate_sell_price(weapon: Node2D) -> int:
	if weapon and weapon.has_method("get_price"):
		var original_price = weapon.get_price()
		return int(original_price * sell_multiplier)
	elif weapon and weapon.has_property("price"):
		var original_price = weapon.price
		return int(original_price * sell_multiplier)
	return 50

func get_guns_for_sale() -> Array[PackedScene]:
	return guns_for_sale

func get_player() -> CharacterBody2D:
	return player
#endregion

#region Shop Transactions
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

func cache_gun_data() -> void:
	for gun_scene in guns_for_sale:
		if gun_scene:
			var gun_instance = gun_scene.instantiate()
			var gun_data = {
				"name": gun_instance.name,
				"price": 100
			}
			
			if gun_instance.has_method("get_price"):
				gun_data["price"] = gun_instance.get_price()
			elif gun_instance.has_property("price"):
				gun_data["price"] = gun_instance.price
			
			gun_data_cache[gun_scene] = gun_data
			gun_instance.queue_free()
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
