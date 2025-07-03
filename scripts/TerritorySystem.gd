extends Node
class_name TerritorySystem

# Единая система территорий и кристаллов для TERRION RTS
# Объединяет стратегические точки, кристаллы и ресурсы

signal territory_captured(territory_id, new_owner, territory_type)
signal territory_depleted(territory_id)

var territories: Array[Dictionary] = []
var territory_meshes: Array[MeshInstance3D] = []
var battle_manager = null

# Типы территорий (объединенные)
enum TerritoryType {
	# === ОСНОВНЫЕ РЕСУРСНЫЕ ТЕРРИТОРИИ ===
	ENERGY_MINE,        # Энергетические рудники
	CRYSTAL_MINE,       # Кристальные рудники
	VOID_CRYSTAL,       # Кристаллы пустоты (ультиматы)
	
	# === СТРАТЕГИЧЕСКИЕ ТОЧКИ ===
	CENTER_TRIGGER_1,   # Первый центральный триггер
	CENTER_TRIGGER_2,   # Второй центральный триггер
	ANCIENT_TOWER,      # Башня Предтеч (нейтральная)
	
	# === СПЕЦИАЛЬНЫЕ ТЕРРИТОРИИ ===
	ANCIENT_ALTAR,      # Главный алтарь (победа)
	BATTLEFIELD_SHRINE, # Святилище (лечение)
	DEFENSIVE_TOWER,    # Оборонительная башня
	FACTORY,            # Фабрика (производство)
	
	# === СТАРТОВЫЕ ПОЗИЦИИ ===
	PLAYER_BASE,        # База игрока
	ENEMY_BASE          # База врага
}

func _ready():
	# Создаем территории на карте
	create_territories()
	
	# Таймер для генерации ресурсов
	var resource_timer = Timer.new()
	resource_timer.wait_time = 3.0
	resource_timer.autostart = true
	resource_timer.timeout.connect(_on_resource_generation)
	add_child(resource_timer)

func create_territories():
	# Создаем логичную карту территорий для TERRION
	var territory_configs = [
		# === СТАРТОВЫЕ ПОЗИЦИИ ===
		{"name": "База Игрока", "pos": Vector3(0, 0, 28), "type": TerritoryType.PLAYER_BASE, "value": 1000, "radius": 8.0},
		{"name": "База Врага", "pos": Vector3(0, 0, -28), "type": TerritoryType.ENEMY_BASE, "value": 1000, "radius": 8.0},
		
		# === РЕСУРСНЫЕ ТЕРРИТОРИИ (СИММЕТРИЧНО) ===
		# Энергетические рудники
		{"name": "Энергетический Рудник Юг-Запад", "pos": Vector3(-15, 0, 15), "type": TerritoryType.ENERGY_MINE, "value": 100, "radius": 5.0},
		{"name": "Энергетический Рудник Юг-Восток", "pos": Vector3(15, 0, 15), "type": TerritoryType.ENERGY_MINE, "value": 100, "radius": 5.0},
		{"name": "Энергетический Рудник Север-Запад", "pos": Vector3(-15, 0, -15), "type": TerritoryType.ENERGY_MINE, "value": 100, "radius": 5.0},
		{"name": "Энергетический Рудник Север-Восток", "pos": Vector3(15, 0, -15), "type": TerritoryType.ENERGY_MINE, "value": 100, "radius": 5.0},
		
		# Кристальные рудники
		{"name": "Кристальный Рудник Юг", "pos": Vector3(0, 0, 20), "type": TerritoryType.CRYSTAL_MINE, "value": 150, "radius": 5.0},
		{"name": "Кристальный Рудник Север", "pos": Vector3(0, 0, -20), "type": TerritoryType.CRYSTAL_MINE, "value": 150, "radius": 5.0},
		
		# === СТРАТЕГИЧЕСКИЕ ТОЧКИ ===
		# Центральные триггеры для призыва героя
		{"name": "Триггер Альфа", "pos": Vector3(-8, 0, 0), "type": TerritoryType.CENTER_TRIGGER_1, "value": 200, "radius": 4.0},
		{"name": "Триггер Бета", "pos": Vector3(8, 0, 0), "type": TerritoryType.CENTER_TRIGGER_2, "value": 200, "radius": 4.0},
		
		# Башня Предтеч (нейтральная, в центре)
		{"name": "Башня Предтеч", "pos": Vector3(0, 0, 0), "type": TerritoryType.ANCIENT_TOWER, "value": 300, "radius": 5.5},
		
		# Кристалл пустоты (между ядром и центральной точкой)
		{"name": "Кристалл Пустоты", "pos": Vector3(0, 0, 12), "type": TerritoryType.VOID_CRYSTAL, "value": 250, "radius": 6.0},
		
		# === СПЕЦИАЛЬНЫЕ ТЕРРИТОРИИ ===
		# Оборонительные сооружения
		{"name": "Застава Запад", "pos": Vector3(-20, 0, 0), "type": TerritoryType.DEFENSIVE_TOWER, "value": 120, "radius": 4.5},
		{"name": "Фабрика Восток", "pos": Vector3(20, 0, 0), "type": TerritoryType.FACTORY, "value": 120, "radius": 4.5},
		
		# Святилища
		{"name": "Святилище Юг", "pos": Vector3(0, 0, 8), "type": TerritoryType.BATTLEFIELD_SHRINE, "value": 100, "radius": 4.5},
		{"name": "Святилище Север", "pos": Vector3(0, 0, -8), "type": TerritoryType.BATTLEFIELD_SHRINE, "value": 100, "radius": 4.5},
		
		# Главный алтарь (цель победы)
		{"name": "Главный Алтарь", "pos": Vector3(0, 0, 4), "type": TerritoryType.ANCIENT_ALTAR, "value": 500, "radius": 6.0}
	]
	
	for i in range(territory_configs.size()):
		var config = territory_configs[i]
		var territory = create_territory(i, config["pos"], config["type"], config["value"], config["radius"])
		territories.append(territory)

