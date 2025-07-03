class_name Unit
extends CharacterBody3D

@export var team: String = "player"
@export var unit_type: String = "soldier" # soldier, tank, drone
@export var speed: float = 100.0
@export var health: int = 100
@export var max_health: int = 100
@export var damage: int = 20
@export var target_pos: Vector3
var battle_manager = null

var attack_range: float = 3.0
var attack_cooldown: float = 1.0
var attack_timer: float = 0.0
var target: Node = null

# Система зон восприятия и приоритетов
var enemy_detection_range: float = 8.0  # Зона восприятия вражеских войск
var building_search_range: float = 12.0  # Зона поиска зданий
var current_target_type: String = "building"  # "building" или "enemy"
var enemy_target: Node = null  # Текущий вражеский юнит
var building_target: Node = null  # Текущее здание

# Оптимизация поиска целей
var target_search_timer: float = 0.0
var target_search_interval: float = 0.5  # Ищем цели раз в 0.5 секунды
var last_target_search_time: float = 0.0

# Визуальная модель юнита
var current_mesh: MeshInstance3D = null

# Специальные переменные для коллекторов
var target_crystal = null
var is_capturing = false
var capture_progress = 0.0
var has_transformed = false

@onready var attack_area: Area3D = null
@onready var health_bar: Label = null

func _ready():
	# Добавляем юнита в группу для поиска целей
	add_to_group("units")
	
	# Создаем AttackArea если его нет
	if not has_node("AttackArea"):
		attack_area = Area3D.new()
		attack_area.name = "AttackArea"
		var collision_shape = CollisionShape3D.new()
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = 2.0  # Радиус атаки
		collision_shape.shape = sphere_shape
		attack_area.add_child(collision_shape)
		add_child(attack_area)
	else:
		attack_area = get_node("AttackArea")
	
	# Создаем HealthBar если его нет
	if not has_node("HealthBar"):
		health_bar = Label.new()
		health_bar.name = "HealthBar"
		add_child(health_bar)
	else:
		health_bar = get_node("HealthBar")
	
	# Создаем визуальную модель юнита
	create_unit_visual()
	
	# Тип и параметры (МАКСИМАЛЬНО МЕДЛЕННЫЕ СКОРОСТИ для глубокого тактического геймплея)
	if unit_type == "soldier":
		speed = 3            # МАКСИМАЛЬНО МЕДЛЕННО (было 15)
		health = 300         # Увеличено в 3 раза для тактики
		max_health = 300
		damage = 25
		enemy_detection_range = 10.0  # Хорошая зона восприятия
		building_search_range = 15.0
	elif unit_type == "tank":
		speed = 2            # МАКСИМАЛЬНО МЕДЛЕННО (было 10)
		health = 800         # Увеличено в 3+ раза для тактики
		max_health = 800
		damage = 35
		enemy_detection_range = 8.0   # Средняя зона восприятия
		building_search_range = 12.0
	elif unit_type == "drone":
		speed = 4           # МАКСИМАЛЬНО МЕДЛЕННО (было 20)
		health = 240         # Увеличено в 3 раза для тактики
		max_health = 240
		damage = 15
		enemy_detection_range = 12.0  # Отличная зона восприятия (дрон)
		building_search_range = 18.0
	elif unit_type == "elite_soldier":
		speed = 4           # МАКСИМАЛЬНО МЕДЛЕННО (было 18)
		health = 450         # Увеличено в 3+ раза для тактики
		max_health = 450
		damage = 40
		enemy_detection_range = 12.0  # Отличная зона восприятия
		building_search_range = 16.0
	elif unit_type == "crystal_mage":
		speed = 2            # МАКСИМАЛЬНО МЕДЛЕННО (было 12)
		health = 320         # Увеличено в 3+ раза для тактики
		max_health = 320
		damage = 45
		attack_range = 5.0
		enemy_detection_range = 14.0  # Очень хорошая зона восприятия (маг)
		building_search_range = 20.0
	elif unit_type == "heavy_tank":
		speed = 1            # МАКСИМАЛЬНО МЕДЛЕННО (было 8)
		health = 1200        # Увеличено в 2.7 раза для тактики
		max_health = 1200
		damage = 60
		enemy_detection_range = 6.0   # Ограниченная зона восприятия (тяжелый танк)
		building_search_range = 10.0
	elif unit_type == "collector":
		speed = 2           # МАКСИМАЛЬНО МЕДЛЕННО (было 18)
		health = 280         # Увеличено почти в 3 раза для тактики
		max_health = 280
		damage = 0           # Не атакуют
		enemy_detection_range = 5.0   # Ограниченная зона восприятия
		building_search_range = 8.0
		
	# Безопасно подключаем AttackArea
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)
	
	# Создаем 3D HP бар
	create_3d_health_bar()
	
	# Создаем визуальные зоны восприятия (для отладки)
	create_detection_zones()
	
	# Безопасно обновляем HealthBar
	if health_bar and health_bar is Label:
		update_health_display()

