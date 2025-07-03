extends Node
class_name CrystalSystem

# Кристаллическая система TERRION RTS
# Заменяет простые территории на динамические кристаллы с уникальными свойствами

signal crystal_captured(crystal_id: int, new_owner: String, crystal_type: int)
signal crystal_depleted(crystal_id: int)

var crystals: Array[Dictionary] = []
var crystal_meshes: Array[MeshInstance3D] = []
var battle_manager = null

# Типы кристаллов
enum CrystalType {
	MAIN_CRYSTAL,         # Главные кристаллы (стартовые позиции)
	ENERGY_CRYSTAL,       # Энергетические кристаллы
	UNSTABLE_CRYSTAL,     # Нестабильные кристаллы для супер-войск
	VOID_CRYSTAL          # Кристаллы пустоты для ультимативных способностей
}

func _ready():
	print("💎 Инициализация Кристаллической Системы...")
	create_crystal_field()
	
	# Таймер для регенерации кристаллов
	var regen_timer = Timer.new()
	regen_timer.wait_time = 2.0
	regen_timer.autostart = true
	regen_timer.timeout.connect(_on_crystal_regeneration)
	add_child(regen_timer)
	
	# Таймер для генерации ресурсов
	var resource_timer = Timer.new()
	resource_timer.wait_time = 3.0
	resource_timer.autostart = true
	resource_timer.timeout.connect(_on_resource_generation)
	add_child(resource_timer)

func create_crystal_field():
	# Создаем сбалансированное поле кристаллов
	var crystal_configs = [
		# === ГЛАВНЫЕ КРИСТАЛЛЫ (стартовые позиции) ===
		{"name": "Главный Кристалл Юг", "pos": Vector3(0, 1, 25), "type": CrystalType.MAIN_CRYSTAL, "capacity": 10000, "regen": 0, "radius": 8.0},
		{"name": "Главный Кристалл Север", "pos": Vector3(0, 1, -25), "type": CrystalType.MAIN_CRYSTAL, "capacity": 10000, "regen": 0, "radius": 8.0},
		
		# === ЭНЕРГЕТИЧЕСКИЕ КРИСТАЛЛЫ (основные ресурсы) ===
		{"name": "energy_1", "pos": Vector3(-15, 1, 10), "type": CrystalType.ENERGY_CRYSTAL, "capacity": 5000, "regen": 10, "radius": 6.0},
		{"name": "energy_2", "pos": Vector3(15, 1, 10), "type": CrystalType.ENERGY_CRYSTAL, "capacity": 5000, "regen": 10, "radius": 6.0},
		{"name": "energy_3", "pos": Vector3(-15, 1, -10), "type": CrystalType.ENERGY_CRYSTAL, "capacity": 5000, "regen": 10, "radius": 6.0},
		{"name": "energy_4", "pos": Vector3(15, 1, -10), "type": CrystalType.ENERGY_CRYSTAL, "capacity": 5000, "regen": 10, "radius": 6.0},
		
		# === НЕСТАБИЛЬНЫЕ КРИСТАЛЛЫ (для супер-войск) ===
		{"name": "Нестабильный Кристалл Лево", "pos": Vector3(-8, 1, 0), "type": CrystalType.UNSTABLE_CRYSTAL, "capacity": 800, "regen": 2, "radius": 4.0},
		{"name": "Нестабильный Кристалл Право", "pos": Vector3(8, 1, 0), "type": CrystalType.UNSTABLE_CRYSTAL, "capacity": 800, "regen": 2, "radius": 4.0},
		{"name": "Нестабильный Кристалл Центр", "pos": Vector3(0, 1, 0), "type": CrystalType.UNSTABLE_CRYSTAL, "capacity": 1000, "regen": 2, "radius": 5.0},
		
		# === КРИСТАЛЛЫ ПУСТОТЫ (для ультимативных способностей) ===
		{"name": "Кристалл Пустоты Альфа", "pos": Vector3(-5, 1, 5), "type": CrystalType.VOID_CRYSTAL, "capacity": 500, "regen": 1, "radius": 3.0},
		{"name": "Кристалл Пустоты Бета", "pos": Vector3(5, 1, -5), "type": CrystalType.VOID_CRYSTAL, "capacity": 500, "regen": 1, "radius": 3.0},
	]
	
	for i in range(crystal_configs.size()):
		var config = crystal_configs[i]
		var crystal = create_crystal(i, config["pos"], config["type"], config["capacity"], config["regen"], config["radius"])
		crystals.append(crystal)

