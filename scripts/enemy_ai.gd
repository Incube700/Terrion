extends Node2D

# Скрипт EnemyAI — управляет ядром врага, строит здания и призывает юнитов
class_name EnemyAI

@onready var core = get_parent()
@onready var buildings_container = get_tree().get_root().get_node_or_null("Main/BuildingsContainer")
@onready var units_container = get_tree().get_root().get_node_or_null("Main/EnemiesContainer")

# Префабы
var soldier_scene = preload("res://scenes/enemy_soldier.tscn")
var tank_scene = preload("res://scenes/enemy_tank.tscn")
var drone_scene = preload("res://scenes/enemy_drone.tscn")
var tower_scene = preload("res://scenes/enemy_tower.tscn")
var barracks_scene = preload("res://scenes/enemy_barracks.tscn")

# Стоимость
const SOLDIER_COST = 20
const TANK_COST = 50
const DRONE_COST = 35
const TOWER_COST = 50
const BARRACKS_COST = 80

# Таймеры
var action_timer: Timer

func _ready():
	print("[EnemyAI] _ready called")
	if not buildings_container:
		print("[EnemyAI] BuildingsContainer не найден!")
	if not units_container:
		print("[EnemyAI] EnemiesContainer не найден!")
	# Таймер действий
	action_timer = Timer.new()
	action_timer.wait_time = 4.0
	action_timer.autostart = true
	action_timer.timeout.connect(_on_action_timer)
	add_child(action_timer)

func _on_action_timer():
	print("[EnemyAI] Action timer tick, энергия: ", core.energy)
	if not buildings_container or not units_container:
		print("[EnemyAI] Нет контейнеров для построек или юнитов!")
		return
	# Если нет ни одного юнита — всегда призываем солдата
	if units_container.get_child_count() == 0 and core.energy >= SOLDIER_COST:
		_summon_soldier()
		return
	# Примитивная логика: если хватает энергии — строим или призываем
	if core.energy >= TOWER_COST and not _has_tower():
		_build_tower()
	elif core.energy >= BARRACKS_COST and not _has_barracks():
		_build_barracks()
	elif core.energy >= TANK_COST:
		_summon_tank()
	elif core.energy >= DRONE_COST:
		_summon_drone()
	elif core.energy >= SOLDIER_COST:
		_summon_soldier()

func _has_tower() -> bool:
	return buildings_container.get_children().any(func(n): return n.name.begins_with("EnemyTower"))

func _has_barracks() -> bool:
	return buildings_container.get_children().any(func(n): return n.name.begins_with("EnemyBarracks"))

func _build_tower():
	if core.spend_energy(TOWER_COST):
		var tower = tower_scene.instantiate()
		tower.position = core.position + Vector2(-100, -100)
		buildings_container.add_child(tower)
		print("[EnemyAI] Башня построена!")

func _build_barracks():
	if core.spend_energy(BARRACKS_COST):
		var barracks = barracks_scene.instantiate()
		barracks.position = core.position + Vector2(-100, 100)
		buildings_container.add_child(barracks)
		print("[EnemyAI] Барак построен!")

func _summon_soldier():
	if core.spend_energy(SOLDIER_COST):
		var soldier = soldier_scene.instantiate()
		soldier.position = core.position + Vector2(-120, 0)
		units_container.add_child(soldier)
		print("[EnemyAI] Солдат призван!")

func _summon_tank():
	if core.spend_energy(TANK_COST):
		var tank = tank_scene.instantiate()
		tank.position = core.position + Vector2(-140, 40)
		units_container.add_child(tank)
		print("[EnemyAI] Танк призван!")

func _summon_drone():
	if core.spend_energy(DRONE_COST):
		var drone = drone_scene.instantiate()
		drone.position = core.position + Vector2(-120, -40)
		units_container.add_child(drone)
		print("[EnemyAI] Дрон призван!") 
