extends Node2D

# Основной скрипт игры
class_name Main

# Только эти onready переменные!
@onready var play_button = $UI/PlayButton
@onready var exit_button = $UI/ExitButton

# Все остальные переменные объявляем только один раз
var player_core: Node2D
var enemy_core: Node2D
var units_container: Node2D
var buildings_container: Node2D
var hud: CanvasLayer
var energy_label: Label
var energy: float = 0.0
var max_energy: float = 200.0
var energy_generation_rate: float = 5.0
var health: int = 100
var max_health: int = 100
var energy_timer: Timer
var btn_soldier: Button
var btn_tank: Button
var btn_tower: Button
var btn_barracks: Button

# Префабы для юнитов и построек
var soldier_scene = preload("res://scenes/soldier.tscn")
var tank_scene = preload("res://scenes/tank.tscn")
var drone_scene = preload("res://scenes/drone.tscn")
var tower_scene = preload("res://scenes/tower.tscn")
var barracks_scene = preload("res://scenes/barracks.tscn")

# Стоимость
const SOLDIER_COST = 20
const TANK_COST = 50
const DRONE_COST = 35
const TOWER_COST = 50
const BARRACKS_COST = 80

# GameOver
var game_over_instance: Node = null
var game_over_scene = preload("res://scenes/GameOver.tscn")

var battle_scene_path := "res://scenes/battle_scene.tscn"

func _ready():
	print("[Main] _ready called")
	# Добавляем в группу для поиска
	add_to_group("main")
	play_button.pressed.connect(_on_play_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_summon_soldier():
	if player_core.energy >= SOLDIER_COST:
		player_core.spend_energy(SOLDIER_COST)
		var soldier = soldier_scene.instantiate()
		soldier.position = player_core.position + Vector2(100, 0)
		units_container.add_child(soldier)
		print("Солдат призван!")

func _on_summon_tank():
	if player_core.energy >= TANK_COST:
		player_core.spend_energy(TANK_COST)
		var tank = tank_scene.instantiate()
		tank.position = player_core.position + Vector2(120, 40)
		units_container.add_child(tank)
		print("Танк призван!")

func _on_summon_drone():
	if player_core.energy >= DRONE_COST:
		player_core.spend_energy(DRONE_COST)
		var drone = drone_scene.instantiate()
		drone.position = player_core.position + Vector2(100, -40)
		units_container.add_child(drone)
		print("Дрон призван!")

func _on_build_tower():
	if player_core.energy >= TOWER_COST:
		player_core.spend_energy(TOWER_COST)
		var tower = tower_scene.instantiate()
		tower.position = player_core.position + Vector2(0, -100)
		buildings_container.add_child(tower)
		print("Башня построена!")

func _on_build_barracks():
	if player_core.energy >= BARRACKS_COST:
		player_core.spend_energy(BARRACKS_COST)
		var barracks = barracks_scene.instantiate()
		barracks.position = player_core.position + Vector2(-100, 0)
		buildings_container.add_child(barracks)
		print("Барак построен!")

func show_game_over(message: String):
	if game_over_instance:
		return
	game_over_instance = game_over_scene.instantiate()
	add_child(game_over_instance)
	game_over_instance.set_message(message)

func _on_play_pressed():
	$UI.hide()
	_spawn_battlefield()
	print("Игра началась!")

func _on_exit_pressed():
	get_tree().quit()

func _spawn_battlefield():
	units_container = Node2D.new()
	units_container.name = "UnitsContainer"
	add_child(units_container)
	buildings_container = Node2D.new()
	buildings_container.name = "BuildingsContainer"
	add_child(buildings_container)
	player_core = Node2D.new()
	player_core.name = "PlayerCore"
	var player_core_shape = ColorRect.new()
	player_core_shape.color = Color(0.2, 0.6, 1.0)
	player_core_shape.size = Vector2(48, 48)
	player_core_shape.position = Vector2(-24, -24)
	player_core.add_child(player_core_shape)
	player_core.position = Vector2(200, 300)
	add_child(player_core)
	enemy_core = Node2D.new()
	enemy_core.name = "EnemyCore"
	var enemy_core_shape = ColorRect.new()
	enemy_core_shape.color = Color(1.0, 0.2, 0.2)
	enemy_core_shape.size = Vector2(48, 48)
	enemy_core_shape.position = Vector2(-24, -24)
	enemy_core.add_child(enemy_core_shape)
	enemy_core.position = Vector2(1000, 300)
	add_child(enemy_core)
	# Создаём HUD через отдельную сцену
	var hud_scene = preload("res://scenes/HUD.tscn")
	hud = hud_scene.instantiate()
	hud.name = "HUD"
	add_child(hud)
	# Подключаем сигналы HUD
	hud.summon_soldier_requested.connect(_on_summon_soldier)
	hud.summon_tank_requested.connect(_on_summon_tank)
	hud.summon_drone_requested.connect(_on_summon_drone)
	hud.build_tower_requested.connect(_on_build_tower)
	hud.build_barracks_requested.connect(_on_build_barracks)
	energy_label = Label.new()
	energy_label.text = _get_energy_text()
	energy_label.position = Vector2(20, 20)
	hud.add_child(energy_label)
	btn_soldier = Button.new()
	btn_soldier.text = "Soldier"
	btn_soldier.position = Vector2(1000, 40)
	btn_soldier.pressed.connect(_on_soldier_pressed)
	hud.add_child(btn_soldier)
	btn_tank = Button.new()
	btn_tank.text = "Tank"
	btn_tank.position = Vector2(1000, 90)
	btn_tank.pressed.connect(_on_tank_pressed)
	hud.add_child(btn_tank)
	btn_tower = Button.new()
	btn_tower.text = "Tower"
	btn_tower.position = Vector2(1000, 140)
	btn_tower.pressed.connect(_on_tower_pressed)
	hud.add_child(btn_tower)
	btn_barracks = Button.new()
	btn_barracks.text = "Barracks"
	btn_barracks.position = Vector2(1000, 190)
	btn_barracks.pressed.connect(_on_barracks_pressed)
	hud.add_child(btn_barracks)
	energy = 0.0
	health = max_health
	energy_timer = Timer.new()
	energy_timer.wait_time = 1.0
	energy_timer.autostart = true
	energy_timer.timeout.connect(_on_energy_timer)
	add_child(energy_timer)

func _on_energy_timer():
	energy = min(energy + energy_generation_rate, max_energy)
	energy_label.text = _get_energy_text()

func _get_energy_text() -> String:
	return "Energy: %.1f / %d\nHealth: %d / %d" % [energy, max_energy, health, max_health]

func _on_soldier_pressed():
	print("[HUD] Soldier button pressed (заглушка)")

func _on_tank_pressed():
	print("[HUD] Tank button pressed (заглушка)")

func _on_tower_pressed():
	print("[HUD] Tower button pressed (заглушка)")

func _on_barracks_pressed():
	print("[HUD] Barracks button pressed (заглушка)")
