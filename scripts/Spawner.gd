class_name Spawner
extends Node3D

@export var team: String = "player"
@export var lane_idx: int = 0
@export var unit_type: String = "soldier"
@export var spawner_type: String = "spawner" # 'spawner', 'tower', 'barracks'
@export var spawn_interval: float = 5.0
@export var max_units: int = 10

# Добавляем здоровье спавнеру
@export var health: int = 200
@export var max_health: int = 200

@onready var spawn_timer: Timer = $SpawnTimer
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var mesh_barrack1: MeshInstance3D = $MeshBarrack1
@onready var mesh_barrack2: MeshInstance3D = $MeshBarrack2
@onready var mesh_barrack3: MeshInstance3D = $MeshBarrack3
@onready var mesh_barrack4: MeshInstance3D = $MeshBarrack4

var battle_manager = null

func find_battle_manager():
	var current = get_parent()
	while current:
		if current.has_method("spawn_unit_at_pos"):
			return current
		current = current.get_parent()
	var root = get_tree().current_scene
	if root and root.has_method("spawn_unit_at_pos"):
		return root
	print("⚠️ BattleManager не найден для спавнера ", name, ". Путь поиска завершён.")
	return null

func _ready():
	# Получаем ссылку на BattleManager
	battle_manager = find_battle_manager()
	
	# Добавляем в группу для поиска целей
	add_to_group("spawners")
	
	# Настраиваем здоровье по типу спавнера
	match spawner_type:
		"tower":
			health = 1200         # Увеличено в 4 раза для тактики
			max_health = 1200
		"barracks":
			health = 800          # Увеличено в 3.2 раза для тактики
			max_health = 800
		"collector_facility":
			health = 600          # Увеличено в 4 раза для тактики
			max_health = 600
		"spawner":
			health = 800          # Увеличено в 4 раза для тактики
			max_health = 800
		_:
			health = 800          # Увеличено в 4 раза для тактики
			max_health = 800
	
	# Настройка внешнего вида в зависимости от типа спавнера
	setup_appearance()
	
	# Настройка таймера спавна
	if spawn_timer:
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		
		# Настройка времени спавна в зависимости от типа
		match spawner_type:
			"spawner":
				spawn_timer.wait_time = 4.0  # Базовый спавнер
			"barracks":
				spawn_timer.wait_time = 3.0  # Быстрее спавнит
			"tower":
				spawn_timer.wait_time = 6.0  # Медленнее, но сильнее
			"collector_facility":
				spawn_timer.wait_time = 8.0  # Медленнее, коллекторы дорогие
			_:
				spawn_timer.wait_time = 4.0
	
	# Создаем 3D HP бар для здания
	create_building_health_bar()

func setup_appearance():
	if spawner_type == "tower":
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.7
		cyl.bottom_radius = 0.7
		cyl.height = 2.0
		mesh_instance.mesh = cyl
		mesh_instance.scale = Vector3(1, 1.5, 1)
		mesh_instance.material_override = StandardMaterial3D.new()
		
		# Цвет башни зависит от команды
		if team == "player":
			mesh_instance.material_override.albedo_color = Color(0.2, 0.6, 1, 1)  # Синий
		else:
			mesh_instance.material_override.albedo_color = Color(1, 0.2, 0.2, 1)  # Красный
			
		hide_barracks_meshes()
		
	elif spawner_type == "barracks":
		mesh_instance.visible = false
		show_barracks_meshes()
		
		for m in [mesh_barrack1, mesh_barrack2, mesh_barrack3, mesh_barrack4]:
			if m:
				m.material_override = StandardMaterial3D.new()
				if team == "player":
					m.material_override.albedo_color = Color(0.3, 0.5, 0.8, 1)  # Синеватый
				else:
					m.material_override.albedo_color = Color(0.8, 0.3, 0.3, 1)  # Красноватый
	
	elif spawner_type == "collector_facility":
		# Комплекс коллекторов - особая форма
		var sphere = SphereMesh.new()
		sphere.radius = 0.8
		sphere.height = 1.6
		mesh_instance.mesh = sphere
		mesh_instance.material_override = StandardMaterial3D.new()
		
		# Зеленый цвет для коллекторов
		if team == "player":
			mesh_instance.material_override.albedo_color = Color(0.2, 1.0, 0.2, 1)  # Ярко-зеленый
		else:
			mesh_instance.material_override.albedo_color = Color(0.8, 0.8, 0.2, 1)  # Желто-зеленый
		
		# Добавляем свечение
		mesh_instance.material_override.emission_enabled = true
		mesh_instance.material_override.emission = Color(0.1, 0.5, 0.1)
		
		hide_barracks_meshes()
		
	else:  # spawner
		var box = BoxMesh.new()
		box.size = Vector3(1, 1, 1)
		mesh_instance.mesh = box
		mesh_instance.material_override = StandardMaterial3D.new()
		
		# Цвет спавнера зависит от команды
		if team == "player":
			mesh_instance.material_override.albedo_color = Color(0.2, 0.8, 0.8, 1)  # Бирюзовый
		else:
			mesh_instance.material_override.albedo_color = Color(0.8, 0.2, 0.8, 1)  # Пурпурный
			
		hide_barracks_meshes()

