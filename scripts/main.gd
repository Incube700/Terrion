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
var tower_scene = preload("res://scenes/tower.tscn")
var barracks_scene = preload("res://scenes/barracks.tscn")

# Стоимость объектов
const SOLDIER_COST = 20
const TOWER_COST = 50
const BARRACKS_COST = 80

func _ready():
	# Добавляем в группу для поиска
	add_to_group("main")
	
	# Подключаем сигналы HUD
	hud.summon_soldier_requested.connect(_on_summon_soldier)
	hud.build_tower_requested.connect(_on_build_tower)
	hud.build_barracks_requested.connect(_on_build_barracks)
	
	# Создаем несколько врагов для тестирования
	_create_test_enemies()

func _on_summon_soldier():
	if core.energy >= SOLDIER_COST:
		core.spend_energy(SOLDIER_COST)
		var soldier = soldier_scene.instantiate()
		soldier.position = core.position + Vector2(100, 0)
		units_container.add_child(soldier)
		print("Солдат призван!")

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

func _create_test_enemies():
	# Создаем несколько врагов для тестирования
	for i in range(3):
		var enemy = preload("res://scenes/enemy.tscn").instantiate()
		enemy.position = Vector2(800 + i * 100, 300)
		enemies_container.add_child(enemy) 