func create_crystal(id: int, position: Vector3, type: CrystalType, capacity: int, regen_rate: int, radius: float) -> Dictionary:
	var crystal = {
		"id": id,
		"position": position,
		"type": type,
		"owner": "neutral",
		"max_capacity": capacity,
		"current_capacity": capacity,
		"regeneration_rate": regen_rate,
		"control_radius": radius,
		"capture_progress": 0.0,
		"max_capture_time": get_capture_time(type),
		"instability": 0.0,  # Для пси-кристаллов
		"growth_level": 1.0,  # Для био-кристаллов
		"contamination": 0.0  # Для био-кристаллов
	}
	
	# Создаем визуальное представление
	create_crystal_visual(crystal)
	
	return crystal

func get_capture_time(type: CrystalType) -> float:
	match type:
		CrystalType.MAIN_CRYSTAL:
			return 10.0  # Захват: 10 сек → Освобождение: 15 сек
		CrystalType.ENERGY_CRYSTAL:
			return 5.0   # Захват: 5 сек → Освобождение: 7.5 сек
		CrystalType.UNSTABLE_CRYSTAL:
			return 8.0   # Захват: 8 сек → Освобождение: 12 сек
		CrystalType.VOID_CRYSTAL:
			return 4.0   # Захват: 4 сек → Освобождение: 6 сек
		_:
			return 5.0

