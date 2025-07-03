extends Node
class_name TerritorySystem

# Система территорий для захвата зон на карте
# Похоже на Tiny Clash - игроки могут захватывать зоны для получения ресурсов

signal territory_captured(territory_id, new_owner)

var territories: Array[Dictionary] = []
var territory_meshes: Array[MeshInstance3D] = []
var battle_manager = null

# Типы территорий
enum TerritoryType {
	NEUTRAL,
	ENERGY_MINE,        # Дает энергию
	CRYSTAL_MINE,       # Дает кристаллы
	STRATEGIC_POINT,    # Дает бонус к атаке/защите
	DEFENSIVE_TOWER,    # Автоматически атакует врагов
	FACTORY,            # Автоматически производит юнитов
	PORTAL,             # Телепортирует юнитов
	ANCIENT_ALTAR,      # Дает мощные бонусы способностей
	BATTLEFIELD_SHRINE, # Воскрешает павших юнитов
	# НОВЫЕ ТИПЫ ТЕРРИТОРИЙ
	CENTER_TRIGGER_1,   # Первый центральный триггер
	CENTER_TRIGGER_2,   # Второй центральный триггер
	ANCIENT_TOWER,      # Башня Предтеч (нейтральная, стреляет по всем)
	VOID_CRYSTAL        # Кристалл пустоты (аура эффективности + энергия для ультиматов)
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
	# Создаем СПРАВЕДЛИВО распределенные территории для обеих сторон
	var territory_configs = [
		# === РЕСУРСНЫЕ ТЕРРИТОРИИ (ПОРОВНУ ДЛЯ КАЖДОЙ СТОРОНЫ) ===
		# Зона игрока (нижняя половина)
		{"name": "Энергетический Рудник Юг", "pos": Vector3(-12, 0, 15), "type": TerritoryType.ENERGY_MINE, "value": 100, "radius": 5.0},
		{"name": "Кристальный Рудник Юг", "pos": Vector3(12, 0, 15), "type": TerritoryType.CRYSTAL_MINE, "value": 100, "radius": 5.0},
		
		# Зона врага (верхняя половина)
		{"name": "Энергетический Рудник Север", "pos": Vector3(-12, 0, -15), "type": TerritoryType.ENERGY_MINE, "value": 100, "radius": 5.0},
		{"name": "Кристальный Рудник Север", "pos": Vector3(12, 0, -15), "type": TerritoryType.CRYSTAL_MINE, "value": 100, "radius": 5.0},
		
		# === СИММЕТРИЧНЫЕ БОКОВЫЕ ТЕРРИТОРИИ ===
		{"name": "Левая Застава", "pos": Vector3(-18, 0, 0), "type": TerritoryType.DEFENSIVE_TOWER, "value": 120, "radius": 4.5},
		{"name": "Правая Фабрика", "pos": Vector3(18, 0, 0), "type": TerritoryType.FACTORY, "value": 120, "radius": 4.5},
		
		# === ЦЕНТРАЛЬНЫЕ НЕЙТРАЛЬНЫЕ ТЕРРИТОРИИ ===
		{"name": "Центральный Алтарь", "pos": Vector3(0, 0, 0), "type": TerritoryType.ANCIENT_ALTAR, "value": 200, "radius": 6.0},
		{"name": "Северное Святилище", "pos": Vector3(0, 0, -8), "type": TerritoryType.BATTLEFIELD_SHRINE, "value": 100, "radius": 4.5},
		{"name": "Южное Святилище", "pos": Vector3(0, 0, 8), "type": TerritoryType.BATTLEFIELD_SHRINE, "value": 100, "radius": 4.5},
		
		# === НОВЫЕ СТРАТЕГИЧЕСКИЕ ТОЧКИ ===
		# Центральные триггеры для призыва героя
		{"name": "Триггер Альфа", "pos": Vector3(-8, 0, 0), "type": TerritoryType.CENTER_TRIGGER_1, "value": 150, "radius": 4.0},
		{"name": "Триггер Бета", "pos": Vector3(8, 0, 0), "type": TerritoryType.CENTER_TRIGGER_2, "value": 150, "radius": 4.0},
		
		# Башня Предтеч (нейтральная, в центре между триггерами)
		{"name": "Башня Предтеч", "pos": Vector3(0, 0, 0), "type": TerritoryType.ANCIENT_TOWER, "value": 300, "radius": 5.5},
		
		# Кристалл пустоты (между ядром и центральной точкой)
		{"name": "Кристалл Пустоты", "pos": Vector3(0, 0, 12), "type": TerritoryType.VOID_CRYSTAL, "value": 250, "radius": 6.0}
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
		TerritoryType.STRATEGIC_POINT:
			material.albedo_color = Color(1.0, 1.0, 0.0, 0.95)  # Ярко-желтый
			material.emission = Color(0.8, 0.8, 0.0)  # Сильное желтое свечение
		TerritoryType.DEFENSIVE_TOWER:
			# Оборонительные заставы - ЯРКО-КРАСНЫЕ
			material.albedo_color = Color(1.0, 0.0, 0.0, 0.95)  # Ярко-красный
			material.emission = Color(0.8, 0.0, 0.0)  # Сильное красное свечение
		TerritoryType.FACTORY:
			# Фабрики - ЯРКО-ОРАНЖЕВЫЕ
			material.albedo_color = Color(1.0, 0.5, 0.0, 0.95)  # Ярко-оранжевый
			material.emission = Color(0.8, 0.4, 0.0)  # Сильное оранжевое свечение
		TerritoryType.PORTAL:
			material.albedo_color = Color(0.0, 1.0, 0.0, 0.95)  # Ярко-зеленый
			material.emission = Color(0.0, 0.8, 0.0)  # Сильное зеленое свечение
		TerritoryType.ANCIENT_ALTAR:
			# Главный алтарь - ЗОЛОТОЙ (особый)
			material.albedo_color = Color(1.0, 0.8, 0.0, 0.95)  # Ярко-золотой
			material.emission = Color(0.8, 0.6, 0.0)  # Сильное золотое свечение
		TerritoryType.BATTLEFIELD_SHRINE:
			# ВСЕ святилища - ЯРКО-ЗЕЛЕНЫЕ
			material.albedo_color = Color(0.0, 1.0, 0.0, 0.95)  # Ярко-зеленый
			material.emission = Color(0.0, 0.8, 0.0)  # Сильное зеленое свечение
		# НОВЫЕ ТИПЫ ТЕРРИТОРИЙ
		TerritoryType.CENTER_TRIGGER_1, TerritoryType.CENTER_TRIGGER_2:
			# Центральные триггеры - ЯРКО-ЗОЛОТЫЕ
			material.albedo_color = Color(1.0, 0.8, 0.0, 0.95)  # Ярко-золотой
			material.emission = Color(1.0, 0.6, 0.0)  # Сильное золотое свечение
		TerritoryType.ANCIENT_TOWER:
			# Башня Предтеч - ТЕМНО-СИНЯЯ с пульсацией
			material.albedo_color = Color(0.2, 0.2, 0.8, 0.95)  # Темно-синий
			material.emission = Color(0.4, 0.4, 1.0)  # Синее свечение
		TerritoryType.VOID_CRYSTAL:
			# Кристалл пустоты - ТЕМНО-ПУРПУРНЫЙ с пульсацией
			material.albedo_color = Color(0.6, 0.0, 0.8, 0.95)  # Темно-пурпурный
			material.emission = Color(0.8, 0.0, 1.0)  # Пурпурное свечение
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
		TerritoryType.STRATEGIC_POINT:
			return 5   # Бонусная энергия
		TerritoryType.ANCIENT_ALTAR:
			return 8   # Бонус к способностям
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
			
		TerritoryType.STRATEGIC_POINT:
			add_resource(territory_owner, "energy", amount)
			
		TerritoryType.DEFENSIVE_TOWER:
			# Автоматическая атака ближайших врагов
			auto_attack_enemies(territory)
			
		TerritoryType.FACTORY:
			# Автоматическое производство юнитов
			auto_produce_units(territory)
			
		TerritoryType.PORTAL:
			# Телепортация дружественных юнитов
			teleport_friendly_units(territory)
			
		TerritoryType.ANCIENT_ALTAR:
			# Снижение кулдаунов способностей
			reduce_ability_cooldowns(territory)
			add_resource(territory_owner, "crystals", amount)
			
		TerritoryType.BATTLEFIELD_SHRINE:
			# Лечение дружественных юнитов в радиусе
			heal_friendly_units(territory)
			
		# НОВЫЕ ТИПЫ ТЕРРИТОРИЙ
		TerritoryType.CENTER_TRIGGER_1, TerritoryType.CENTER_TRIGGER_2:
			# Центральные триггеры - проверяем условия для призыва героя
			check_hero_summon_conditions()
			
		TerritoryType.ANCIENT_TOWER:
			# Башня Предтеч - автоматическая атака всех врагов
			ancient_tower_attack(territory)
			
		TerritoryType.VOID_CRYSTAL:
			# Кристалл пустоты - аура эффективности и генерация энергии для ультиматов
			apply_void_crystal_effects(territory)

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
	
	# Логика захвата территории
	territory.capture_progress += 1.0
	
	if territory.capture_progress >= territory.max_capture_time:
		territory.owner = team
		territory.capture_progress = 0.0
		
		# Обновляем визуал
		update_territory_visual(territory)
		
		territory_captured.emit(territory.id, team)
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
	
	territory_captured.emit(territory_id, territory_owner)
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
	
	# Если оба триггера захвачены одной командой - призываем героя
	if trigger_1_captured and trigger_2_captured and trigger_1_owner == trigger_2_owner:
		if not battle_manager.has("hero_summoned") or not battle_manager.hero_summoned:
			summon_hero(trigger_1_owner)
			print("🦸 ГЕРОЙ ПРИЗВАН для команды ", trigger_1_owner, "!")

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

# Атака башни предтеч
func ancient_tower_attack(territory: Dictionary):
	if not battle_manager:
		return
	
	# Башня атакует всех врагов в радиусе, независимо от владельца
	var attack_radius = territory.control_radius * 1.5
	var tower_position = territory.position
	
	# Ищем всех юнитов в радиусе
	var units = get_tree().get_nodes_in_group("units")
	var targets = []
	
	for unit in units:
		if unit.global_position.distance_to(tower_position) <= attack_radius:
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
	
	# Генерируем энергию для ультиматов
	if territory.owner != "neutral":
		var energy_amount = 5  # Энергия для ультиматов
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
 
 