func create_territory(id: int, position: Vector3, type: TerritoryType, value: int, radius: float) -> Dictionary:
	var territory = {
		"id": id,
		"position": position,
		"type": type,
		"owner": "neutral",
		"capture_progress": 0.0,
		"max_capture_time": 5.0,
		"resource_generation_rate": get_resource_rate(type),
		"control_radius": radius,
		"value": value
	}
	
	# Создаем визуальное представление территории
	create_territory_visual(territory)
	
	return territory

func create_territory_visual(territory: Dictionary):
	var mesh_instance = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = territory.control_radius * 1.1  # Немного уменьшил для баланса
	cylinder.bottom_radius = territory.control_radius * 1.1
	cylinder.height = 0.5  # Увеличил высоту для лучшей видимости
	mesh_instance.mesh = cylinder
	mesh_instance.position = territory.position

	# Создаем визуальную метку территории с КРУПНЫМ текстом
	var label = Label3D.new()
	label.text = get_territory_short_name(territory.type)
	label.position = territory.position + Vector3(0, 3, 0)  # Выше над территорией
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 120  # УВЕЛИЧИЛ с 96 до 120 для максимальной читаемости
	label.modulate = Color.BLACK  # ТЕМНЫЙ ТЕКСТ для читаемости
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.name = TerritoryType.keys()[territory.type] + "_Label"
	# ЯРКИЙ БЕЛЫЙ контур для контраста
	label.outline_size = 20  # Увеличил до 20 для максимального контраста
	label.outline_modulate = Color.WHITE
	get_parent().add_child(label)

	# ЕДИНЫЕ ЦВЕТА для одинаковых типов территорий - яркие и контрастные
	var material = StandardMaterial3D.new()
	match territory.type:
		TerritoryType.ENERGY_MINE:
			# ВСЕ энергетические рудники - ЯРКО-ГОЛУБЫЕ
			material.albedo_color = Color(0.0, 0.9, 1.0, 0.95)  # Ярко-голубой
			material.emission = Color(0.0, 0.7, 1.0)  # Сильное голубое свечение
		TerritoryType.CRYSTAL_MINE:
			# ВСЕ кристальные рудники - ЯРКО-ПУРПУРНЫЕ
			material.albedo_color = Color(1.0, 0.0, 1.0, 0.95)  # Ярко-пурпурный
			material.emission = Color(0.8, 0.0, 0.8)  # Сильное пурпурное свечение
		TerritoryType.DEFENSIVE_TOWER:
			material.albedo_color = Color(1.0, 0.0, 0.0, 0.95)  # Ярко-красный
			material.emission = Color(0.8, 0.0, 0.0)  # Сильное красное свечение
		TerritoryType.FACTORY:
			material.albedo_color = Color(1.0, 0.5, 0.0, 0.95)  # Ярко-оранжевый
			material.emission = Color(0.8, 0.4, 0.0)  # Сильное оранжевое свечение
		TerritoryType.ANCIENT_ALTAR:
			material.albedo_color = Color(1.0, 0.8, 0.0, 0.95)  # Ярко-золотой
			material.emission = Color(0.8, 0.6, 0.0)  # Сильное золотое свечение
		TerritoryType.BATTLEFIELD_SHRINE:
			material.albedo_color = Color(0.0, 1.0, 0.0, 0.95)  # Ярко-зеленый
			material.emission = Color(0.0, 0.8, 0.0)  # Сильное зеленое свечение
		TerritoryType.CENTER_TRIGGER_1, TerritoryType.CENTER_TRIGGER_2:
			material.albedo_color = Color(1.0, 0.8, 0.0, 0.95)  # Ярко-золотой
			material.emission = Color(1.0, 0.6, 0.0)  # Сильное золотое свечение
		TerritoryType.ANCIENT_TOWER:
			material.albedo_color = Color(0.2, 0.2, 0.8, 0.95)  # Темно-синий
			material.emission = Color(0.4, 0.4, 1.0)  # Синее свечение
		TerritoryType.VOID_CRYSTAL:
			material.albedo_color = Color(0.6, 0.0, 0.8, 0.95)  # Темно-пурпурный
			material.emission = Color(0.8, 0.0, 1.0)  # Пурпурное свечение
		TerritoryType.PLAYER_BASE:
			material.albedo_color = Color(0.2, 0.6, 1.0, 0.95)  # Синий игрок
			material.emission = Color(0.1, 0.3, 0.5)  # Синее свечение
		TerritoryType.ENEMY_BASE:
			material.albedo_color = Color(1.0, 0.2, 0.2, 0.95)  # Красный враг
			material.emission = Color(0.5, 0.1, 0.1)  # Красное свечение
		_:
			material.albedo_color = Color(0.6, 0.6, 0.6, 0.95)
			material.emission = Color(0.3, 0.3, 0.3)

	material.flags_transparent = true
	material.emission_enabled = true
	# МАКСИМАЛЬНАЯ интенсивность свечения для видимости
	material.emission_energy = 3.0  # Увеличил с 2.0 до 3.0
	mesh_instance.set_surface_override_material(0, material)
	get_parent().add_child(mesh_instance)
	territory_meshes.append(mesh_instance)