func create_crystal_visual(crystal: Dictionary):
	var mesh_instance = MeshInstance3D.new()
	
	# Разные формы для разных типов кристаллов
	match crystal.type:
		CrystalType.MAIN_CRYSTAL:
			var sphere = SphereMesh.new()
			sphere.radius = crystal.control_radius * 0.8
			sphere.height = crystal.control_radius * 1.6
			mesh_instance.mesh = sphere
		CrystalType.ENERGY_CRYSTAL:
			var cylinder = CylinderMesh.new()
			cylinder.top_radius = crystal.control_radius * 0.6
			cylinder.bottom_radius = crystal.control_radius * 0.8
			cylinder.height = crystal.control_radius * 1.2
			mesh_instance.mesh = cylinder
		CrystalType.UNSTABLE_CRYSTAL:
			var box = BoxMesh.new()
			box.size = Vector3(crystal.control_radius, crystal.control_radius * 1.5, crystal.control_radius)
			mesh_instance.mesh = box
		CrystalType.VOID_CRYSTAL:
			var capsule = CapsuleMesh.new()
			capsule.radius = crystal.control_radius * 0.5
			capsule.height = crystal.control_radius * 1.8
			mesh_instance.mesh = capsule
	
	mesh_instance.position = crystal.position
	
	# Создаем информационную метку
	var label = Label3D.new()
	label.text = get_crystal_info_text(crystal)
	label.position = crystal.position + Vector3(0, crystal.control_radius + 2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 96
	label.modulate = Color.WHITE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.outline_size = 15
	label.outline_modulate = Color.BLACK
	label.name = "Crystal_" + str(crystal.id) + "_Label"
	get_parent().add_child(label)
	
	# Материалы и цвета
	var material = StandardMaterial3D.new()
	match crystal.type:
		CrystalType.MAIN_CRYSTAL:
			material.albedo_color = Color(1.0, 0.8, 0.0, 0.9)  # Золотой
			material.emission = Color(0.8, 0.6, 0.0)
		CrystalType.ENERGY_CRYSTAL:
			material.albedo_color = Color(0.0, 0.9, 1.0, 0.9)  # Ярко-голубой
			material.emission = Color(0.0, 0.7, 1.0)
		CrystalType.UNSTABLE_CRYSTAL:
			material.albedo_color = Color(1.0, 0.5, 0.0, 0.9)  # Оранжевый нестабильный
			material.emission = Color(1.0, 0.3, 0.0)
		CrystalType.VOID_CRYSTAL:
			material.albedo_color = Color(0.3, 0.0, 0.8, 0.9)  # Темно-фиолетовый пустота
			material.emission = Color(0.5, 0.0, 1.0)
	
	material.flags_transparent = true
	material.emission_enabled = true
	material.emission_energy = 2.5
	mesh_instance.set_surface_override_material(0, material)
	
	get_parent().add_child(mesh_instance)
	crystal_meshes.append(mesh_instance)

func get_crystal_info_text(crystal: Dictionary) -> String:
	var type_name = ""
	var bonus_info = ""
	
	match crystal.type:
		CrystalType.MAIN_CRYSTAL:
			type_name = "👑 ГЛАВНЫЙ"
			bonus_info = "Командный центр"
		CrystalType.ENERGY_CRYSTAL:
			type_name = "⚡ ЭНЕРГИЯ"
			bonus_info = "+" + str(get_resource_rate(crystal.type)) + "/сек"
		CrystalType.UNSTABLE_CRYSTAL:
			type_name = "⚠️ НЕСТАБИЛЬНЫЙ"
			bonus_info = "+25 кристаллов"
		CrystalType.VOID_CRYSTAL:
			type_name = "🌌 ПУСТОТА"
			bonus_info = "+50 кристаллов"
	
	var capacity_percent = int((float(crystal.current_capacity) / float(crystal.max_capacity)) * 100.0)
	return type_name + "\n" + bonus_info + "\n" + str(capacity_percent) + "%"

func _on_crystal_regeneration():
	for crystal in crystals:
		if crystal.current_capacity < crystal.max_capacity and crystal.regeneration_rate > 0:
			# Базовая регенерация
			crystal.current_capacity += crystal.regeneration_rate
			crystal.current_capacity = min(crystal.current_capacity, crystal.max_capacity)
			
			# Специальные эффекты регенерации
			apply_crystal_regeneration_effects(crystal)
			
			# Обновляем визуал
			update_crystal_visual(crystal)

func apply_crystal_regeneration_effects(crystal: Dictionary):
	match crystal.type:
		CrystalType.ENERGY_CRYSTAL:
			# Энергетические кристаллы могут расти и увеличивать максимальную емкость
			if crystal.growth_level < 2.0 and randf() < 0.05:  # 5% шанс роста
				crystal.growth_level += 0.1
				crystal.max_capacity = int(crystal.max_capacity * 1.05)  # +5% к емкости
				print("🌱 Энергетический кристалл ", crystal.id, " вырос! Новая емкость: ", crystal.max_capacity)

func _on_resource_generation():
	for crystal in crystals:
		if crystal.owner != "neutral":
			apply_crystal_effects(crystal)

func apply_crystal_effects(crystal: Dictionary):
	if not battle_manager:
		return
	
	var crystal_owner = crystal.owner
	var amount = get_resource_rate(crystal.type)
	
	match crystal.type:
		CrystalType.MAIN_CRYSTAL:
			# Главные кристаллы дают постоянный доход
			add_resource(crystal_owner, "energy", amount)
			add_resource(crystal_owner, "crystals", int(float(amount) / 2.0))
			
		CrystalType.ENERGY_CRYSTAL:
			# Энергетические кристаллы дают энергию
			add_resource(crystal_owner, "energy", amount)
			# Тратим емкость кристалла
			crystal.current_capacity -= amount
			if crystal.current_capacity <= 0:
				crystal.current_capacity = 0
				crystal_depleted.emit(crystal.id)
			
		CrystalType.UNSTABLE_CRYSTAL:
			# Нестабильные кристаллы дают кристаллы для супер-войск
			add_resource(crystal_owner, "crystals", 25)
			
		CrystalType.VOID_CRYSTAL:
			# Кристаллы пустоты дают кристаллы для ультимативных способностей
			add_resource(crystal_owner, "crystals", 50)

func get_resource_rate(type: CrystalType) -> int:
	match type:
		CrystalType.MAIN_CRYSTAL:
			return 20  # Главные кристаллы дают много ресурсов
		CrystalType.ENERGY_CRYSTAL:
			return 25  # Энергетические кристаллы - основной источник
		CrystalType.UNSTABLE_CRYSTAL:
			return 10  # Технологические - меньше, но ценнее
		CrystalType.VOID_CRYSTAL:
			return 15  # Био-кристаллы - средний доход
		_:
			return 0

func add_resource(crystal_owner: String, resource_type: String, amount: int):
	if not battle_manager:
		return
		
	match resource_type:
		"energy":
			if crystal_owner == "player":
				battle_manager.player_energy += amount
			else:
				battle_manager.enemy_energy += amount
		"crystals":
			if crystal_owner == "player":
				battle_manager.player_crystals += amount
			else:
				battle_manager.enemy_crystals += amount

func attempt_capture(crystal: Dictionary, team: String):
	if crystal.owner == team:
		return  # Уже захвачен этой командой
	
	# Логика захвата кристалла
	crystal.capture_progress += 1.0
	
	if crystal.capture_progress >= crystal.max_capture_time:
		var old_owner = crystal.owner
		crystal.owner = team
		crystal.capture_progress = 0.0
		
		# Обновляем визуал
		update_crystal_visual(crystal)
		
		# Специальные эффекты при захвате
		apply_capture_effects(crystal, old_owner, team)
		
		crystal_captured.emit(crystal.id, team, crystal.type)
		print("💎 Кристалл ", crystal.id, " (", get_crystal_type_name(crystal.type), ") захвачен командой ", team)
		
		# Проверяем условия победы
		if battle_manager:
			battle_manager.call_deferred("check_victory_conditions")

func apply_capture_effects(crystal: Dictionary, old_owner: String, new_owner: String):
	# Используем old_owner для логирования
	print("💎 Кристалл переходит от ", old_owner, " к ", new_owner)
	
	match crystal.type:
		CrystalType.MAIN_CRYSTAL:
			# Захват главного кристалла - мощный бонус
			if new_owner == "player":
				show_notification("👑 Главный кристалл захвачен! Мощный бонус к ресурсам!")
			deploy_command_center(crystal, new_owner)
			
		CrystalType.UNSTABLE_CRYSTAL:
			# Технологический кристалл дает немедленный исследовательский бонус
			add_resource(new_owner, "crystals", 100)
			show_notification("🔬 Технологический прорыв! +100 кристаллов!")
			
		CrystalType.VOID_CRYSTAL:
			# Био-кристалл лечит всех союзных юнитов
			heal_all_friendly_units(new_owner)
			show_notification("🌿 Био-кристалл лечит ваши войска!")

func update_crystal_visual(crystal: Dictionary):
	var mesh_index = crystal.id
	if mesh_index < crystal_meshes.size():
		var mesh = crystal_meshes[mesh_index]
		var material = mesh.get_surface_override_material(0)
		
		# Изменяем цвет в зависимости от владельца
		if crystal.owner == "player":
			material.albedo_color = material.albedo_color.lerp(Color(0.2, 0.6, 1.0, 0.9), 0.5)
		elif crystal.owner == "enemy":
			material.albedo_color = material.albedo_color.lerp(Color(1.0, 0.2, 0.2, 0.9), 0.5)
		else:
			# Восстанавливаем оригинальный цвет
			restore_original_crystal_color(crystal, material)
	
	# Обновляем информационную метку
	update_crystal_label(crystal)

func restore_original_crystal_color(crystal: Dictionary, material: StandardMaterial3D):
	match crystal.type:
		CrystalType.MAIN_CRYSTAL:
			material.albedo_color = Color(1.0, 0.8, 0.0, 0.9)
		CrystalType.ENERGY_CRYSTAL:
			material.albedo_color = Color(0.0, 0.9, 1.0, 0.9)
		CrystalType.UNSTABLE_CRYSTAL:
			material.albedo_color = Color(1.0, 0.5, 0.0, 0.9)
		CrystalType.VOID_CRYSTAL:
			material.albedo_color = Color(0.3, 0.0, 0.8, 0.9)

func update_crystal_label(crystal: Dictionary):
	var label_name = "Crystal_" + str(crystal.id) + "_Label"
	var label = get_parent().get_node_or_null(label_name)
	if label:
		label.text = get_crystal_info_text(crystal)

# Вспомогательные функции - используем параметры
func deploy_command_center(crystal: Dictionary, team_owner: String):
	print("🏗️ Развертывание командного центра для ", team_owner, " на кристалле ", crystal.id)

func boost_tech_research(team_owner: String):
	print("🔬 Ускорение исследований для ", team_owner)

func heal_nearby_units(pos: Vector3, team_owner: String, search_radius: float):
	print("💚 Лечение юнитов ", team_owner, " в радиусе ", search_radius, " от позиции ", pos)

func heal_all_friendly_units(team_owner: String):
	print("💚 Лечение всех юнитов ", team_owner)

func reduce_ability_cooldowns(team_owner: String):
	print("⏰ Снижение кулдаунов для ", team_owner)

func reset_all_cooldowns(team_owner: String):
	print("⚡ Сброс всех кулдаунов для ", team_owner)

func teleport_nearby_units(pos: Vector3, search_radius: float):
	print("🌀 Телепортация юнитов в радиусе ", search_radius, " от ", pos)

func disable_nearby_crystals(pos: Vector3, search_radius: float, effect_duration: float):
	print("💫 Отключение кристаллов в радиусе ", search_radius, " на ", effect_duration, " секунд от ", pos)

func show_notification(message: String):
	print("📢 ", message)
	if battle_manager and battle_manager.notification_system:
		battle_manager.notification_system.show_notification(message)

# Публичные методы для интеграции с BattleManager
func get_crystal_info() -> Array[Dictionary]:
	return crystals

func get_controlled_crystals(team: String) -> int:
	var count = 0
	for crystal in crystals:
		if crystal.owner == team:
			count += 1
	return count

func force_capture_crystal(crystal_id: int, crystal_owner: String):
	if crystal_id < 0 or crystal_id >= crystals.size():
		return false
		
	var crystal = crystals[crystal_id]
	crystal.owner = crystal_owner
	crystal.capture_progress = 0.0
	
	update_crystal_visual(crystal)
	
	crystal_captured.emit(crystal.id, crystal_owner, crystal.type)
	print("💎 Кристалл ", crystal_id, " принудительно захвачен командой ", crystal_owner)
	return true

# НОВАЯ ФУНКЦИЯ: Проверка взаимодействия с кристаллами для всех юнитов
func check_crystal_interaction(unit_position: Vector3, team: String, unit_type: String):
	for crystal in crystals:
		var distance = unit_position.distance_to(crystal.position)
		if distance <= crystal.control_radius:
			if unit_type == "collector":
				# Коллекторы могут захватывать кристаллы
				attempt_collector_capture(crystal, team)
			else:
				# Обычные юниты могут только освобождать вражеские кристаллы
				attempt_crystal_liberation(crystal, team)

# НОВАЯ ФУНКЦИЯ: Захват кристаллов коллекторами (полноценный захват)
func attempt_collector_capture(crystal: Dictionary, team: String):
	if crystal.owner == team:
		return  # Уже захвачен этой командой
	
	# Коллекторы могут захватывать любые кристаллы (нейтральные и вражеские)
	crystal.capture_progress += 1.0
	
	if crystal.capture_progress >= crystal.max_capture_time:
		var old_owner = crystal.owner
		crystal.owner = team
		crystal.capture_progress = 0.0
		
		# Обновляем визуал
		update_crystal_visual(crystal)
		
		# Специальные эффекты при захвате
		apply_capture_effects(crystal, old_owner, team)
		
		crystal_captured.emit(crystal.id, team, crystal.type)
		var crystal_type_name = get_crystal_type_name(crystal.type)
		print("💎 Коллектор ", team, " захватил кристалл ", crystal.id, " (", crystal_type_name, ")")
		
		# Проверяем условия победы
		if battle_manager:
			battle_manager.call_deferred("check_victory_conditions")

# НОВАЯ ФУНКЦИЯ: Освобождение кристаллов обычными юнитами
func attempt_crystal_liberation(crystal: Dictionary, team: String):
	# Обычные юниты могут только освобождать ВРАЖЕСКИЕ кристаллы (делать их нейтральными)
	if crystal.owner == "neutral" or crystal.owner == team:
		return  # Нельзя освобождать свои или уже нейтральные кристаллы
	
	# ИЗМЕНЕНИЕ: Освобождение теперь ДОЛЬШЕ захвата (в 1.5 раза)
	var liberation_time = crystal.max_capture_time * 1.5
	crystal.capture_progress += 1.0
	
	# Проверяем, есть ли на кристалле турели или здания
	if has_defensive_structures_on_crystal(crystal):
		# Если есть турели/здания - сначала нужно их уничтожить
		show_notification("⚠️ Сначала уничтожьте турели и здания на кристалле!")
		return
	
	if crystal.capture_progress >= liberation_time:
		var old_owner = crystal.owner
		crystal.owner = "neutral"  # Делаем кристалл нейтральным
		crystal.capture_progress = 0.0
		
		# Обновляем визуал
		update_crystal_visual(crystal)
		
		# Специальные эффекты освобождения
		apply_liberation_effects(crystal, old_owner, team)
		
		crystal_captured.emit(crystal.id, "neutral", crystal.type)
		var crystal_type_name = get_crystal_type_name(crystal.type)
		print("⚔️ Юнит ", team, " освободил кристалл ", crystal.id, " (", crystal_type_name, ") от ", old_owner, " за ", liberation_time, " секунд")
		
		# Показываем уведомление
		if battle_manager and battle_manager.notification_system:
			battle_manager.notification_system.show_notification("Кристалл " + crystal_type_name + " освобожден после долгой осады!")

# НОВАЯ ФУНКЦИЯ: Проверка наличия оборонительных сооружений на кристалле
func has_defensive_structures_on_crystal(crystal: Dictionary) -> bool:
	var crystal_position = crystal.position
	var search_radius = crystal.control_radius + 2.0  # Немного больше радиуса кристалла
	
	# Ищем турели (превращенные коллекторы)
	var turrets = get_tree().get_nodes_in_group("turrets")
	for turret in turrets:
		if turret.team != crystal.owner:
			continue  # Не наша турель
		var distance = crystal_position.distance_to(turret.global_position)
		if distance <= search_radius:
			return true
	
	# Ищем здания/спавнеры
	var spawners = get_tree().get_nodes_in_group("spawners")
	for spawner in spawners:
		if spawner.team != crystal.owner:
			continue  # Не наше здание
		var distance = crystal_position.distance_to(spawner.global_position)
		if distance <= search_radius:
			return true
	
	# Ищем другие оборонительные структуры
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if "team" in building and building.team != crystal.owner:
			continue  # Не наше здание
		var distance = crystal_position.distance_to(building.global_position)
		if distance <= search_radius:
			return true
	
	return false  # Нет оборонительных сооружений

# Обновляем времена освобождения в функции get_capture_time
func get_liberation_time(type: CrystalType) -> float:
	# Освобождение теперь ДОЛЬШЕ захвата (в 1.5 раза)
	var base_capture_time = get_capture_time(type)
	return base_capture_time * 1.5

# НОВАЯ ФУНКЦИЯ: Эффекты при освобождении кристаллов
func apply_liberation_effects(crystal: Dictionary, previous_owner: String, liberating_team: String):
	print("⚔️ Освобождение кристалла ", crystal.id, " от ", previous_owner, " командой ", liberating_team)
	
	match crystal.type:
		CrystalType.MAIN_CRYSTAL:
			# Освобождение главного кристалла - мощный тактический ход
			show_notification("👑 Главный кристалл освобожден! Враг потерял командный центр!")
			
		CrystalType.ENERGY_CRYSTAL:
			# Энергетический кристалл перестает давать ресурсы врагу
			show_notification("⚡ Энергетический кристалл освобожден!")
			
		CrystalType.UNSTABLE_CRYSTAL:
			# Технологический кристалл - прерывание исследований врага
			show_notification("🔬 Технологический кристалл освобожден! Исследования врага прерваны!")
			
		CrystalType.VOID_CRYSTAL:
			# Био-кристалл перестает лечить врагов
			show_notification("🌿 Био-кристалл освобожден! Враг потерял лечение!")

# Обновляем публичную функцию для вызова из Unit.gd
func check_crystal_capture(unit_position: Vector3, team: String, unit_type: String = "soldier"):
	# Новая универсальная функция для всех типов юнитов
	check_crystal_interaction(unit_position, team, unit_type)

# Добавляем функцию для безопасного получения имени типа кристалла
func get_crystal_type_name(crystal_type: int) -> String:
	match crystal_type:
		CrystalType.MAIN_CRYSTAL: return "MAIN_CRYSTAL"
		CrystalType.ENERGY_CRYSTAL: return "ENERGY_CRYSTAL"
		CrystalType.UNSTABLE_CRYSTAL: return "UNSTABLE_CRYSTAL"
		CrystalType.VOID_CRYSTAL: return "VOID_CRYSTAL"
		_: return "UNKNOWN" 
 
