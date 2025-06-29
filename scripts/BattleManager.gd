extends Node

# BattleManager — управляет логикой боя, ресурсами, победой/поражением

var player_energy = 100  # Начальная энергия игрока
var enemy_energy = 100   # Начальная энергия врага
var energy_gain_per_tick = 10  # Прирост энергии за тик
var energy_tick_time = 1.0     # Время между тиками энергии

var player_base_hp = 100
var enemy_base_hp = 100

var lanes = []
var player_spawners = []
var enemy_spawners = []

signal battle_finished(winner)

var unit_scene = preload("res://scenes/Unit.tscn")
var battle_ui = null
var battle_started = false

var is_building_mode = false
var building_preview = null
var can_build_here = false
var building_cost = 30

# AI система для врага
var enemy_ai_timer: Timer
var enemy_decision_timer: Timer
var enemy_max_soldiers = 3
var enemy_max_tanks = 2
var enemy_max_drones = 2
var enemy_current_soldiers = 0
var enemy_current_tanks = 0
var enemy_current_drones = 0

var enemy_ai: Node = null

func _ready():
	# Получаем UI
	battle_ui = get_node_or_null("BattleUI")
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)
		battle_ui.start_battle.connect(_on_start_battle)
		battle_ui.spawn_unit_drag.connect(_on_spawn_unit_drag)
		battle_ui.build_structure_drag.connect(_on_build_structure_drag)
		battle_ui.spawn_soldier.connect(_on_spawn_soldier)
		battle_ui.build_tower.connect(_on_build_tower)

	# Визуальное поле (трава)
	var field = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(20, 30)
	field.mesh = plane
	field.position = Vector3(0, 0, 0)
	var field_mat = StandardMaterial3D.new()
	field_mat.albedo_color = Color(0.2, 0.7, 0.2, 1.0)
	field.set_surface_override_material(0, field_mat)
	add_child(field)

	# Белая линия (разделитель)
	var line = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(20, 0.1, 0.2)
	line.mesh = box
	line.position = Vector3(0, 0.05, 0)
	var line_mat = StandardMaterial3D.new()
	line_mat.albedo_color = Color(1, 1, 1, 1)
	line.set_surface_override_material(0, line_mat)
	add_child(line)

	# Создаём ядра и стартовые спавнеры
	create_cores_and_spawners()

	# Инициализация AI врага
	init_enemy_ai()

	# Не запускаем бой сразу — ждём нажатия Start Battle
	battle_started = false
	update_hud()

func create_cores_and_spawners():
	# Удаляем старые ядра, если есть
	for node in get_children():
		if node.name == "PlayerCore" or node.name == "EnemyCore":
			node.queue_free()

	# Создаём ядро игрока (синее)
	var player_core_scene = preload("res://scenes/Core.tscn")
	var player_core = player_core_scene.instantiate()
	player_core.name = "PlayerCore"
	player_core.position = Vector3(0, 0.5, -13)
	# Проверяем, что есть MeshInstance3D
	if not player_core.has_node("MeshInstance3D"):
		var mesh = MeshInstance3D.new()
		mesh.mesh = SphereMesh.new()
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.6, 1, 1)
		mesh.set_surface_override_material(0, mat)
		player_core.add_child(mesh)
	add_child(player_core)

	# Создаём ядро врага (красное)
	var enemy_core_scene = preload("res://scenes/Core.tscn")
	var enemy_core = enemy_core_scene.instantiate()
	enemy_core.name = "EnemyCore"
	enemy_core.position = Vector3(0, 0.5, 13)
	if not enemy_core.has_node("MeshInstance3D"):
		var mesh = MeshInstance3D.new()
		mesh.mesh = SphereMesh.new()
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.2, 0.2, 1)
		mesh.set_surface_override_material(0, mat)
		enemy_core.add_child(mesh)
	add_child(enemy_core)

	# Создаём стартовые спавнеры игрока и врага
	create_start_spawner("player", Vector3(-4, 0, -10))
	create_start_spawner("enemy", Vector3(4, 0, 10))