func get_resource_rate(type: TerritoryType) -> int:
	match type:
		TerritoryType.ENERGY_MINE:
			return 15  # Энергия в секунду
		TerritoryType.CRYSTAL_MINE:
			return 10  # Кристаллы в секунду
		TerritoryType.VOID_CRYSTAL:
			return 1   # Медленная генерация энергии для ультиматов
		TerritoryType.ANCIENT_ALTAR:
			return 8   # Бонус к способностям
		TerritoryType.PLAYER_BASE, TerritoryType.ENEMY_BASE:
			return 5   # Базовая генерация ресурсов
		_:
			return 0

func _on_resource_generation():
	for territory in territories:
		if territory.owner != "neutral":
			# Применяем эффекты территорий
			apply_territory_effects(territory)

func apply_territory_effects(territory: Dictionary):
	if not battle_manager:
		return
	
	var territory_owner = territory.owner
	var amount = territory.resource_generation_rate
	
	match territory.type:
		TerritoryType.ENERGY_MINE:
			add_resource(territory_owner, "energy", amount)
			
		TerritoryType.CRYSTAL_MINE:
			add_resource(territory_owner, "crystals", amount)
			
		TerritoryType.VOID_CRYSTAL:
			add_resource(territory_owner, "energy", amount)
			apply_void_crystal_effects(territory)
			
		TerritoryType.DEFENSIVE_TOWER:
			auto_attack_enemies(territory)
			
		TerritoryType.FACTORY:
			auto_produce_units(territory)
			
		TerritoryType.ANCIENT_ALTAR:
			reduce_ability_cooldowns(territory)
			add_resource(territory_owner, "crystals", amount)
			
		TerritoryType.BATTLEFIELD_SHRINE:
			heal_friendly_units(territory)
			
		TerritoryType.CENTER_TRIGGER_1, TerritoryType.CENTER_TRIGGER_2:
			check_hero_summon_conditions()
			
		TerritoryType.ANCIENT_TOWER:
			ancient_tower_attack(territory)
			
		TerritoryType.PLAYER_BASE, TerritoryType.ENEMY_BASE:
			add_resource(territory_owner, "energy", amount)

