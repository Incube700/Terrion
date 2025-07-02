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

# Специальные переменные для коллекторов
var target_crystal = null
var is_capturing = false
var capture_progress = 0.0
var has_transformed = false

@onready var attack_area: Area3D = null
@onready var health_bar: Label = null

func _ready():
	# Добавляем юнит в группу для поиска целей
	add_to_group("units")
	
	# Безопасно получаем ссылки на ноды
	if has_node("AttackArea"):
		attack_area = get_node("AttackArea")
	if has_node("HealthBar"):
		health_bar = get_node("HealthBar")
	
	# Отключаем все MeshInstance3D
	if has_node("MeshInstance3D_Capsule"): get_node("MeshInstance3D_Capsule").visible = false
	if has_node("MeshInstance3D_Cube"): get_node("MeshInstance3D_Cube").visible = false
	if has_node("MeshInstance3D_Sphere"): get_node("MeshInstance3D_Sphere").visible = false
	if has_node("MeshInstance3D_Cylinder"): get_node("MeshInstance3D_Cylinder").visible = false

	# Включаем нужную форму по типу юнита
	var current_mesh = null
	if unit_type == "soldier" and has_node("MeshInstance3D_Capsule"):
		current_mesh = get_node("MeshInstance3D_Capsule")
		if current_mesh:
			current_mesh.visible = true
	elif unit_type == "tank" and has_node("MeshInstance3D_Cube"):
		current_mesh = get_node("MeshInstance3D_Cube")
		if current_mesh:
			current_mesh.visible = true
	elif unit_type == "drone" and has_node("MeshInstance3D_Sphere"):
		current_mesh = get_node("MeshInstance3D_Sphere")
		if current_mesh:
			current_mesh.visible = true
	elif unit_type == "collector" and has_node("MeshInstance3D_Cylinder"):
		current_mesh = get_node("MeshInstance3D_Cylinder")
		if current_mesh:
			current_mesh.visible = true
	else:
		if has_node("MeshInstance3D_Capsule"):
			current_mesh = get_node("MeshInstance3D_Capsule")
			if current_mesh:
				current_mesh.visible = true

	# Тип и параметры (МАКСИМАЛЬНО МЕДЛЕННЫЕ СКОРОСТИ для глубокого тактического геймплея)
	if unit_type == "soldier":
		speed = 8            # МАКСИМАЛЬНО МЕДЛЕННО (было 15)
		health = 300         # Увеличено в 3 раза для тактики
		max_health = 300
		damage = 25
	elif unit_type == "tank":
		speed = 5            # МАКСИМАЛЬНО МЕДЛЕННО (было 10)
		health = 800         # Увеличено в 3+ раза для тактики
		max_health = 800
		damage = 35
	elif unit_type == "drone":
		speed = 12           # МАКСИМАЛЬНО МЕДЛЕННО (было 20)
		health = 240         # Увеличено в 3 раза для тактики
		max_health = 240
		damage = 15
	elif unit_type == "elite_soldier":
		speed = 10           # МАКСИМАЛЬНО МЕДЛЕННО (было 18)
		health = 450         # Увеличено в 3+ раза для тактики
		max_health = 450
		damage = 40
	elif unit_type == "crystal_mage":
		speed = 6            # МАКСИМАЛЬНО МЕДЛЕННО (было 12)
		health = 320         # Увеличено в 3+ раза для тактики
		max_health = 320
		damage = 45
		attack_range = 5.0
	elif unit_type == "heavy_tank":
		speed = 4            # МАКСИМАЛЬНО МЕДЛЕННО (было 8)
		health = 1200        # Увеличено в 2.7 раза для тактики
		max_health = 1200
		damage = 60
	elif unit_type == "collector":
		speed = 10           # МАКСИМАЛЬНО МЕДЛЕННО (было 18)
		health = 280         # Увеличено почти в 3 раза для тактики
		max_health = 280
		damage = 0           # Не атакуют
	# Цвет по команде (жёстко: игрок — синий, враг — красный)
	if current_mesh:
		current_mesh.material_override = StandardMaterial3D.new()
		if team == "player":
			current_mesh.material_override.albedo_color = Color(0.2, 0.6, 1, 1)
		else:
			current_mesh.material_override.albedo_color = Color(1, 0.2, 0.2, 1)
	# Безопасно подключаем AttackArea
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)
	
	# Создаем 3D HP бар
	create_3d_health_bar()
	
	# Безопасно обновляем HealthBar
	if health_bar and health_bar is Label:
		update_health_display()

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
	
	# Проверяем захват кристаллов для обычных юнитов
	if battle_manager and battle_manager.crystal_system:
		battle_manager.crystal_system.check_crystal_interaction(global_position, team, unit_type)
	
	attack_timer += _delta
	
	# ПРИОРИТЕТ 1: Если есть враг в зоне видимости - атакуем его
	if target and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist > attack_range:
			# Враг далеко - движемся к нему
			move_towards_enemy()
		else:
			# Враг близко - атакуем
			if attack_timer > attack_cooldown:
				attack()
				attack_timer = 0.0
	else:
		# ПРИОРИТЕТ 2: Нет врагов - ищем новых врагов
		find_new_target()
		
		# ПРИОРИТЕТ 3: Если врагов нет - идем к вражескому ядру
		if not target:
			move_towards_target()

func move_towards_target():
	# Движение к вражескому ядру (основная цель)
	if target_pos:
		var dir = (target_pos - global_position).normalized()
		velocity = dir * speed
		move_and_slide()

func move_towards_enemy():
	# Движение к конкретному врагу (приоритетная цель)
	if target and is_instance_valid(target):
		var dir = (target.global_position - global_position).normalized()
		velocity = dir * speed
		move_and_slide()