func hide_barracks_meshes():
	if mesh_barrack1: mesh_barrack1.visible = false
	if mesh_barrack2: mesh_barrack2.visible = false
	if mesh_barrack3: mesh_barrack3.visible = false
	if mesh_barrack4: mesh_barrack4.visible = false

func show_barracks_meshes():
	if mesh_barrack1: mesh_barrack1.visible = true
	if mesh_barrack2: mesh_barrack2.visible = true
	if mesh_barrack3: mesh_barrack3.visible = true
	if mesh_barrack4: mesh_barrack4.visible = true

func _on_spawn_timer_timeout():
	if not battle_manager:
		return
		
	# Проверяем, началась ли битва
	if not battle_manager.battle_started:
		return
	
	# Определяем тип юнита для спавна в зависимости от типа спавнера
	var spawn_unit_type = get_spawn_unit_type()
	var cost = battle_manager.get_unit_cost(spawn_unit_type)
	
	# Проверяем энергию команды
	var team_energy = battle_manager.player_energy if team == "player" else battle_manager.enemy_energy
	if team_energy < cost:
		print("Спавнер ", team, ": недостаточно энергии для ", spawn_unit_type)
		return
	
	# Определяем позицию спавна рядом со спавнером
	var spawn_pos = get_spawn_position()
	
	# Спавним юнита
	battle_manager.spawn_unit_at_pos(team, spawn_pos, spawn_unit_type)
	
	# Снимаем энергию
	if team == "player":
		battle_manager.player_energy -= cost
	else:
		battle_manager.enemy_energy -= cost
	
	# Обновляем UI
	battle_manager.update_ui()
	
	print("Спавнер ", team, " создал ", spawn_unit_type, " за ", cost, " энергии")

func get_spawn_unit_type() -> String:
	match spawner_type:
		"tower":
			# Башни спавнят дронов (воздушные юниты)
			return "drone"
		"barracks":
			# Бараки спавнят солдат
			return "soldier"
		"collector_facility":
			# Комплекс коллекторов спавнит коллекторов
			return "collector"
		"spawner":
			# Базовые спавнеры случайно выбирают тип
			var types = ["soldier", "soldier", "tank"]  # Больше шансов на солдат
			return types[randi() % types.size()]
		_:
			return "soldier"

func get_spawn_position() -> Vector3:
	# Спавним юнита рядом со спавнером, но не прямо на нём
	var offset_x = randf_range(-1.5, 1.5)
	var offset_z = randf_range(-1.5, 1.5)
	
	# Для игрока - спавним чуть ближе к центру
	if team == "player":
		offset_z += 1.0  # Сдвигаем к центру поля
	else:
		offset_z -= 1.0  # Сдвигаем к центру поля
	
	return global_position + Vector3(offset_x, 0, offset_z)

# Функция для получения информации о спавнере (для AI анализа)
func get_spawner_info() -> Dictionary:
	return {
		"team": team,
		"type": spawner_type,
		"position": global_position,
		"unit_type": get_spawn_unit_type(),
		"spawn_time": spawn_timer.wait_time if spawn_timer else 4.0
	}

# Функция для уничтожения спавнера (например, от атак)
func destroy_spawner():
	print("💥 Спавнер ", team, " ", spawner_type, " уничтожен!")
	
	# Проверяем условия победы после уничтожения спавнера
	if battle_manager:
		battle_manager.call_deferred("check_victory_conditions")
	
	queue_free()

# Функция для получения урона (юниты могут атаковать здания)
func take_damage(amount: int):
	health -= amount
	update_building_health_bar()  # Обновляем 3D HP бар при получении урона
	print("🏗️ ", spawner_type, " команды ", team, " получил урон: ", amount, " HP: ", health, "/", max_health)
	
	# Визуальный эффект урона (мигание красным)
	if mesh_instance:
		var original_color = mesh_instance.material_override.albedo_color if mesh_instance.material_override else Color.WHITE
		if mesh_instance.material_override:
			mesh_instance.material_override.albedo_color = Color.RED
		await get_tree().create_timer(0.2).timeout
		if mesh_instance and mesh_instance.material_override:
			mesh_instance.material_override.albedo_color = original_color
	
	# Уничтожение при нулевом здоровье
	if health <= 0:
		destroy_spawner()