func add_resource(territory_owner: String, resource_type: String, amount: int):
	match resource_type:
		"energy":
			if territory_owner == "player":
				battle_manager.player_energy += amount
			else:
				battle_manager.enemy_energy += amount
		"crystals":
			if territory_owner == "player":
				battle_manager.player_crystals += amount
			else:
				battle_manager.enemy_crystals += amount

func check_territory_capture(unit_position: Vector3, team: String):
	for territory in territories:
		var distance = unit_position.distance_to(territory.position)
		if distance <= territory.control_radius:
			attempt_capture(territory, team)

func attempt_capture(territory: Dictionary, team: String):
	if territory.owner == team:
		return  # Уже захвачена этой командой
	
	# Освященную башню нельзя атаковать
	if territory.type == TerritoryType.ANCIENT_TOWER and territory.get("consecrated", false):
		print("🏛️ Освященную башню предтеч нельзя атаковать!")
		return
	
	# Логика захвата территории
	territory.capture_progress += 1.0
	
	if territory.capture_progress >= territory.max_capture_time:
		territory.owner = team
		territory.capture_progress = 0.0
		
		# Обновляем визуал
		update_territory_visual(territory)
		
		territory_captured.emit(territory.id, team, territory.type)
		print("🏳️ Территория ", territory.id, " захвачена командой ", team)
		
		# Проверяем условия победы после захвата территории
		if battle_manager:
			battle_manager.call_deferred("check_victory_conditions")

func update_territory_visual(territory: Dictionary):
	var mesh_index = territory.id
	if mesh_index < territory_meshes.size():
		var mesh = territory_meshes[mesh_index]
		var material = mesh.get_surface_override_material(0)
		
		if territory.owner == "player":
			material.albedo_color.r = 0.2
			material.albedo_color.g = 0.6
			material.albedo_color.b = 1.0
		elif territory.owner == "enemy":
			material.albedo_color.r = 1.0
			material.albedo_color.g = 0.2
			material.albedo_color.b = 0.2
		else:
			# Восстанавливаем оригинальный цвет по типу
			match territory.type:
				TerritoryType.ENERGY_MINE:
					material.albedo_color = Color(0.2, 0.8, 1.0, 0.5)
				TerritoryType.CRYSTAL_MINE:
					material.albedo_color = Color(1.0, 0.2, 1.0, 0.5)
				TerritoryType.STRATEGIC_POINT:
					material.albedo_color = Color(1.0, 1.0, 0.2, 0.5)

func get_territory_info() -> Array[Dictionary]:
	return territories

func force_capture_territory(territory_id: int, territory_owner: String):
	# (documentation comment)
	if territory_id < 0 or territory_id >= territories.size():
		return false
		
	var territory = territories[territory_id]
	territory.owner = territory_owner
	territory.capture_progress = 0.0
	
	# Обновляем визуал
	update_territory_visual(territory)
	
	territory_captured.emit(territory_id, territory_owner, territory.type)
	print("🏳️ Территория ", territory_id, " принудительно захвачена командой ", territory_owner)
	return true

func get_controlled_territories(team: String) -> int:
	var count = 0
	for territory in territories:
		if territory.owner == team:
			count += 1
	return count

# Специальные эффекты территорий
func auto_attack_enemies(territory: Dictionary):
	# Находим всех врагов в радиусе и атакуем их
	var enemy_team = "enemy" if territory.owner == "player" else "player"
	
	# Здесь будет логика поиска и атаки врагов
	print("🔥 Defensive tower attacking ", enemy_team, " near territory ", territory.id)

func auto_produce_units(territory: Dictionary):
	# Автоматически производим базовых юнитов
	var territory_owner = territory.owner
	var cost = 20
	
	if territory_owner == "player" and battle_manager.player_energy >= cost:
		battle_manager.player_energy -= cost
		# Спавним юнита рядом с фабрикой
		var spawn_pos = territory.position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		battle_manager.spawn_unit_at_pos("player", spawn_pos, "soldier")
		print("🏭 Factory produced soldier for ", territory_owner)
	elif territory_owner == "enemy" and battle_manager.enemy_energy >= cost:
		battle_manager.enemy_energy -= cost
		var spawn_pos = territory.position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		battle_manager.spawn_unit_at_pos("enemy", spawn_pos, "soldier")
		print("🏭 Factory produced soldier for ", territory_owner)