func _on_attack_area_body_entered(body):
	if body != self and body.has_method("take_damage") and body.team != team:
		target = body

func _on_attack_area_body_exited(body):
	if target == body:
		target = null

func find_new_target():
	# Ищем ближайшего врага в радиусе видимости
	var enemies = get_tree().get_nodes_in_group("units")
	var enemy_spawners = get_tree().get_nodes_in_group("spawners")
	
	var closest_enemy = null
	var closest_distance = 999999.0
	
	# ПРИОРИТЕТ 1: Вражеские юниты
	for enemy in enemies:
		if enemy.team != team and enemy.health > 0:
			var distance = global_position.distance_to(enemy.global_position)
			if distance < closest_distance and distance < 15.0:  # Радиус поиска 15 единиц
				closest_enemy = enemy
				closest_distance = distance
	
	# ПРИОРИТЕТ 2: Вражеские здания (если нет юнитов рядом)
	if not closest_enemy:
		for spawner in enemy_spawners:
			if spawner.team != team and spawner.health > 0:
				var distance = global_position.distance_to(spawner.global_position)
				if distance < closest_distance and distance < 10.0:  # Меньший радиус для зданий
					closest_enemy = spawner
					closest_distance = distance
	
	if closest_enemy and target != closest_enemy:
		target = closest_enemy
		# Логируем только при смене цели, чтобы избежать спама
		var target_type = "здание" if closest_enemy.has_method("get_spawner_info") else "юнит"
		var enemy_team = closest_enemy.team if "team" in closest_enemy else "нейтральное"
		print(team, " ", unit_type, " нашел новую цель (", target_type, "): ", enemy_team)

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
				var capture_time = target_crystal.max_capture_time if target_crystal and target_crystal.has("max_capture_time") else 5.0
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
		find_new_target()
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
		var capture_time = target_crystal.max_capture_time if target_crystal.has("max_capture_time") else 5.0
		if capture_progress >= capture_time:
			complete_crystal_capture()
		
		# Можем защищаться во время захвата
		attack_timer += _delta
		find_new_target()
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
	if not battle_manager or not battle_manager.crystal_system:
		return
		
	var crystals = battle_manager.crystal_system.get_crystal_info()
	var best_crystal = null
	var closest_distance = 999999.0
	
	for crystal in crystals:
		# Ищем нейтральные или вражеские кристаллы
		if crystal.owner == "neutral" or crystal.owner != team:
			# Проверяем, нет ли уже коллектора на этом кристалле
			if not crystal.has("assigned_collector"):
				var distance = global_position.distance_to(crystal.position)
				if distance < closest_distance:
					closest_distance = distance
					best_crystal = crystal
	
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
	if not target_crystal or not battle_manager or not battle_manager.crystal_system:
		return
		
	# Захватываем кристалл
	battle_manager.crystal_system.force_capture_crystal(target_crystal.id, team)
	
	# Превращаемся в турель
	transform_to_turret()
	
	var crystal_type_name = get_crystal_type_name(target_crystal.type)
	print("🏰 Коллектор ", team, " захватил кристалл ", target_crystal.id, " (", crystal_type_name, ") и превратился в турель!")

func transform_to_turret():
	has_transformed = true
	is_capturing = false
	speed = 0
	
	# Меняем внешний вид на турель
	if has_node("MeshInstance3D_Cylinder"):
		var mesh = get_node("MeshInstance3D_Cylinder")
		mesh.visible = false
	
	# Создаем новый меш турели
	var turret_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.6
	cyl.height = 1.5
	turret_mesh.mesh = cyl
	turret_mesh.position = Vector3(0, 0.75, 0)
	
	# Цвет турели
	turret_mesh.material_override = StandardMaterial3D.new()
	if team == "player":
		turret_mesh.material_override.albedo_color = Color(0.2, 0.6, 1, 1)
	else:
		turret_mesh.material_override.albedo_color = Color(1, 0.2, 0.2, 1)
	
	# Добавляем свечение
	turret_mesh.material_override.emission_enabled = true
	if team == "player":
		turret_mesh.material_override.emission = Color(0.1, 0.3, 0.5)
	else:
		turret_mesh.material_override.emission = Color(0.5, 0.1, 0.1)
	
	add_child(turret_mesh)
	
	# Улучшаем характеристики турели
	damage = 40  # Больше урона
	attack_range = 6.0  # Больше дальность
	attack_cooldown = 0.8  # Быстрее стреляет
	health = 200  # Больше здоровья
	max_health = 200
	
	# Обновляем тип юнита
	unit_type = "turret"
	
	# Обновляем группы
	remove_from_group("units")
	add_to_group("turrets")
	
	update_health_display()
	update_3d_health_bar()  # Обновляем 3D HP бар для турели

func get_current_mesh() -> MeshInstance3D:
	# (documentation comment)
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
	return null

func get_crystal_type_name(crystal_type: int) -> String:
	# Безопасное получение имени типа кристалла
	match crystal_type:
		0: return "MAIN_CRYSTAL"
		1: return "ENERGY_CRYSTAL"
		2: return "TECH_CRYSTAL"
		3: return "BIO_CRYSTAL"
		4: return "PSI_CRYSTAL"
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
			var capture_time = target_crystal.max_capture_time if target_crystal and target_crystal.has("max_capture_time") else 5.0
			var progress_percent = int(capture_progress * 100 / capture_time)
			health_label_3d.text = "💎 " + str(progress_percent) + "%"
			health_label_3d.modulate = Color.ORANGE
		else:
			health_label_3d.text = str(health) + "/" + str(max_health)
			health_label_3d.modulate = Color.WHITE
