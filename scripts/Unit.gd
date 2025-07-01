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
var target_territory = null
var is_capturing = false
var capture_progress = 0.0
var has_transformed = false

@onready var attack_area: Area3D = $AttackArea
@onready var health_bar: Label = $HealthBar

func _ready():
	# Отключаем все MeshInstance3D
	if has_node("MeshInstance3D_Capsule"): get_node("MeshInstance3D_Capsule").visible = false
	if has_node("MeshInstance3D_Cube"): get_node("MeshInstance3D_Cube").visible = false
	if has_node("MeshInstance3D_Sphere"): get_node("MeshInstance3D_Sphere").visible = false
	if has_node("MeshInstance3D_Cylinder"): get_node("MeshInstance3D_Cylinder").visible = false

	# Включаем нужную форму по типу юнита
	var current_mesh = null
	if unit_type == "soldier":
		current_mesh = get_node("MeshInstance3D_Capsule")
		current_mesh.visible = true
	elif unit_type == "tank":
		current_mesh = get_node("MeshInstance3D_Cube")
		current_mesh.visible = true
	elif unit_type == "drone":
		current_mesh = get_node("MeshInstance3D_Sphere")
		current_mesh.visible = true
	elif unit_type == "collector":
		current_mesh = get_node("MeshInstance3D_Cylinder")
		current_mesh.visible = true
	else:
		current_mesh = get_node("MeshInstance3D_Capsule")
		current_mesh.visible = true

	# Тип и параметры (СБАЛАНСИРОВАННЫЕ)
	if unit_type == "soldier":
		speed = 70           # Базовая пехота - средняя скорость
		health = 100
		max_health = 100
		damage = 25          # Увеличен урон для баланса
	elif unit_type == "tank":
		speed = 35           # Медленные танки
		health = 250         # Больше HP для танковости
		max_health = 250
		damage = 35          # Меньше урона, но больше HP
	elif unit_type == "drone":
		speed = 110          # Очень быстрые дроны
		health = 80          # Больше HP для выживаемости
		max_health = 80
		damage = 15          # Больше урона для эффективности
	elif unit_type == "elite_soldier":
		speed = 80           # Быстрые элитные бойцы
		health = 140
		max_health = 140
		damage = 40          # Высокий урон за кристаллы
	elif unit_type == "crystal_mage":
		speed = 55           # Медленные маги
		health = 90
		max_health = 90
		damage = 45          # Снижен урон для баланса
		attack_range = 5.0   # Дальняя атака
	elif unit_type == "heavy_tank":
		speed = 25           # Очень медленные супертанки
		health = 450
		max_health = 450
		damage = 60          # Умеренный урон
	elif unit_type == "collector":
		speed = 60           # Быстрые сборщики ресурсов
		health = 100
		max_health = 100
		damage = 0           # Не атакуют
	# Цвет по команде (жёстко: игрок — синий, враг — красный)
	current_mesh.material_override = StandardMaterial3D.new()
	if team == "player":
		current_mesh.material_override.albedo_color = Color(0.2, 0.6, 1, 1)
	else:
		current_mesh.material_override.albedo_color = Color(1, 0.2, 0.2, 1)
	# Безопасно подключаем AttackArea
	if has_node("AttackArea"):
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)
	# Безопасно обновляем HealthBar
	if has_node("HealthBar"):
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
	
	# Проверяем захват территорий для обычных юнитов
	if battle_manager and battle_manager.territory_system:
		battle_manager.territory_system.check_territory_capture(global_position, team)
	
	attack_timer += _delta
	if target and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist > attack_range:
			move_towards_target()
		else:
			if attack_timer > attack_cooldown:
				attack()
				attack_timer = 0.0
	else:
		move_towards_target()
		find_new_target()

func move_towards_target():
	if target_pos:
		var dir = (target_pos - global_position).normalized()
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
	var closest_enemy = null
	var closest_distance = 999999.0
	
	for enemy in enemies:
		if enemy.team != team and enemy.health > 0:
			var distance = global_position.distance_to(enemy.global_position)
			if distance < closest_distance and distance < 15.0:  # Радиус поиска 15 единиц
				closest_enemy = enemy
				closest_distance = distance
	
	if closest_enemy:
		target = closest_enemy
		print(team, " ", unit_type, " нашел цель: ", closest_enemy.team, " ", closest_enemy.unit_type)