func teleport_friendly_units(territory: Dictionary):
	# Телепортируем случайного дружественного юнита к порталу
	print("🌀 Portal effect activated for ", territory.owner)

func reduce_ability_cooldowns(territory: Dictionary):
	# Снижаем кулдауны способностей для владельца
	if territory.owner == "player" and battle_manager.has_method("reduce_cooldowns"):
		battle_manager.reduce_cooldowns(0.5)  # Снижаем на 0.5 секунды
	print("✨ Ancient altar reducing cooldowns for ", territory.owner)

func heal_friendly_units(territory: Dictionary):
	# Лечим дружественных юнитов в радиусе
	print("💚 Battlefield shrine healing units for ", territory.owner)

func get_territory_short_name(type) -> String:
	# Короткие и читаемые названия территорий
	match type:
		TerritoryType.ENERGY_MINE:
			return "⚡ ЭНЕРГИЯ\n+15/сек"
		TerritoryType.CRYSTAL_MINE:
			return "💎 КРИСТАЛЛЫ\n+10/сек"
		TerritoryType.VOID_CRYSTAL:
			return "💜 ПУСТОТА\n+1 энергия/сек"
		TerritoryType.DEFENSIVE_TOWER:
			return "🏰 ЗАСТАВА\nАвтоатака"
		TerritoryType.FACTORY:
			return "🏭 ФАБРИКА\nСоздает войска"
		TerritoryType.ANCIENT_ALTAR:
			return "✨ АЛТАРЬ\n💰 ГЛАВНАЯ ЦЕЛЬ!"
		TerritoryType.BATTLEFIELD_SHRINE:
			return "🌿 СВЯТИЛИЩЕ\nЛечение"
		TerritoryType.CENTER_TRIGGER_1:
			return "⚔️ ТРИГГЕР АЛЬФА\nПризыв героя!"
		TerritoryType.CENTER_TRIGGER_2:
			return "⚔️ ТРИГГЕР БЕТА\nПризыв героя!"
		TerritoryType.ANCIENT_TOWER:
			return "🏛️ БАШНЯ ПРЕДТЕЧ\nНейтральная угроза"
		TerritoryType.PLAYER_BASE:
			return "🏠 БАЗА ИГРОКА\nКомандный центр"
		TerritoryType.ENEMY_BASE:
			return "🏠 БАЗА ВРАГА\nКомандный центр"
		_:
			return "❓ ТЕРРИТОРИЯ"

func get_territory_label(type):
	match type:
		TerritoryType.ENERGY_MINE:
			return "⚡ ЭНЕРГИЯ ⚡\n+15/сек"
		TerritoryType.CRYSTAL_MINE:
			return "💎 КРИСТАЛЛЫ 💎\n+10/сек"
		TerritoryType.STRATEGIC_POINT:
			return "🎯 СТРАТЕГИЯ 🎯\n+5 энергии"
		TerritoryType.DEFENSIVE_TOWER:
			return "🏰 БАШНЯ 🏰\nАвтоатака"
		TerritoryType.FACTORY:
			return "🏭 ФАБРИКА 🏭\nСоздает армию"
		TerritoryType.PORTAL:
			return "🌀 ПОРТАЛ 🌀\nТелепорт"
		TerritoryType.ANCIENT_ALTAR:
			return "✨ АЛТАРЬ ✨\n💪 ГЛАВНАЯ ЦЕЛЬ!"
		TerritoryType.BATTLEFIELD_SHRINE:
			return "💚 СВЯТИЛИЩЕ 💚\nЛечение войск"
		# НОВЫЕ ТИПЫ ТЕРРИТОРИЙ
		TerritoryType.CENTER_TRIGGER_1:
			return "⚔️ ТРИГГЕР АЛЬФА ⚔️\nПризыв героя!"
		TerritoryType.CENTER_TRIGGER_2:
			return "⚔️ ТРИГГЕР БЕТА ⚔️\nПризыв героя!"
		TerritoryType.ANCIENT_TOWER:
			return "🏛️ БАШНЯ ПРЕДТЕЧ 🏛️\nНейтральная угроза"
		TerritoryType.VOID_CRYSTAL:
			return "💜 КРИСТАЛЛ ПУСТОТЫ 💜\nАура эффективности"
		_:
			return "❓ ТЕРРИТОРИЯ ❓"