func create_building_health_bar():
	# Создаем контейнер для HP бара здания
	var health_container = Node3D.new()
	health_container.name = "BuildingHealthBarContainer"
	health_container.position = Vector3(0, 3.5, 0)  # Выше чем у юнитов
	add_child(health_container)
	
	# Фон HP бара (темный)
	var background = MeshInstance3D.new()
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(3.0, 0.4, 0.15)  # Больше чем у юнитов
	background.mesh = bg_mesh
	background.material_override = StandardMaterial3D.new()
	background.material_override.albedo_color = Color(0.1, 0.1, 0.1, 0.9)
	background.material_override.flags_transparent = true
	background.name = "BuildingHealthBarBackground"
	health_container.add_child(background)
	
	# HP бар (цветной)
	var health_bar_mesh = MeshInstance3D.new()
	var hb_mesh = BoxMesh.new()
	hb_mesh.size = Vector3(3.0, 0.35, 0.08)
	health_bar_mesh.mesh = hb_mesh
	health_bar_mesh.material_override = StandardMaterial3D.new()
	health_bar_mesh.material_override.albedo_color = Color.GREEN
	health_bar_mesh.material_override.emission_enabled = true
	health_bar_mesh.material_override.emission = Color.GREEN * 0.4
	health_bar_mesh.name = "BuildingHealthBar3D"
	health_bar_mesh.position = Vector3(0, 0, 0.04)  # Чуть впереди фона
	health_container.add_child(health_bar_mesh)
	
	# Текст HP (Label3D)
	var health_label = Label3D.new()
	health_label.text = str(health) + "/" + str(max_health)
	health_label.font_size = 48  # Меньше чем у юнитов
	health_label.position = Vector3(0, 0.6, 0)
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.modulate = Color.WHITE
	health_label.outline_size = 3
	health_label.outline_modulate = Color.BLACK
	health_label.name = "BuildingHealthLabel3D"
	health_container.add_child(health_label)
	
	# Иконка типа здания
	var type_label = Label3D.new()
	var type_icon = get_building_icon()
	type_label.text = type_icon
	type_label.font_size = 32
	type_label.position = Vector3(0, 1.0, 0)
	type_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	type_label.modulate = Color.YELLOW
	type_label.outline_size = 2
	type_label.outline_modulate = Color.BLACK
	type_label.name = "BuildingTypeLabel3D"
	health_container.add_child(type_label)
	
	# Label3D уже имеют свой billboard, контейнеру он не нужен

func get_building_icon() -> String:
	match spawner_type:
		"tower": return "🗼"
		"barracks": return "🏰"
		"collector_facility": return "⚙️"
		"spawner": return "🏭"
		_: return "🏢"

func update_building_health_bar():
	var health_container = get_node_or_null("BuildingHealthBarContainer")
	if not health_container:
		return
		
	var health_bar_3d = health_container.get_node_or_null("BuildingHealthBar3D")
	var health_label_3d = health_container.get_node_or_null("BuildingHealthLabel3D")
	
	if health_bar_3d and health_label_3d:
		# Обновляем размер HP бара
		var health_percent = float(health) / float(max_health)
		var new_scale_x = health_percent
		health_bar_3d.scale.x = new_scale_x
		
		# Сдвигаем HP бар влево при уменьшении
		var offset_x = -(1.0 - new_scale_x) * 1.5  # 1.5 - половина ширины бара здания
		health_bar_3d.position.x = offset_x
		
		# Меняем цвет в зависимости от здоровья
		if health_percent > 0.7:
			health_bar_3d.material_override.albedo_color = Color.GREEN
			health_bar_3d.material_override.emission = Color.GREEN * 0.4
		elif health_percent > 0.4:
			health_bar_3d.material_override.albedo_color = Color.YELLOW
			health_bar_3d.material_override.emission = Color.YELLOW * 0.4
		elif health_percent > 0.2:
			health_bar_3d.material_override.albedo_color = Color.ORANGE
			health_bar_3d.material_override.emission = Color.ORANGE * 0.4
		else:
			health_bar_3d.material_override.albedo_color = Color.RED
			health_bar_3d.material_override.emission = Color.RED * 0.4
		
		# Обновляем текст
		health_label_3d.text = str(health) + "/" + str(max_health)
		health_label_3d.modulate = Color.WHITE
 