func create_start_spawner(team: String, position: Vector3):
	var spawner_scene = preload("res://scenes/Spawner.tscn")
	var spawner = spawner_scene.instantiate()
	spawner.position = position
	spawner.name = team.capitalize() + "StartSpawner"
	spawner.set("team", team)
	add_child(spawner)
	spawner.add_to_group("spawners")

func _on_start_battle():
	print("Битва началась!")
	battle_started = true
	if battle_ui and battle_ui.has_node("Panel/StartButton"):
		battle_ui.get_node("Panel/StartButton").hide()
	# Запустить таймеры спавна только после старта боя
	for spawner in get_tree().get_nodes_in_group("spawners"):
		if spawner.has_node("SpawnTimer"):
			spawner.get_node("SpawnTimer").autostart = true
			spawner.get_node("SpawnTimer").start()

func _on_energy_timer():
	if not battle_started:
		return
	player_energy += energy_gain_per_tick
	enemy_energy += energy_gain_per_tick
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)

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

func _on_build_pressed():
	if player_energy >= building_cost:
		is_building_mode = true
		create_building_preview()

func create_building_preview():
	if building_preview:
		building_preview.queue_free()
	var preview = unit_scene.instantiate()
	preview.modulate = Color(0.5, 1, 0.5, 0.5) # зелёный по умолчанию
	preview.name = "BuildingPreview"
	preview.set_physics_process(false)
	add_child(preview)
	building_preview = preview

func _unhandled_input(event):
	if is_building_mode:
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			var pos = get_mouse_map_position(event.position)
			if building_preview:
				building_preview.global_position = pos
				can_build_here = is_valid_build_position(pos)
				building_preview.modulate = Color(0.5, 1, 0.5, 0.5) if can_build_here else Color(1, 0.3, 0.3, 0.5)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Начало drag — ничего не делаем
				pass
			else:
				# Отпускание — попытка построить
				if can_build_here and player_energy >= building_cost:
					place_spawner("player", "soldier", building_preview.global_position)
					player_energy -= building_cost
					update_ui()
					building_preview.queue_free()
					building_preview = null
					is_building_mode = false
				else:
					# Нельзя строить — можно добавить звук/эффект
					pass

func get_mouse_map_position(screen_pos):
	var camera = get_viewport().get_camera_3d()
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	var result = space_state.intersect_ray(query)
	if result and result.has("position"):
		return result.position
	return Vector3.ZERO

func is_valid_build_position(pos: Vector3) -> bool:
	# Только на своей половине, не на других зданиях, не вне поля
	var map_width = 20.0
	var map_height = 30.0
	if pos.z > 0:
		return false
	if pos.x < -map_width/2 or pos.x > map_width/2:
		return false
	if pos.z < -map_height/2 or pos.z > 0:
		return false
	# Проверка коллизий с другими зданиями (спавнерами)
	var spawners = get_tree().get_nodes_in_group("spawners")
	for s in spawners:
		if s.global_position.distance_to(pos) < 1.5:
			return false
	return true

# Drag&drop: спавн юнита
func _on_spawn_unit_drag(unit_type, screen_pos):
	if not battle_started or player_energy < 20:
		return
	var pos = get_mouse_map_position(screen_pos)
	if is_valid_unit_position(pos):
		spawn_unit_at_pos("player", pos, unit_type)
		player_energy -= 20
		update_hud()

# Drag&drop: строительство здания
func _on_build_structure_drag(screen_pos):
	if not battle_started or player_energy < 60:
		return
	var pos = get_mouse_map_position(screen_pos)
	if is_valid_build_position(pos):
		place_spawner("player", "tower", pos)
		player_energy -= 60
		update_hud()