func attack():
	if target and target.has_method("take_damage"):
		target.take_damage(damage)
		print(team, " ", unit_type, " атакует ", target.team, " ", target.unit_type, " урон: ", damage)
		
		# Визуальный эффект атаки
		var current_mesh = get_current_mesh()
		if current_mesh:
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
	
	print(team, " ", unit_type, " получил урон: ", amount, " HP: ", health)
	
	# Визуальный эффект получения урона
	var current_mesh = get_current_mesh()
	if current_mesh:
		current_mesh.material_override.albedo_color = Color.RED
		await get_tree().create_timer(0.2).timeout
		# Возвращаем исходный цвет
		if team == "player":
			current_mesh.material_override.albedo_color = Color(0.2, 0.6, 1, 1)
		else:
			current_mesh.material_override.albedo_color = Color(1, 0.2, 0.2, 1)
	
	if health <= 0:
		print(team, " ", unit_type, " уничтожен!")
		queue_free()

func update_health_display():
	if has_node("HealthBar"):
		var health_display = get_node("HealthBar")
		if health_display and health_display is Label:
			if unit_type == "collector" and is_capturing:
				# Показываем прогресс захвата для коллекторов
				var progress_percent = int(capture_progress * 100 / 5.0)  # 5 секунд = 100%
				health_display.text = "Захват: " + str(progress_percent) + "%"
			else:
				health_display.text = str(health) + "/" + str(max_health)

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
	
	# Если мы захватываем территорию
	if is_capturing and target_territory:
		capture_progress += _delta
		update_health_display()
		
		# Проверяем, завершен ли захват
		if capture_progress >= 5.0:  # 5 секунд для захвата
			complete_territory_capture()
		
		# Можем защищаться во время захвата
		attack_timer += _delta
		find_new_target()
		if target and is_instance_valid(target):
			if attack_timer > attack_cooldown:
				attack()
				attack_timer = 0.0
		return
	
	# Ищем ближайшую свободную территорию
	if not target_territory:
		find_target_territory()
	
	# Двигаемся к целевой территории
	if target_territory:
		var territory_pos = target_territory.position
		var distance = global_position.distance_to(territory_pos)
		
		if distance < target_territory.control_radius:
			# Начинаем захват
			start_territory_capture()
		else:
			# Движемся к территории
			var dir = (territory_pos - global_position).normalized()
			velocity = dir * speed
			move_and_slide()
	else:
		# Если нет цели, двигаемся к вражеской базе
		if target_pos:
			move_towards_target()

func find_target_territory():
	if not battle_manager or not battle_manager.territory_system:
		return
		
	var territories = battle_manager.territory_system.get_territory_info()
	var best_territory = null
	var closest_distance = 999999.0
	
	for territory in territories:
		# Ищем нейтральные или вражеские территории
		if territory.owner == "neutral" or territory.owner != team:
			# Проверяем, нет ли уже коллектора на этой территории
			if not territory.has("assigned_collector"):
				var distance = global_position.distance_to(territory.position)
				if distance < closest_distance:
					closest_distance = distance
					best_territory = territory
	
	if best_territory:
		target_territory = best_territory
		# Помечаем территорию как занятую
		target_territory["assigned_collector"] = self
		print("🎯 Коллектор ", team, " нацелился на территорию ", target_territory.id)

func start_territory_capture():
	is_capturing = true
	capture_progress = 0.0
	speed = 0  # Останавливаемся для захвата
	print("⏳ Коллектор ", team, " начал захват территории ", target_territory.id)

func complete_territory_capture():
	if not target_territory or not battle_manager or not battle_manager.territory_system:
		return
		
	# Захватываем территорию
	battle_manager.territory_system.force_capture_territory(target_territory.id, team)
	
	# Превращаемся в турель
	transform_to_turret()
	
	print("🏰 Коллектор ", team, " захватил территорию ", target_territory.id, " и превратился в турель!")

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

func get_current_mesh() -> MeshInstance3D:
	"""Возвращает текущий активный меш юнита"""
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
