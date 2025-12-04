
# 🧟‍♂️ UNDERTOWN (Godot Engine)

A **2D top-down zombie shooter game** built with Godot Engine where you battle endless waves of zombies!  
Survive as long as you can, unlock weapons, and fight through increasingly difficult hordes.  
This project is still **in development**, with new weapons and features being added regularly.

---

## 🎮 Gameplay

- **Objective:** Survive wave after wave of zombies.  
- **Enemies:** Zombies become faster and tougher with each wave.  
- **Weapons:** Multiple weapons available (some are still under development).  
- **Controls:**  
  - `W / A / S / D` – Move  
  - `Mouse` – Aim  
  - `Left Click` – Shoot  
  - `R` – Reload  
  - `1 / 2 / 3...` – Switch weapons  

---

## 🧰 Features

### ✅ Implemented
- Wave-based zombie spawning system  
- Player movement and shooting mechanics  
- Health and damage system  
- Weapon switching (limited selection)

### 🛠️ In Development
- New weapon types (shotguns, rifles, explosives, etc.)  
- Power-ups and upgrades  
- Improved enemy AI and animations  
- Sound effects and background music  
- Main menu and pause menu  

---

## 🚀 How to Run in Godot

### Prerequisites
- **Godot Engine 4.x** installed on your computer
- [Download Godot](https://godotengine.org/download)

### Step-by-Step Setup

1. **Clone or Download the Project**
   ```bash
   git clone https://github.com/mo-rale/top-down_game.git
   ```
   Or download the ZIP file and extract it to a folder.

2. **Open Godot Engine**

3. **Import the Project**
   - Click "Import" button
   - Browse to the project folder
   - Select the `project.godot` file
   - Click "Import & Edit"

4. **Run the Game**
   - Press `F5` or click the "Play" button in the top-right corner
   - The main scene should load automatically

### Project Structure
```
zombie-shooter/
├── assets/          # Images, sounds, fonts
├── scenes/          # Godot scene files
│   ├── player.tscn
│   ├── zombie.tscn
│   ├── weapons/
│   └── ui/
├── scripts/         # GDScript files
├── project.godot    # Project configuration
└── README.md
```

---

## 📸 Screenshots

<p align="center">
  <img src="assets/Screenshot1.png" alt="Gameplay Screenshot" width="45%">
</p>

---

## 🛠️ Adding This Project to Your Godot Project

### Method 1: Manual Integration (Recommended for learning)

1. **Create a new Godot project** or use an existing one

2. **Copy the file structure:**
   - Copy the `scenes/` folder into your project
   - Copy the `scripts/` folder into your project  
   - Copy the `assets/` folder into your project

3. **Set up the main scene:**
   - In Godot, go to Project → Project Settings
   - Under "Application → Run", set the main scene to your player or game manager scene

4. **Configure input maps:**
   - Go to Project → Project Settings → Input Map
   - Add the following actions:
     - `move_forward`, `move_backward`, `move_left`, `move_right`
     - `shoot`, `reload`, `weapon_1`, `weapon_2`, `weapon_3`

### Method 2: As a Godot Module (Advanced)
If you want to use this as a reusable module:

1. **Clone into modules folder:**
   ```bash
   cd your-godot-project/
   git clone https://github.com/mo-rale/top-down_game.git modules/zombie_shooter
   ```

2. **Recompile Godot** with the module included

### Key Components to Copy:

**Player Controller:**
- `scenes/player.tscn` + `scripts/player.gd`
- Handles movement, shooting, health

**Zombie AI:**
- `scenes/zombie.tscn` + `scripts/zombie.gd`
- Pathfinding and attack behavior

**Weapon System:**
- `scenes/weapons/` folder
- Weapon base class and specific weapon types

**Wave Manager:**
- `scripts/wave_manager.gd`
- Controls zombie spawning and difficulty

---

## 🎯 Quick Start Template

If you want to start from scratch but use similar mechanics:

1. **Create a 2D scene** with:
   - CharacterBody2D for player
   - Area2D for zombies
   - Camera2D for following player

2. **Use this basic player movement script:**
```gdscript
extends CharacterBody2D

var speed = 300
var health = 100

func _physics_process(delta):
    var input_dir = Vector2.ZERO
    input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
    
    velocity = input_dir.normalized() * speed
    move_and_slide()
```

---

## 💡 Future Plans

* Add boss waves
* Introduce player customization
* Implement multiplayer or co-op mode
* Add save/load system
* Improve graphics and UI effects
* Performance optimizations for low-end devices

---

## 🧑‍💻 Contributing

Contributions are welcome!
If you'd like to suggest a feature or fix a bug:

1. Fork the repository
2. Create a new branch (`feature/your-feature-name`)
3. Commit your changes
4. Submit a pull request

Bug reports and ideas are also welcome in the **Issues** section!

---

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

---

## 👤 Author
📧 [personal email](crapeling29@gmai.com)
    [university email](ahron.badili@bisu.edu.ph)
🐙 [GitHub Profile](https://github.com/mo-rale)

---

> 🎯 *Made with passion for zombie games — still under heavy development! Stay tuned for more updates.*