func is_valid_unit_position(pos: Vector3) -> bool:
	# Только на своей половине, не на зданиях, не вне поля
	var map_width = 20.0
	var map_height = 30.0
	if pos.z > 0:
		return false
	if pos.x < -map_width/2 or pos.x > map_width/2:
		return false
	if pos.z < -map_height/2 or pos.z > 0:
		return false
	# Не на зданиях
	var spawners = get_tree().get_nodes_in_group("spawners")
	for s in spawners:
		if s.global_position.distance_to(pos) < 2.5:
			return false
	return true

func spawn_unit_at_pos(team, pos, unit_type="soldier"):
	if not can_spawn_unit(team, unit_type):
		print("Недостаточно энергии или превышен лимит!")
		return
	var unit = unit_scene.instantiate()
	unit.team = team
	unit.unit_type = unit_type
	unit.global_position = pos
	if team == "player":
		unit.target_pos = Vector3(0, 0, 13)
		player_energy -= 20
	else:
		unit.target_pos = Vector3(0, 0, -13)
		enemy_energy -= 20
	unit.battle_manager = self
	add_child(unit)
	unit.add_to_group("units")
	update_hud()

# Добавляю функцию update_ui, если её нет
func update_ui():
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)

# Добавляю функцию place_spawner, если её нет
func place_spawner(team: String, spawner_type: String, position: Vector3):
	if not can_build_structure(team, spawner_type):
		print("Недостаточно энергии для постройки!")
		return
	var spawner = unit_scene.instantiate()
	spawner.team = team
	spawner.spawner_type = spawner_type
	spawner.global_position = position
	add_child(spawner)
	spawner.add_to_group("spawners")
	if team == "player":
		player_energy -= 60
	else:
		enemy_energy -= 60
	update_hud()

# ... остальной код ... 

func init_enemy_ai():
	# Таймер для принятия решений AI
	enemy_decision_timer = Timer.new()
	enemy_decision_timer.wait_time = 3.0  # Решение каждые 3 секунды
	enemy_decision_timer.autostart = true
	enemy_decision_timer.timeout.connect(_on_enemy_ai_decision)
	add_child(enemy_decision_timer)
	
	# Таймер для спавна юнитов врага
	enemy_ai_timer = Timer.new()
	enemy_ai_timer.wait_time = 5.0  # Спавн каждые 5 секунд
	enemy_ai_timer.autostart = true
	enemy_ai_timer.timeout.connect(_on_enemy_ai_spawn)
	add_child(enemy_ai_timer)

func _on_enemy_ai_decision():
	if not battle_started:
		return
	
	print("AI врага принимает решение...")
	
	# Подсчитываем текущих юнитов врага
	count_enemy_units()
	
	# Логика принятия решений
	var decision = make_enemy_decision()
	execute_enemy_decision(decision)

func count_enemy_units():
	enemy_current_soldiers = 0
	enemy_current_tanks = 0
	enemy_current_drones = 0
	
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit.team == "enemy":
			match unit.unit_type:
				"soldier":
					enemy_current_soldiers += 1
				"tank":
					enemy_current_tanks += 1
				"drone":
					enemy_current_drones += 1
	
	print("Вражеские юниты: солдаты=", enemy_current_soldiers, 
		  ", танки=", enemy_current_tanks, 
		  ", дроны=", enemy_current_drones)

func make_enemy_decision() -> Dictionary:
	var decision = {
		"action": "none",
		"unit_type": "",
		"position": Vector3.ZERO
	}
	
	# Если мало солдат - создаем солдат
	if enemy_current_soldiers < enemy_max_soldiers and enemy_energy >= 20:
		decision.action = "spawn"
		decision.unit_type = "soldier"
		return decision
	
	# Если есть солдаты, но мало танков - создаем танк
	if enemy_current_soldiers > 0 and enemy_current_tanks < enemy_max_tanks and enemy_energy >= 50:
		decision.action = "spawn"
		decision.unit_type = "tank"
		return decision
	
	# Если есть танки, но мало дронов - создаем дрон
	if enemy_current_tanks > 0 and enemy_current_drones < enemy_max_drones and enemy_energy >= 35:
		decision.action = "spawn"
		decision.unit_type = "drone"
		return decision
	
	# Если много ресурсов - строим башню
	if enemy_energy >= 60:
		decision.action = "build"
		decision.unit_type = "tower"
		return decision
	
	return decision

