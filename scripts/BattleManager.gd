extends Node

# BattleManager — управляет логикой боя, ресурсами, победой/поражением

var player_resources = 100
var enemy_resources = 100
var resource_gain_per_sec = 10

var player_base_hp = 100
var enemy_base_hp = 100

var lanes = []
var player_spawners = []
var enemy_spawners = []

signal battle_finished(winner)

var unit_scene = preload("res://scenes/Unit.tscn")
var battle_ui = null
var battle_started = false

func _ready():
	# Найти все линии и спавнеры (ищем Lane1, Lane2, Lane3 как дочерние узлы Battle)
	lanes = [
		get_node("Lane1"),
		get_node("Lane2"),
		get_node("Lane3")
	]
	for lane in lanes:
		player_spawners.append(lane.get_node("PlayerSpawner" + str(lanes.find(lane)+1)))
		enemy_spawners.append(lane.get_node("EnemySpawner" + str(lanes.find(lane)+1)))
	battle_ui = get_node("BattleUI")
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_resources, enemy_base_hp, enemy_resources)
		battle_ui.start_battle.connect(_on_start_battle)
	# Запустить таймеры спавна
	for spawner in player_spawners + enemy_spawners:
		spawner.get_node("SpawnTimer").autostart = true
		spawner.get_node("SpawnTimer").start()
	# Запустить таймер ресурсов
	var resource_timer = Timer.new()
	resource_timer.wait_time = 1.0
	resource_timer.autostart = true
	resource_timer.timeout.connect(_on_resource_timer)
	add_child(resource_timer)

func _on_start_battle():
	battle_started = true
	if battle_ui:
		battle_ui.start_button.hide()
	# Запустить таймеры спавна
	for spawner in player_spawners + enemy_spawners:
		spawner.get_node("SpawnTimer").autostart = true
		spawner.get_node("SpawnTimer").start()

func _on_resource_timer():
	if not battle_started:
		return
	player_resources += resource_gain_per_sec
	enemy_resources += resource_gain_per_sec
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_resources, enemy_base_hp, enemy_resources)

# Заготовка: обработка победы/поражения
func finish_battle(winner):
	emit_signal("battle_finished", winner)
	# TODO: показать экран победы/поражения

# Спавн юнита на линии
func spawn_unit(team, lane_idx):
	if not battle_started:
		return
	if lane_idx < 0 or lane_idx >= lanes.size():
		return
	var lane = lanes[lane_idx]
	var start_pos = lane.get_node("Start").global_position
	var end_pos = lane.get_node("End").global_position
	var unit = unit_scene.instantiate()
	unit.team = team
	unit.global_position = start_pos
	unit.target_pos = end_pos
	unit.battle_manager = self
	get_parent().add_child(unit)

func unit_reached_base(unit):
	if unit.team == "player":
		enemy_base_hp -= unit.damage
		if enemy_base_hp <= 0:
			finish_battle("player")
	elif unit.team == "enemy":
		player_base_hp -= unit.damage
		if player_base_hp <= 0:
			finish_battle("enemy")

# TODO: добавить обработку UI, победы, расширение логики по мере развития 