# НОВЫЕ ФУНКЦИИ ДЛЯ СТРАТЕГИЧЕСКИХ МЕХАНИК

# Проверка условий для призыва героя
func check_hero_summon_conditions():
	var trigger_1_captured = false
	var trigger_2_captured = false
	var trigger_1_owner = ""
	var trigger_2_owner = ""
	
	# Проверяем статус обоих триггеров
	for territory in territories:
		if territory.type == TerritoryType.CENTER_TRIGGER_1:
			trigger_1_captured = territory.owner != "neutral"
			trigger_1_owner = territory.owner
		elif territory.type == TerritoryType.CENTER_TRIGGER_2:
			trigger_2_captured = territory.owner != "neutral"
			trigger_2_owner = territory.owner
	
	# Если оба триггера захвачены одной командой - призываем героя и освящаем башню
	if trigger_1_captured and trigger_2_captured and trigger_1_owner == trigger_2_owner:
		if not battle_manager.has("hero_summoned") or not battle_manager.hero_summoned:
			summon_hero(trigger_1_owner)
			consecrate_ancient_tower(trigger_1_owner)
			print("🦸 ГЕРОЙ ПРИЗВАН и БАШНЯ ОСВЯЩЕНА для команды ", trigger_1_owner, "!")

# Призыв героя
func summon_hero(team: String):
	if not battle_manager:
		return
	
	# Помечаем что герой уже призван
	battle_manager.hero_summoned = true
	
	# Определяем позицию спавна героя (рядом с ядром команды)
	var spawn_position = Vector3.ZERO
	if team == "player":
		spawn_position = Vector3(0, 0, 20)  # Позиция ядра игрока
	else:
		spawn_position = Vector3(0, 0, -20)  # Позиция ядра врага
	
	# Спавним героя
	battle_manager.spawn_unit_at_pos(team, spawn_position, "hero")
	
	# Уведомление
	if battle_manager.notification_system:
		battle_manager.notification_system.show_hero_summoned(team)
	
	print("🦸 Герой призван для команды ", team, " в позиции ", spawn_position)

# Освящение башни предтеч
func consecrate_ancient_tower(team: String):
	# Находим башню предтеч и делаем её союзной и неуязвимой
	for territory in territories:
		if territory.type == TerritoryType.ANCIENT_TOWER:
			territory.owner = team
			territory["consecrated"] = true  # Помечаем как освященную
			territory["invulnerable"] = true  # Делаем неуязвимой
			territory["activation_timer"] = 5.0  # Таймер активации 5 секунд
			territory["is_active"] = false  # Пока неактивна
			
			# Запускаем таймер активации
			start_tower_activation_timer(territory)
			
			# Обновляем визуал башни
			update_territory_visual(territory)
			
			print("🏛️ Башня Предтеч освящена для команды ", team, " и станет активной через 5 секунд")
			break

# Таймер активации башни
func start_tower_activation_timer(territory: Dictionary):
	var timer = Timer.new()
	timer.wait_time = territory["activation_timer"]
	timer.one_shot = true
	timer.timeout.connect(func(): activate_consecrated_tower(territory))
	add_child(timer)
	timer.start()

# Активация освященной башни
func activate_consecrated_tower(territory: Dictionary):
	territory["is_active"] = true
	print("🏛️ Башня Предтеч активирована и готова к бою!")

