extends Node

# --- Save Data Structure ---
var save_data: Dictionary = {
	"high_kills": 0,
	"high_wave": 0,
	"high_time": 0.0,
	"high_money": 0,
	"total_games_played": 0,
	"total_kills": 0,
	"total_time_played": 0.0,
	"total_money_collected": 0,
	"last_game_stats": {
		"kills": 0,
		"wave": 0,
		"time": 0.0,
		"money": 0
	}
}

# --- Save File Path ---
const SAVE_FILE_PATH = "user://player_save_data.save"

# --- Signals ---
signal high_score_updated(stat_name: String, new_value, old_value)
signal stats_updated
signal save_data_loaded

func _ready() -> void:
	# Load saved data on startup
	load_save_data()
	
	# Save on exit
	get_tree().root.tree_exiting.connect(save_data_to_file)

#region Save/Load Functions
func load_save_data() -> void:
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		
		if error == OK:
			var loaded_data = json.data
			if loaded_data is Dictionary:
				# Update only existing keys to preserve structure
				for key in loaded_data:
					if key in save_data:
						save_data[key] = loaded_data[key]
				
				print("Save data loaded successfully")
				save_data_loaded.emit()
			else:
				print("Invalid save data format")
		else:
			print("JSON Parse Error: ", json.get_error_message())
			# Create fresh save file with defaults
			save_data_to_file()
	else:
		print("No save file found, creating new one")
		save_data_to_file()

func save_data_to_file() -> void:
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	
	if file:
		var json_string = JSON.stringify(save_data, "\t")
		file.store_string(json_string)
		file.close()
		print("Save data saved to: ", SAVE_FILE_PATH)
	else:
		print("Error: Could not save data to file")

func delete_save_data() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var dir = DirAccess.open("user://")
		dir.remove(SAVE_FILE_PATH)
		print("Save data deleted")
		# Reset to defaults
		save_data = {
			"high_kills": 0,
			"high_wave": 0,
			"high_time": 0.0,
			"high_money": 0,
			"total_games_played": 0,
			"total_kills": 0,
			"total_time_played": 0.0,
			"total_money_collected": 0,
			"last_game_stats": {
				"kills": 0,
				"wave": 0,
				"time": 0.0,
				"money": 0
			}
		}
#endregion

#region Game Stats Tracking
func record_game_stats(kills: int, wave: int, time: float, money: int) -> void:
	# Update last game stats
	save_data["last_game_stats"]["kills"] = kills
	save_data["last_game_stats"]["wave"] = wave
	save_data["last_game_stats"]["time"] = time
	save_data["last_game_stats"]["money"] = money
	
	# Update total stats
	save_data["total_games_played"] += 1
	save_data["total_kills"] += kills
	save_data["total_time_played"] += time
	save_data["total_money_collected"] += money
	
	# Check and update high scores
	update_high_score("high_kills", kills)
	update_high_score("high_wave", wave)
	update_high_score("high_time", time)
	update_high_score("high_money", money)
	
	# Save to file
	save_data_to_file()
	stats_updated.emit()

func update_high_score(stat_name: String, new_value) -> void:
	var old_value = save_data[stat_name]
	
	# Compare values (handle both int and float)
	if typeof(new_value) == typeof(old_value):
		if new_value > old_value:
			save_data[stat_name] = new_value
			high_score_updated.emit(stat_name, new_value, old_value)
			print("New high score! ", stat_name, ": ", new_value, " (was: ", old_value, ")")
	else:
		print("Type mismatch for stat: ", stat_name)
#endregion

#region Getter Functions
func get_high_kills() -> int:
	return save_data["high_kills"]

func get_high_wave() -> int:
	return save_data["high_wave"]

func get_high_time() -> float:
	return save_data["high_time"]

func get_high_money() -> int:
	return save_data["high_money"]

func get_last_game_kills() -> int:
	return save_data["last_game_stats"]["kills"]

func get_last_game_wave() -> int:
	return save_data["last_game_stats"]["wave"]

func get_last_game_time() -> float:
	return save_data["last_game_stats"]["time"]

func get_last_game_money() -> int:
	return save_data["last_game_stats"]["money"]

func get_total_games_played() -> int:
	return save_data["total_games_played"]

func get_total_kills() -> int:
	return save_data["total_kills"]

func get_total_time_played() -> float:
	return save_data["total_time_played"]

func get_total_money_collected() -> int:
	return save_data["total_money_collected"]

func get_all_stats() -> Dictionary:
	return save_data.duplicate(true)

func format_time(seconds: float) -> String:
	var hours = int(seconds) / 3600
	var minutes = (int(seconds) % 3600) / 60
	var secs = int(seconds) % 60
	
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	else:
		return "%02d:%02d" % [minutes, secs]
#endregion

#region Debug Functions
func print_all_stats() -> void:
	print("=== GAME STATISTICS ===")
	print("High Kills: ", get_high_kills())
	print("High Wave: ", get_high_wave())
	print("High Time: ", format_time(get_high_time()))
	print("High Money: $", get_high_money())
	print("---")
	print("Last Game - Kills: ", get_last_game_kills(), " Wave: ", get_last_game_wave())
	print("Last Game - Time: ", format_time(get_last_game_time()), " Money: $", get_last_game_money())
	print("---")
	print("Total Games: ", get_total_games_played())
	print("Total Kills: ", get_total_kills())
	print("Total Time: ", format_time(get_total_time_played()))
	print("Total Money: $", get_total_money_collected())
	print("========================")

func reset_high_scores() -> void:
	save_data["high_kills"] = 0
	save_data["high_wave"] = 0
	save_data["high_time"] = 0.0
	save_data["high_money"] = 0
	save_data_to_file()
	print("High scores reset")
	stats_updated.emit()
#endregion
