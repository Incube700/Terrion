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
var flash_scene = preload("res://scenes/Flash.tscn")

# Стоимость
const SOLDIER_COST = 50
const TANK_COST = 100
const DRONE_COST = 75
const TOWER_COST = 150
const BARRACKS_COST = 200

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
	if energy >= SOLDIER_COST:
		energy -= SOLDIER_COST
		var soldier = soldier_scene.instantiate()
		soldier.position = player_core.position
		units_container.add_child(soldier)
		# Flash effect
		var flash = flash_scene.instantiate()
		flash.position = soldier.position
		add_child(flash)
		print("Солдат призван! Энергия: ", energy)
		energy_label.text = _get_energy_text()
	else:
		print("Недостаточно энергии для призыва солдата!")

func _on_summon_tank():
	if energy >= TANK_COST:
		energy -= TANK_COST
		var tank = tank_scene.instantiate()
		tank.position = player_core.position
		units_container.add_child(tank)
		# Flash effect
		var flash = flash_scene.instantiate()
		flash.position = tank.position
		add_child(flash)
		print("Танк призван! Энергия: ", energy)
		energy_label.text = _get_energy_text()
	else:
		print("Недостаточно энергии для призыва танка!")

func _on_summon_drone():
	if player_core.energy >= DRONE_COST:
		player_core.spend_energy(DRONE_COST)
		var drone = drone_scene.instantiate()
		drone.position = player_core.position + Vector2(100, -40)
		units_container.add_child(drone)
		# Flash effect
		var flash = flash_scene.instantiate()
		flash.position = drone.position
		units_container.add_child(flash)
		print("Дрон призван!")

func _on_build_tower():
	if energy >= TOWER_COST:
		energy -= TOWER_COST
		var tower = tower_scene.instantiate()
		# Place tower in front of the core
		var spawn_offset = Vector2(100, 0)  # 100 pixels in front of core
		tower.position = player_core.position + spawn_offset
		buildings_container.add_child(tower)
		# Flash effect
		var flash = flash_scene.instantiate()
		flash.position = tower.position
		add_child(flash)
		print("Башня построена! Энергия: ", energy)
		energy_label.text = _get_energy_text()
	else:
		print("Недостаточно энергии для постройки башни!")

func _on_build_barracks():
	if energy >= BARRACKS_COST:
		energy -= BARRACKS_COST
		var barracks = barracks_scene.instantiate()
		barracks.position = player_core.position + Vector2(0, 100)
		buildings_container.add_child(barracks)
		# Flash effect
		var flash = flash_scene.instantiate()
		flash.position = barracks.position
		add_child(flash)
		print("Казарма построена! Энергия: ", energy)
		energy_label.text = _get_energy_text()
	else:
		print("Недостаточно энергии для постройки казармы!")

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
	# Контейнер для вражеских юнитов
	var enemies_container = Node2D.new()
	enemies_container.name = "EnemiesContainer"
	add_child(enemies_container)
	
	# Ядро игрока
	player_core = Node2D.new()
	player_core.name = "PlayerCore"
	var player_core_shape = ColorRect.new()
	player_core_shape.color = Color(0.2, 0.6, 1.0)
	player_core_shape.size = Vector2(48, 48)
	player_core_shape.position = Vector2(-24, -24)
	player_core.add_child(player_core_shape)
	player_core.position = Vector2(200, 300)
	# Add to player buildings group
	player_core.add_to_group("player_buildings")
	add_child(player_core)
	
	# Ядро врага (инстанцируем сцену EnemyCore.tscn)
	var enemy_core_scene = preload("res://scenes/enemy_core.tscn")
	enemy_core = enemy_core_scene.instantiate()
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
	
	# Инициализация энергии и таймера
	energy = 50.0  # Начальная энергия
	energy_label = Label.new()
	energy_label.text = _get_energy_text()
	energy_label.position = Vector2(20, 20)
	hud.add_child(energy_label)
	
	energy_timer = Timer.new()
	energy_timer.wait_time = 1.0
	energy_timer.autostart = true
	energy_timer.timeout.connect(_on_energy_timer)
	add_child(energy_timer)

func _on_energy_timer():
	energy = min(energy + energy_generation_rate, max_energy)
	energy_label.text = _get_energy_text()

func _get_energy_text() -> String:
	return "Энергия: %.1f / %d\nЗдоровье: %d / %d" % [energy, max_energy, health, max_health]

func _on_soldier_pressed():
	_on_summon_soldier()

func _on_tank_pressed():
	_on_summon_tank()

func _on_tower_pressed():
	_on_build_tower()

func _on_barracks_pressed():
	_on_build_barracks()