# Атака башни предтеч
func ancient_tower_attack(territory: Dictionary):
	if not battle_manager:
		return
	
	# Если башня освящена, но еще не активирована - не атакуем
	if territory.get("consecrated", false) and not territory.get("is_active", true):
		return
	
	# Башня атакует в зависимости от владельца
	var attack_radius = territory.control_radius * 1.5
	var tower_position = territory.position
	
	# Определяем цели в зависимости от владельца
	var target_team = ""
	if territory.owner == "neutral":
		# Нейтральная башня атакует всех
		target_team = "all"
	elif territory.owner == "player":
		# Союзная башня атакует только врагов
		target_team = "enemy"
	elif territory.owner == "enemy":
		# Вражеская башня атакует только игрока
		target_team = "player"
	
	# Ищем цели
	var units = get_tree().get_nodes_in_group("units")
	var targets = []
	
	for unit in units:
		if unit.global_position.distance_to(tower_position) <= attack_radius:
			if target_team == "all" or unit.team == target_team:
				targets.append(unit)
	
	# Атакуем случайную цель
	if targets.size() > 0:
		var target = targets[randi() % targets.size()]
		ancient_tower_damage_target(target, territory)
		print("🏛️ Башня Предтеч атакует ", target.unit_type, " команды ", target.team)

# Урон от башни предтеч
func ancient_tower_damage_target(target, territory: Dictionary):
	if not target or not is_instance_valid(target):
		return
	
	# Сильный урон от башни
	var damage = 25
	target.take_damage(damage)
	
	# Визуальный эффект
	if battle_manager.effect_system:
		battle_manager.effect_system.create_damage_effect(target.global_position, damage)

# Эффекты кристалла пустоты
func apply_void_crystal_effects(territory: Dictionary):
	if not battle_manager:
		return
	
	var crystal_position = territory.position
	var aura_radius = territory.control_radius
	
	# Генерируем энергию для ультиматов (очень медленно)
	if territory.owner != "neutral":
		var energy_amount = 1  # Очень медленная генерация (было 5)
		add_resource(territory.owner, "energy", energy_amount)
		
		# Применяем ауру эффективности к зданиям в радиусе
		apply_efficiency_aura(crystal_position, aura_radius, territory.owner)
		
		# Блокируем лечение в зоне кристалла
		block_healing_in_zone(crystal_position, aura_radius)

# Аура эффективности для зданий
func apply_efficiency_aura(crystal_position: Vector3, aura_radius: float, team: String):
	var spawners = get_tree().get_nodes_in_group("spawners")
	
	for spawner in spawners:
		if spawner.team == team and spawner.global_position.distance_to(crystal_position) <= aura_radius:
			# Ускоряем постройку и производство
			if spawner.has_method("apply_efficiency_bonus"):
				spawner.apply_efficiency_bonus(1.5)  # +50% эффективности
			print("💜 Аура эффективности применена к ", spawner.name)

# Блокировка лечения в зоне кристалла
func block_healing_in_zone(crystal_position: Vector3, aura_radius: float):
	var units = get_tree().get_nodes_in_group("units")
	
	for unit in units:
		if unit.global_position.distance_to(crystal_position) <= aura_radius:
			# Блокируем лечение для всех юнитов в зоне
			if unit.has_method("block_healing"):
				unit.block_healing(true)
			print("💜 Лечение заблокировано для ", unit.unit_type, " в зоне кристалла")

# Обновляем get_territory_short_name для новых типов
func get_territory_short_name(type) -> String:
	match type:
		TerritoryType.ENERGY_MINE:
			return "⚡ ЭНЕРГИЯ\n+15/сек"
		TerritoryType.CRYSTAL_MINE:
			return "💎 КРИСТАЛЛЫ\n+10/сек"
		TerritoryType.DEFENSIVE_TOWER:
			return "🏰 ЗАСТАВА\nАвтоатака"
		TerritoryType.FACTORY:
			return "🏭 ФАБРИКА\nСоздает войска"
		TerritoryType.ANCIENT_ALTAR:
			return "✨ АЛТАРЬ\n💰 ГЛАВНАЯ ЦЕЛЬ!"
		TerritoryType.BATTLEFIELD_SHRINE:
			return "🌿 СВЯТИЛИЩЕ\nЛечение"
		# НОВЫЕ ТИПЫ
		TerritoryType.CENTER_TRIGGER_1:
			return "⚔️ ТРИГГЕР АЛЬФА\nПризыв героя!"
		TerritoryType.CENTER_TRIGGER_2:
			return "⚔️ ТРИГГЕР БЕТА\nПризыв героя!"
		TerritoryType.ANCIENT_TOWER:
			return "🏛️ БАШНЯ ПРЕДТЕЧ\nНейтральная угроза"
		TerritoryType.VOID_CRYSTAL:
			return "💜 КРИСТАЛЛ ПУСТОТЫ\nАура эффективности"
		_:
			return "❓ ТЕРРИТОРИЯ"
 
 