func execute_enemy_decision(decision: Dictionary):
	match decision.action:
		"spawn":
			spawn_enemy_unit(decision.unit_type)
		"build":
			build_enemy_structure(decision.unit_type)
		"none":
			print("AI врага: нет действий")

func spawn_enemy_unit(unit_type: String):
	var cost = get_unit_cost(unit_type)
	if enemy_energy < cost:
		print("AI врага: недостаточно энергии для ", unit_type)
		return
	
	# Выбираем случайную позицию на вражеской стороне
	var spawn_pos = get_random_enemy_spawn_position()
	
	spawn_unit_at_pos("enemy", spawn_pos, unit_type)
	enemy_energy -= cost
	
	print("AI врага создал ", unit_type, " за ", cost, " энергии")
	
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)

func build_enemy_structure(structure_type: String):
	var cost = get_structure_cost(structure_type)
	if enemy_energy < cost:
		print("AI врага: недостаточно энергии для постройки ", structure_type)
		return
	
	# Выбираем позицию для постройки на вражеской стороне
	var build_pos = get_random_enemy_build_position()
	
	place_spawner("enemy", structure_type, build_pos)
	enemy_energy -= cost
	
	print("AI врага построил ", structure_type, " за ", cost, " энергии")
	
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)

func get_unit_cost(unit_type: String) -> int:
	match unit_type:
		"soldier":
			return 20
		"tank":
			return 50
		"drone":
			return 35
		_:
			return 20

func get_structure_cost(structure_type: String) -> int:
	match structure_type:
		"tower":
			return 60
		"barracks":
			return 80
		_:
			return 60

func get_random_enemy_spawn_position() -> Vector3:
	# Случайная позиция на вражеской стороне (z > 0)
	var x = randf_range(-8.0, 8.0)
	var z = randf_range(5.0, 12.0)
	return Vector3(x, 0, z)

func get_random_enemy_build_position() -> Vector3:
	# Позиция для постройки на вражеской стороне
	var x = randf_range(-6.0, 6.0)
	var z = randf_range(8.0, 12.0)
	return Vector3(x, 0, z)

func _on_enemy_ai_spawn():
	if not battle_started:
		return
	
	# Автоматический спавн базовых юнитов
	if enemy_energy >= 20:
		spawn_enemy_unit("soldier")

# ... остальной код ... 

func _on_spawn_soldier():
	print("Кнопка спавна солдата нажата!")
	# Спавн юнита-солдата на первой линии, стартовая позиция игрока
	var lane = lanes[0]
	var start_pos = lane.get_node("Start").global_position if lane.has_node("Start") else lane.global_position
	spawn_unit_at_pos("player", start_pos, "soldier")

func _on_build_tower():
	print("Кнопка постройки башни нажата!")
	# Строим башню рядом с базой игрока (слева от центра поля)
	var build_pos = Vector3(-6, 0, -12)
	place_spawner("player", "tower", build_pos)

# ... остальной код ... 

func update_hud():
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)

func can_spawn_unit(team, unit_type):
	if team == "player":
		if player_energy < 20:
			return false
		# Можно добавить лимиты
	else:
		if enemy_energy < 20:
			return false
	return true

func can_build_structure(team, structure_type):
	if team == "player":
		if player_energy < 60:
			return false
	else:
		if enemy_energy < 60:
			return false
	return true

# ... остальной код ... 
 
