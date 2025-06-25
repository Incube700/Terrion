extends Node2D

# Основной скрипт игры
class_name Main

# Ссылки на контейнеры
@onready var units_container = $UnitsContainer
@onready var buildings_container = $BuildingsContainer
@onready var enemies_container = $EnemiesContainer
@onready var core = $Core
@onready var hud = $HUD

# Префабы для создания объектов
var soldier_scene = preload("res://scenes/soldier.tscn")
var tank_scene = preload("res://scenes/tank.tscn")
var drone_scene = preload("res://scenes/drone.tscn")
var tower_scene = preload("res://scenes/tower.tscn")
var barracks_scene = preload("res://scenes/barracks.tscn")
var game_over_scene = preload("res://scenes/GameOver.tscn")
var game_over_instance: CanvasLayer = null

# Стоимость объектов
const SOLDIER_COST = 20
const TANK_COST = 50
const DRONE_COST = 35
const TOWER_COST = 50
const BARRACKS_COST = 80

func _ready():
	print("[Main] _ready called")
	# Добавляем в группу для поиска
	add_to_group("main")
	
	# Подключаем сигналы HUD
	hud.summon_soldier_requested.connect(_on_summon_soldier)
	hud.summon_tank_requested.connect(_on_summon_tank)
	hud.summon_drone_requested.connect(_on_summon_drone)
	hud.build_tower_requested.connect(_on_build_tower)
	hud.build_barracks_requested.connect(_on_build_barracks)
	
	# Враги теперь создаются через EnemySpawner
	print("Игра TERRION запущена! Защищайте ядро от волн врагов!")

func _on_summon_soldier():
	if core.energy >= SOLDIER_COST:
		core.spend_energy(SOLDIER_COST)
		var soldier = soldier_scene.instantiate()
		soldier.position = core.position + Vector2(100, 0)
		units_container.add_child(soldier)
		print("Солдат призван!")

func _on_summon_tank():
	if core.energy >= TANK_COST:
		core.spend_energy(TANK_COST)
		var tank = tank_scene.instantiate()
		tank.position = core.position + Vector2(120, 40)
		units_container.add_child(tank)
		print("Танк призван!")

func _on_summon_drone():
	if core.energy >= DRONE_COST:
		core.spend_energy(DRONE_COST)
		var drone = drone_scene.instantiate()
		drone.position = core.position + Vector2(100, -40)
		units_container.add_child(drone)
		print("Дрон призван!")

func _on_build_tower():
	if core.energy >= TOWER_COST:
		core.spend_energy(TOWER_COST)
		var tower = tower_scene.instantiate()
		tower.position = core.position + Vector2(0, -100)
		buildings_container.add_child(tower)
		print("Башня построена!")

func _on_build_barracks():
	if core.energy >= BARRACKS_COST:
		core.spend_energy(BARRACKS_COST)
		var barracks = barracks_scene.instantiate()
		barracks.position = core.position + Vector2(-100, 0)
		buildings_container.add_child(barracks)
		print("Барак построен!")

func show_game_over(message: String):
	if game_over_instance:
		return
	game_over_instance = game_over_scene.instantiate()
	add_child(game_over_instance)
	game_over_instance.set_message(message) 