func create_unit_visual():
	# Создаем визуальную модель для юнита
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "UnitMesh"
	add_child(mesh_instance)
	
	# Уникальная форма для каждого типа юнита
	match unit_type:
		"soldier":
			var capsule = CapsuleMesh.new()
			capsule.radius = 0.3
			capsule.height = 1.0
			mesh_instance.mesh = capsule
		"tank":
			var box = BoxMesh.new()
			box.size = Vector3(1.2, 0.5, 1.6)
			mesh_instance.mesh = box
		"drone":
			var sphere = SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			mesh_instance.mesh = sphere
		"collector":
			var cylinder = CylinderMesh.new()
			cylinder.top_radius = 0.35
			cylinder.bottom_radius = 0.35
			cylinder.height = 1.0
			mesh_instance.mesh = cylinder
		"elite_soldier":
			var capsule = CapsuleMesh.new()
			capsule.radius = 0.4
			capsule.height = 1.4
			mesh_instance.mesh = capsule
		"crystal_mage":
			var prism = PrismMesh.new()
			prism.size = Vector3(0.7, 1.3, 0.7)
			mesh_instance.mesh = prism
		"heavy_tank":
			var box = BoxMesh.new()
			box.size = Vector3(1.6, 0.7, 2.0)
			mesh_instance.mesh = box
		"hero":
			var capsule = CapsuleMesh.new()
			capsule.radius = 0.6
			capsule.height = 2.0
			mesh_instance.mesh = capsule
		_:
			var capsule = CapsuleMesh.new()
			capsule.radius = 0.3
			capsule.height = 1.0
			mesh_instance.mesh = capsule
	
	# Цвет и эффекты — по команде (как раньше)
	var material = StandardMaterial3D.new()
	if team == "player":
		match unit_type:
			"collector":
				material.albedo_color = Color(0.2, 1.0, 0.2, 1)
				material.emission = Color(0.1, 0.7, 0.1)
			"crystal_mage":
				material.albedo_color = Color(0.7, 0.2, 1, 1)
				material.emission = Color(0.5, 0.1, 0.7)
			"heavy_tank":
				material.albedo_color = Color(0.2, 0.6, 1, 1)
				material.emission = Color(0.1, 0.3, 0.5)
			"hero":
				material.albedo_color = Color(1, 1, 0.2, 1)
				material.emission = Color(1, 1, 0.2)
			_:
				material.albedo_color = Color(0.2, 0.6, 1, 1)
				material.emission = Color(0.1, 0.3, 0.5)
		material.emission_enabled = true
		material.emission_energy = 1.0
		material.outline_size = 0.05
		material.outline_color = Color(0.2, 0.6, 1, 1)
	else:
		match unit_type:
			"collector":
				material.albedo_color = Color(1, 1, 0.2, 1)
				material.emission = Color(0.7, 0.7, 0.1)
			"crystal_mage":
				material.albedo_color = Color(1, 0.2, 0.7, 1)
				material.emission = Color(0.7, 0.1, 0.5)
			"heavy_tank":
				material.albedo_color = Color(1, 0.05, 0.05, 1)
				material.emission = Color(0.5, 0.1, 0.1)
			"hero":
				material.albedo_color = Color(1, 0.7, 0.2, 1)
				material.emission = Color(1, 0.5, 0.1)
			_:
				material.albedo_color = Color(1, 0.05, 0.05, 1)
				material.emission = Color(0.5, 0.1, 0.1)
		material.emission_enabled = true
		material.emission_energy = 1.0
		material.outline_size = 0.05
		material.outline_color = Color(1, 0.05, 0.05, 1)
	mesh_instance.material_override = material
	current_mesh = mesh_instance
	
	# Подпись типа юнита (Label3D)
	var label = Label3D.new()
	label.text = unit_type
	label.font_size = 32
	label.position = Vector3(0, 1.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if team == "player":
		label.modulate = Color(0.2, 0.6, 1, 1)
	else:
		label.modulate = Color(1, 0.05, 0.05, 1)
	label.outline_size = 4
	label.outline_modulate = Color.BLACK
	label.name = "TypeLabel3D"
	add_child(label)

func _physics_process(_delta):
	if health <= 0:
		queue_free()
		return
	
	# Специальное поведение коллекторов
	if unit_type == "collector":
		handle_collector_behavior(_delta)
		return
		
	if target_pos and global_position.distance_to(target_pos) < 1.5:
		if battle_manager:
			battle_manager.unit_reached_base(self)
		queue_free()
		return
	
	# Заменяем проверку crystal_system на territory_system
	if battle_manager and battle_manager.territory_system:
		battle_manager.territory_system.check_territory_interaction(global_position, team)
	
	attack_timer += _delta
	target_search_timer += _delta
	
	# Проверяем валидность текущих целей
	if enemy_target and (not is_instance_valid(enemy_target) or enemy_target.health <= 0):
		enemy_target = null
	if building_target and (not is_instance_valid(building_target) or building_target.health <= 0):
		building_target = null
	
	# Система приоритетов целей
	update_target_priorities()
	
	# Атакуем текущую цель
	if target and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist > attack_range:
			# Цель далеко - движемся к ней
			move_towards_target()
		else:
			# Цель близко - атакуем
			if attack_timer > attack_cooldown:
				attack()
				attack_timer = 0.0
	else:
		# Нет цели - ищем новые цели
		if target_search_timer >= target_search_interval:
			find_new_targets()
			target_search_timer = 0.0
		
		# Если целей нет - идем к вражескому ядру
		if not target:
			move_towards_base()

func update_target_priorities():
	"""Обновляет приоритеты целей на основе зоны восприятия"""
	# Проверяем, есть ли враги в зоне восприятия
	var nearby_enemy = find_nearest_enemy_in_range(enemy_detection_range)
	
	if nearby_enemy:
		# Есть враг в зоне восприятия - переключаемся на него
		if current_target_type != "enemy" or enemy_target != nearby_enemy:
			current_target_type = "enemy"
			enemy_target = nearby_enemy
			target = enemy_target
			print(team, " ", unit_type, " переключился на вражеского юнита в зоне восприятия")
	else:
		# Нет врагов в зоне восприятия - возвращаемся к зданиям
		if current_target_type != "building" or not building_target:
			current_target_type = "building"
			target = building_target
			if building_target:
				print(team, " ", unit_type, " вернулся к атаке здания")

func find_nearest_enemy_in_range(range_limit: float) -> Node:
	"""Ищет ближайшего врага в заданном радиусе"""
	var nearest_enemy = null
	var nearest_distance = range_limit
	
	var enemies = get_tree().get_nodes_in_group("units")
	for enemy in enemies:
		if enemy == self or enemy.team == team:
			continue  # Пропускаем себя и союзников
		
		if enemy.health <= 0:
			continue  # Пропускаем мертвых
			
		var distance = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_enemy = enemy
			nearest_distance = distance
	
	return nearest_enemy

func find_new_targets():
	"""Ищет новые цели для зданий и врагов"""
	# Ищем ближайшее здание
	var nearest_building = null
	var nearest_building_distance = building_search_range
	
	var enemy_spawners = get_tree().get_nodes_in_group("spawners")
	for spawner in enemy_spawners:
		if spawner.team == team:
			continue  # Пропускаем союзные здания
			
		if not "health" in spawner or spawner.health <= 0:
			continue  # Пропускаем разрушенные здания
			
		var distance = global_position.distance_to(spawner.global_position)
		if distance < nearest_building_distance:
			nearest_building = spawner
			nearest_building_distance = distance
	
	# Обновляем цель здания
	if nearest_building and building_target != nearest_building:
		building_target = nearest_building
		if current_target_type == "building":
			target = building_target
			print(team, " ", unit_type, " нашел новое здание для атаки")

func move_towards_target():
	"""Движение к текущей цели (враг или здание)"""
	if target and is_instance_valid(target):
		var dir = (target.global_position - global_position).normalized()
		velocity = dir * speed
		move_and_slide()

func move_towards_base():
	"""Движение к вражескому ядру (основная цель)"""
	if target_pos:
		var dir = (target_pos - global_position).normalized()
		velocity = dir * speed
		move_and_slide()

func _on_attack_area_body_entered(body):
	"""Обработка входа врага в зону атаки"""
	if body != self and body.has_method("take_damage") and body.team != team:
		# Если это вражеский юнит - устанавливаем его как приоритетную цель
		if body.has_method("get_current_mesh"):  # Это юнит
			enemy_target = body
			current_target_type = "enemy"
			target = enemy_target
			print(team, " ", unit_type, " обнаружил вражеского юнита в зоне атаки")

func _on_attack_area_body_exited(body):
	"""Обработка выхода врага из зоны атаки"""
	if enemy_target == body:
		enemy_target = null
		# Возвращаемся к зданию или ищем новую цель
		if building_target:
			current_target_type = "building"
			target = building_target
		else:
			target = null

func attack():
	if target and target.has_method("take_damage"):
		target.take_damage(damage)
		print(team, " ", unit_type, " атакует ", target.team, " ", target.unit_type, " урон: ", damage)
		
		# Визуальный эффект атаки через систему эффектов
		if battle_manager and battle_manager.effect_system:
			battle_manager.effect_system.create_hit_effect(target.global_position, damage)
		
		# Звук атаки
		if battle_manager and battle_manager.audio_system:
			battle_manager.audio_system.play_unit_attack_sound(global_position)
		
		# Визуальный эффект атаки на самом юните
		var current_mesh = get_current_mesh()
		if current_mesh and current_mesh.material_override:
			current_mesh.material_override.albedo_color = Color.WHITE
			await get_tree().create_timer(0.1).timeout
			# Возвращаем исходный цвет
			if team == "player":
				current_mesh.material_override.albedo_color = Color(0.2, 0.6, 1, 1)
			else:
				current_mesh.material_override.albedo_color = Color(1, 0.2, 0.2, 1)

func take_damage(amount: int):
	health -= amount
	update_health_display()
	update_3d_health_bar()
	
	print(team, " ", unit_type, " получил урон: ", amount, " HP: ", health)
	
	# Визуальный эффект получения урона
	var current_mesh = get_current_mesh()
	if current_mesh and current_mesh.material_override:
		current_mesh.material_override.albedo_color = Color.RED
		await get_tree().create_timer(0.2).timeout
		# Возвращаем исходный цвет
		if team == "player":
			current_mesh.material_override.albedo_color = Color(0.2, 0.6, 1, 1)
		else:
			current_mesh.material_override.albedo_color = Color(1, 0.2, 0.2, 1)
	
	if health <= 0:
		print(team, " ", unit_type, " уничтожен!")
		
		# Эффект взрыва при смерти
		if battle_manager and battle_manager.effect_system:
			battle_manager.effect_system.create_explosion_effect(global_position, team)
		
		# Звук смерти
		if battle_manager and battle_manager.audio_system:
			battle_manager.audio_system.play_unit_death_sound(global_position)
		
		# Уведомление о смерти юнита
		if battle_manager and battle_manager.notification_system:
			battle_manager.notification_system.show_unit_killed(unit_type, team)
		
		# Регистрируем в статистике
		if battle_manager and battle_manager.statistics_system:
			battle_manager.statistics_system.register_unit_killed(team, unit_type)
		
		# Проверяем условия победы после смерти юнита
		if battle_manager:
			battle_manager.call_deferred("check_victory_conditions")
		
		queue_free()

func update_health_display():
	if health_bar:
		if health_bar is Label:
			if unit_type == "collector" and is_capturing:
				# Показываем прогресс захвата для коллекторов
				var capture_time = float(target_crystal.max_capture_time) if target_crystal and target_crystal.has("max_capture_time") else 5.0
				var progress_percent = int(capture_progress * 100 / capture_time)
				health_bar.text = "💎 " + str(progress_percent) + "%"
				health_bar.modulate = Color.ORANGE
			else:
				# Красивое отображение здоровья с эмодзи
				var health_percent = float(health) / float(max_health)
				var health_emoji = get_health_emoji(health_percent)
				health_bar.text = health_emoji + " " + str(health) + "/" + str(max_health)
				
				# Цветовая индикация здоровья
				if health_percent > 0.7:
					health_bar.modulate = Color.GREEN
				elif health_percent > 0.3:
					health_bar.modulate = Color.YELLOW
				else:
					health_bar.modulate = Color.RED

func get_health_emoji(health_percent: float) -> String:
	# (documentation comment)
	if health_percent > 0.8:
		return "💚"
	elif health_percent > 0.6:
		return "💛"
	elif health_percent > 0.3:
		return "🧡"
	else:
		return "❤️"

func handle_collector_behavior(_delta):
	# Если коллектор уже превратился в турель
	if has_transformed:
		# Ведем себя как статичная турель
		speed = 0
		attack_timer += _delta
		# Оптимизация: ищем цели не каждый кадр
		if target_search_timer >= target_search_interval:
			find_new_targets()
		if target and is_instance_valid(target):
			if attack_timer > attack_cooldown:
				attack()
				attack_timer = 0.0
		return
	
	# Если мы захватываем кристалл
	if is_capturing and target_crystal:
		capture_progress += _delta
		update_health_display()
		update_3d_health_bar()  # Обновляем 3D HP бар при захвате
		
		# Проверяем, завершен ли захват
		var capture_time = float(target_crystal.max_capture_time) if target_crystal and target_crystal.has("max_capture_time") else 5.0
		if capture_progress >= capture_time:
			complete_crystal_capture()
		
		# Можем защищаться во время захвата
		attack_timer += _delta
		# Оптимизация: ищем цели не каждый кадр
		if target_search_timer >= target_search_interval:
			find_new_targets()
		if target and is_instance_valid(target):
			if attack_timer > attack_cooldown:
				attack()
				attack_timer = 0.0
		return
	
	# Ищем ближайший свободный кристалл
	if not target_crystal:
		find_target_crystal()
	
	# Двигаемся к целевому кристаллу
	if target_crystal:
		if not is_inside_tree() or not target_crystal:
			return
		if not ("position" in target_crystal and is_instance_valid(self)):
			return
		var crystal_pos = target_crystal.position
		var distance = global_position.distance_to(crystal_pos)
		
		if distance < target_crystal.control_radius:
			# Начинаем захват
			start_crystal_capture()
		else:
			# Движемся к кристаллу
			var dir = (crystal_pos - global_position).normalized()
			velocity = dir * speed
			move_and_slide()
	else:
		# Если нет цели, двигаемся к вражеской базе
		if target_pos:
			move_towards_target()

func find_target_crystal():
	if not battle_manager or not battle_manager.territory_system:
		return
		
	# Получаем территории вместо кристаллов
	var territories = battle_manager.territory_system.get_territory_info()
	var best_crystal = null
	var closest_distance = 999999.0
	
	for territory in territories:
		# Ищем нейтральные или вражеские кристаллы
		if territory.owner == "neutral" or territory.owner != team:
			# Проверяем, нет ли уже коллектора на этом кристалле
			if not territory.has("assigned_collector"):
				var distance = global_position.distance_to(territory.position)
				if distance < closest_distance:
					closest_distance = distance
					best_crystal = territory
	
	if best_crystal:
		target_crystal = best_crystal
		# Помечаем кристалл как занятый
		target_crystal["assigned_collector"] = self
		var crystal_type_name = get_crystal_type_name(target_crystal.type)
		print("🎯 Коллектор ", team, " нацелился на кристалл ", target_crystal.id, " (", crystal_type_name, ")")

func start_crystal_capture():
	is_capturing = true
	capture_progress = 0.0
	speed = 0  # Останавливаемся для захвата
	var crystal_type_name = get_crystal_type_name(target_crystal.type)
	print("⏳ Коллектор ", team, " начал захват кристалла ", target_crystal.id, " (", crystal_type_name, ")")

func complete_crystal_capture():
	if not target_crystal or not battle_manager or not battle_manager.territory_system:
		return
		
	# Захватываем территорию вместо кристалла
	battle_manager.territory_system.force_capture_territory(target_crystal.id, team)
	
	# Создаем генератор с турелью на кристалле
	create_crystal_generator_turret()
	
	var crystal_type_name = get_crystal_type_name(target_crystal.type)
	print("🏰 Коллектор ", team, " захватил кристалл ", target_crystal.id, " (", crystal_type_name, ") и создал генератор с турелью!")

func create_crystal_generator_turret():
	has_transformed = true
	is_capturing = false
	speed = 0
	
	# Меняем внешний вид на генератор с турелью
	if has_node("MeshInstance3D_Cylinder"):
		var mesh = get_node("MeshInstance3D_Cylinder")
		mesh.visible = false
	
	# Создаем основание генератора
	var generator_base = MeshInstance3D.new()
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 1.2
	base_mesh.bottom_radius = 1.5
	base_mesh.height = 0.8
	generator_base.mesh = base_mesh
	generator_base.position = Vector3(0, 0.4, 0)
	
	# Материал генератора
	var base_material = StandardMaterial3D.new()
	if team == "player":
		base_material.albedo_color = Color(0.1, 0.4, 0.8, 1)
		base_material.emission = Color(0.05, 0.2, 0.4)
	else:
		base_material.albedo_color = Color(0.8, 0.1, 0.1, 1)
		base_material.emission = Color(0.4, 0.05, 0.05)
	
	base_material.emission_enabled = true
	base_material.emission_energy = 1.5
	generator_base.material_override = base_material
	generator_base.name = "GeneratorBase"
	add_child(generator_base)
	
	# Создаем турель на генераторе
	var turret_mesh = MeshInstance3D.new()
	var turret_cyl = CylinderMesh.new()
	turret_cyl.top_radius = 0.4
	turret_cyl.bottom_radius = 0.6
	turret_cyl.height = 1.2
	turret_mesh.mesh = turret_cyl
	turret_mesh.position = Vector3(0, 1.2, 0)
	
	# Материал турели
	var turret_material = StandardMaterial3D.new()
	if team == "player":
		turret_material.albedo_color = Color(0.2, 0.6, 1, 1)
		turret_material.emission = Color(0.1, 0.3, 0.5)
	else:
		turret_material.albedo_color = Color(1, 0.2, 0.2, 1)
		turret_material.emission = Color(0.5, 0.1, 0.1)
	
	turret_material.emission_enabled = true
	turret_material.emission_energy = 2.0
	turret_mesh.material_override = turret_material
	turret_mesh.name = "Turret"
	add_child(turret_mesh)
	
	# Создаем энергетические кабели от кристалла к генератору
	create_energy_cables()
	
	# Улучшаем характеристики (питание от кристалла)
	var crystal_bonus = get_crystal_power_bonus()
	damage = 30 + crystal_bonus.damage  # Базовый урон + бонус от кристалла
	attack_range = 5.0 + crystal_bonus.range  # Базовая дальность + бонус
	attack_cooldown = 1.0 - crystal_bonus.speed  # Базовый кулдаун - бонус скорости
	health = 300 + crystal_bonus.health  # Базовое здоровье + бонус
	max_health = health
	
	# Обновляем тип юнита
	unit_type = "crystal_generator_turret"
	
	# Обновляем группы
	remove_from_group("units")
	add_to_group("crystal_generators")
	add_to_group("turrets")
	
	# Запускаем генерацию ресурсов от кристалла
	start_crystal_power_generation()
	
	update_health_display()
	update_3d_health_bar()

func create_energy_cables():
	"""Создает визуальные энергетические кабели от кристалла к генератору"""
	if not is_inside_tree() or not target_crystal:
		return
	
	# Создаем кабель
	var cable = MeshInstance3D.new()
	var cable_mesh = CylinderMesh.new()
	cable_mesh.top_radius = 0.05
	cable_mesh.bottom_radius = 0.05
	
	# Вычисляем длину и направление кабеля
	if not ("position" in target_crystal and is_instance_valid(self)):
		return
	var crystal_pos = target_crystal.position
	var generator_pos = global_position
	var direction = (generator_pos - crystal_pos).normalized()
	var distance = generator_pos.distance_to(crystal_pos)
	
	cable_mesh.height = distance
	cable.mesh = cable_mesh
	
	# Позиционируем кабель между кристаллом и генератором
	var mid_point = (crystal_pos + generator_pos) / 2.0
	cable.global_position = mid_point
	
	# Поворачиваем кабель в нужном направлении
	var up_vector = Vector3.UP
	var rotation_axis = up_vector.cross(direction).normalized()
	var rotation_angle = acos(up_vector.dot(direction))
	cable.rotate(rotation_axis, rotation_angle)
	
	# Материал кабеля с пульсирующим свечением
	var cable_material = StandardMaterial3D.new()
	cable_material.albedo_color = Color(0.8, 0.9, 1.0, 0.8)
	cable_material.emission_enabled = true
	cable_material.emission = Color(0.4, 0.6, 1.0)
	cable_material.emission_energy = 1.5
	cable_material.flags_transparent = true
	cable.material_override = cable_material
	cable.name = "EnergyCable"
	
	# Добавляем кабель в сцену
	get_parent().add_child(cable)

func get_crystal_power_bonus() -> Dictionary:
	"""Возвращает бонусы от типа кристалла для генератора"""
	var bonus = {
		"damage": 0,
		"range": 0,
		"speed": 0,
		"health": 0,
		"resource_bonus": 0
	}
	
	if not target_crystal:
		return bonus
	
	match target_crystal.type:
		0:  # MAIN_CRYSTAL
			bonus.damage = 20
			bonus.range = 2.0
			bonus.health = 100
			bonus.resource_bonus = 5
		1:  # ENERGY_CRYSTAL
			bonus.damage = 15
			bonus.speed = 0.2
			bonus.health = 50
			bonus.resource_bonus = 10
		2:  # UNSTABLE_CRYSTAL
			bonus.damage = 25
			bonus.range = 1.5
			bonus.speed = 0.3
			bonus.health = 75
			bonus.resource_bonus = 15
		3:  # VOID_CRYSTAL
			bonus.damage = 30
			bonus.range = 3.0
			bonus.speed = 0.4
			bonus.health = 100
			bonus.resource_bonus = 20
	
	return bonus

func start_crystal_power_generation():
	"""Запускает генерацию ресурсов от кристалла"""
	if not target_crystal or not battle_manager:
		return
	
	# Создаем таймер для генерации ресурсов
	var resource_timer = Timer.new()
	resource_timer.wait_time = 2.0  # Генерируем ресурсы каждые 2 секунды
	resource_timer.autostart = true
	resource_timer.timeout.connect(_on_crystal_resource_generation)
	resource_timer.name = "CrystalResourceTimer"
	add_child(resource_timer)
	
	print("⚡ Генератор на кристалле ", target_crystal.id, " начал производство ресурсов!")

func _on_crystal_resource_generation():
	"""Генерирует ресурсы от кристалла"""
	if not target_crystal or not battle_manager:
		return
	
	var bonus = get_crystal_power_bonus()
	var resource_amount = 5 + bonus.resource_bonus  # Базовые 5 + бонус от кристалла
	
	# Добавляем ресурсы команде
	if battle_manager.has_method("add_resources"):
		battle_manager.add_resources(team, resource_amount, 0)  # Энергия, кристаллы
	
	# Визуальный эффект генерации
	if battle_manager and battle_manager.effect_system:
		battle_manager.effect_system.create_resource_generation_effect(global_position, resource_amount)
	
	# Обновляем HP бар с информацией о генерации
	update_generator_display(resource_amount)

func get_current_mesh() -> MeshInstance3D:
	# Возвращаем созданный нами меш
	if has_node("UnitMesh"):
		return get_node("UnitMesh")
	# Если по какой-то причине нет UnitMesh, пробуем найти старые меши
	if unit_type == "soldier" and has_node("MeshInstance3D_Capsule"):
		return get_node("MeshInstance3D_Capsule")
	elif unit_type == "tank" and has_node("MeshInstance3D_Cube"):
		return get_node("MeshInstance3D_Cube")
	elif unit_type == "drone" and has_node("MeshInstance3D_Sphere"):
		return get_node("MeshInstance3D_Sphere")
	elif unit_type == "collector" and has_node("MeshInstance3D_Cylinder"):
		return get_node("MeshInstance3D_Cylinder")
	elif has_node("MeshInstance3D_Capsule"):
		return get_node("MeshInstance3D_Capsule")
	return current_mesh  # Возвращаем сохраненную ссылку

func get_crystal_type_name(crystal_type: int) -> String:
	# Безопасное получение имени типа кристалла
	match crystal_type:
		0: return "MAIN_CRYSTAL"
		1: return "ENERGY_CRYSTAL"
		2: return "UNSTABLE_CRYSTAL"
		3: return "VOID_CRYSTAL"
		4: return "ALTAR_CRYSTAL"
		_: return "UNKNOWN"

func create_3d_health_bar():
	# Создаем контейнер для HP бара
	var health_container = Node3D.new()
	health_container.name = "HealthBarContainer"
	health_container.position = Vector3(0, 2.5, 0)  # Над юнитом
	add_child(health_container)
	
	# Фон HP бара (темный)
	var background = MeshInstance3D.new()
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(2.0, 0.3, 0.1)
	background.mesh = bg_mesh
	background.material_override = StandardMaterial3D.new()
	background.material_override.albedo_color = Color(0.2, 0.2, 0.2, 0.8)
	background.material_override.flags_transparent = true
	background.name = "HealthBarBackground"
	health_container.add_child(background)
	
	# HP бар (цветной)
	var health_bar_mesh = MeshInstance3D.new()
	var hb_mesh = BoxMesh.new()
	hb_mesh.size = Vector3(2.0, 0.25, 0.05)
	health_bar_mesh.mesh = hb_mesh
	health_bar_mesh.material_override = StandardMaterial3D.new()
	health_bar_mesh.material_override.albedo_color = Color.GREEN
	health_bar_mesh.material_override.emission_enabled = true
	health_bar_mesh.material_override.emission = Color.GREEN * 0.3
	health_bar_mesh.name = "HealthBar3D"
	health_bar_mesh.position = Vector3(0, 0, 0.03)  # Чуть впереди фона
	health_container.add_child(health_bar_mesh)
	
	# Текст HP (Label3D)
	var health_label = Label3D.new()
	health_label.text = str(health) + "/" + str(max_health)
	health_label.font_size = 64
	health_label.position = Vector3(0, 0.5, 0)
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.modulate = Color.WHITE
	health_label.outline_size = 4
	health_label.outline_modulate = Color.BLACK
	health_label.name = "HealthLabel3D"
	health_container.add_child(health_label)

func update_3d_health_bar():
	var health_container = get_node_or_null("HealthBarContainer")
	if not health_container:
		return
		
	var health_bar_3d = health_container.get_node_or_null("HealthBar3D")
	var health_label_3d = health_container.get_node_or_null("HealthLabel3D")
	
	if health_bar_3d and health_label_3d:
		# Обновляем размер HP бара
		var health_percent = float(health) / float(max_health)
		var new_scale_x = health_percent
		health_bar_3d.scale.x = new_scale_x
		
		# Сдвигаем HP бар влево при уменьшении
		var offset_x = -(1.0 - new_scale_x) * 1.0  # 1.0 - половина ширины бара
		health_bar_3d.position.x = offset_x
		
		# Меняем цвет в зависимости от здоровья
		if health_percent > 0.7:
			health_bar_3d.material_override.albedo_color = Color.GREEN
			health_bar_3d.material_override.emission = Color.GREEN * 0.3
		elif health_percent > 0.4:
			health_bar_3d.material_override.albedo_color = Color.YELLOW
			health_bar_3d.material_override.emission = Color.YELLOW * 0.3
		elif health_percent > 0.2:
			health_bar_3d.material_override.albedo_color = Color.ORANGE
			health_bar_3d.material_override.emission = Color.ORANGE * 0.3
		else:
			health_bar_3d.material_override.albedo_color = Color.RED
			health_bar_3d.material_override.emission = Color.RED * 0.3
		
		# Обновляем текст
		if unit_type == "collector" and is_capturing:
			var capture_time = float(target_crystal.max_capture_time) if target_crystal and target_crystal.has("max_capture_time") else 5.0
			var progress_percent = int(capture_progress * 100 / capture_time)
			health_label_3d.text = "💎 " + str(progress_percent) + "%"
			health_label_3d.modulate = Color.ORANGE
		elif unit_type == "crystal_generator_turret":
			var bonus = get_crystal_power_bonus()
			var resource_amount = 5 + bonus.resource_bonus
			health_label_3d.text = "⚡ " + str(resource_amount) + "/сек"
			health_label_3d.modulate = Color.CYAN
		else:
			health_label_3d.text = str(health) + "/" + str(max_health)
			health_label_3d.modulate = Color.WHITE

func create_detection_zones():
	"""Создает визуальные зоны восприятия для отладки"""
	# Создаем контейнер для зон
	var zones_container = Node3D.new()
	zones_container.name = "DetectionZones"
	add_child(zones_container)
	
	# Зона восприятия вражеских войск (красная)
	var enemy_zone = MeshInstance3D.new()
	var enemy_mesh = SphereMesh.new()
	enemy_mesh.radius = enemy_detection_range
	enemy_mesh.height = 0.1
	enemy_zone.mesh = enemy_mesh
	enemy_zone.material_override = StandardMaterial3D.new()
	enemy_zone.material_override.albedo_color = Color(1, 0, 0, 0.1)  # Красная, прозрачная
	enemy_zone.material_override.flags_transparent = true
	enemy_zone.name = "EnemyDetectionZone"
	enemy_zone.position = Vector3(0, 0.05, 0)
	zones_container.add_child(enemy_zone)
	
	# Зона поиска зданий (синяя)
	var building_zone = MeshInstance3D.new()
	var building_mesh = SphereMesh.new()
	building_mesh.radius = building_search_range
	building_mesh.height = 0.1
	building_zone.mesh = building_mesh
	building_zone.material_override = StandardMaterial3D.new()
	building_zone.material_override.albedo_color = Color(0, 0, 1, 0.05)  # Синяя, очень прозрачная
	building_zone.material_override.flags_transparent = true
	building_zone.name = "BuildingSearchZone"
	building_zone.position = Vector3(0, 0.1, 0)
	zones_container.add_child(building_zone)
	
	# По умолчанию скрываем зоны (можно включить для отладки)
	zones_container.visible = false

func toggle_detection_zones():
	"""Переключает видимость зон восприятия"""
	var zones_container = get_node_or_null("DetectionZones")
	if zones_container:
		zones_container.visible = !zones_container.visible
		print("Зоны восприятия ", "включены" if zones_container.visible else "выключены")

func _input(event):
	# Тестирование зон восприятия (F1)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		toggle_detection_zones()
		# Показываем текущие цели
		print("=== ДИАГНОСТИКА ЮНИТА ===")
		print("Тип: ", unit_type)
		print("Команда: ", team)
		print("Зона восприятия врагов: ", enemy_detection_range)
		print("Зона поиска зданий: ", building_search_range)
		print("Текущий тип цели: ", current_target_type)
		print("Вражеская цель: ", enemy_target.name if enemy_target else "нет")
		print("Цель здания: ", building_target.name if building_target else "нет")
		print("Активная цель: ", target.name if target else "нет")
		print("========================")

func update_generator_display(resource_amount: int):
	"""Обновляет отображение генератора с информацией о производстве"""
	var health_container = get_node_or_null("HealthBarContainer")
	if not health_container:
		return
		
	var health_label_3d = health_container.get_node_or_null("HealthLabel3D")
	if health_label_3d:
		health_label_3d.text = "⚡ " + str(resource_amount) + "/сек"
		health_label_3d.modulate = Color.CYAN
