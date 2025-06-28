extends Node

# BattleManager — управляет логикой боя, ресурсами, победой/поражением

var player_energy = 0
var enemy_energy = 0
var energy_gain_per_tick = 5
var energy_tick_time = 2.0

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

var preview_material_valid := preload("res://materials/preview_valid.tres")
var preview_material_invalid := preload("res://materials/preview_invalid.tres")

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
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)
		battle_ui.start_battle.connect(_on_start_battle)
		battle_ui.spawn_unit.connect(_on_spawn_unit_drag)
		battle_ui.build_structure.connect(_on_build_structure_drag)
	# Запустить таймеры спавна
	for spawner in player_spawners + enemy_spawners:
		spawner.get_node("SpawnTimer").autostart = true
		spawner.get_node("SpawnTimer").start()
	# Запустить таймер энергии
	var energy_timer = Timer.new()
	energy_timer.wait_time = energy_tick_time
	energy_timer.autostart = true
	energy_timer.timeout.connect(_on_energy_timer)
	add_child(energy_timer)

	# Добавить горизонтальную линию (разделение поля)
	var line = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(20, 0.1, 0.2)
	line.mesh = box
	line.transform.origin = Vector3(0, 0.05, 0)
	var line_mat = StandardMaterial3D.new()
	line_mat.albedo_color = Color(1,1,1,1)
	line.set_surface_override_material(0, line_mat)
	add_child(line)

	# Добавить ядро игрока (синее)
	var player_core = MeshInstance3D.new()
	player_core.mesh = SphereMesh.new()
	player_core.transform.origin = Vector3(0, 0.5, -13)
	var player_mat = StandardMaterial3D.new()
	player_mat.albedo_color = Color(0.2, 0.6, 1, 1)
	player_core.set_surface_override_material(0, player_mat)
	add_child(player_core)

	# Добавить ядро врага (красное)
	var enemy_core = MeshInstance3D.new()
	enemy_core.mesh = SphereMesh.new()
	enemy_core.transform.origin = Vector3(0, 0.5, 13)
	var enemy_mat = StandardMaterial3D.new()
	enemy_mat.albedo_color = Color(1, 0.2, 0.2, 1)
	enemy_core.set_surface_override_material(0, enemy_mat)
	add_child(enemy_core)

	# Добавить зелёное поле (трава)
	var field = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(20, 30)
	field.mesh = plane
	field.transform.origin = Vector3(0, 0, 0)
	var field_mat = StandardMaterial3D.new()
	field_mat.albedo_color = Color(0.2, 0.7, 0.2, 1.0) # зелёная трава
	field.set_surface_override_material(0, field_mat)
	add_child(field)

	# Добавить стартовый спавнер игрока
	place_spawner("player", "tower", Vector3(-4, 0, -10))
	# Добавить стартовый спавнер врага
	place_spawner("enemy", "tower", Vector3(4, 0, 10))

func _on_start_battle():
	battle_started = true
	if battle_ui:
		battle_ui.start_button.hide()
	# Запустить таймеры спавна
	for spawner in player_spawners + enemy_spawners:
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
	var preview = preload("res://scenes/Spawner.tscn").instantiate()
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
func _on_spawn_unit_drag(screen_pos):
	if not battle_started or player_energy < 10:
		return
	var pos = get_mouse_map_position(screen_pos)
	if is_valid_unit_position(pos):
		spawn_unit_at_pos("player", pos)
		player_energy -= 10
		if battle_ui:
			battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)

# Drag&drop: строительство здания
func _on_build_structure_drag(screen_pos):
	if not battle_started or player_energy < 10:
		return
	var pos = get_mouse_map_position(screen_pos)
	if is_valid_build_position(pos):
		place_spawner("player", "tower", pos)
		player_energy -= 10
		if battle_ui:
			battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)

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

func spawn_unit_at_pos(team, pos):
	var unit = unit_scene.instantiate()
	unit.team = team
	unit.global_position = pos
	unit.target_pos = Vector3(0, 0, 13) # Враг сверху
	unit.battle_manager = self
	add_child(unit)

# ... остальной код ... 
