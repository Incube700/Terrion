extends Node
class_name TerritorySystem

# Система территорий для захвата зон на карте
# Похоже на Tiny Clash - игроки могут захватывать зоны для получения ресурсов

signal territory_captured(territory_id, new_owner)
signal resource_generated(territory_id, owner, amount)

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
	BATTLEFIELD_SHRINE  # Воскрешает павших юнитов
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
	# Создаем 9 территорий на карте с разными эффектами
	var territory_positions = [
		Vector3(-10, 0.1, -12),  # Левая нижняя
		Vector3(10, 0.1, -12),   # Правая нижняя  
		Vector3(-10, 0.1, 12),   # Левая верхняя
		Vector3(10, 0.1, 12),    # Правая верхняя
		Vector3(-6, 0.1, 0),     # Центр левый
		Vector3(6, 0.1, 0),      # Центр правый
		Vector3(0, 0.1, -6),     # Центр нижний
		Vector3(0, 0.1, 6),      # Центр верхний
		Vector3(0, 0.1, 0)       # Центральная точка
	]
	
	var territory_types = [
		TerritoryType.ENERGY_MINE,      # Ресурсы внизу
		TerritoryType.CRYSTAL_MINE,     # Ресурсы внизу
		TerritoryType.ENERGY_MINE,      # Ресурсы вверху
		TerritoryType.CRYSTAL_MINE,     # Ресурсы вверху
		TerritoryType.DEFENSIVE_TOWER,  # Оборона слева
		TerritoryType.FACTORY,          # Производство справа
		TerritoryType.PORTAL,           # Телепорт внизу
		TerritoryType.BATTLEFIELD_SHRINE, # Воскрешение вверху
		TerritoryType.ANCIENT_ALTAR     # Мощный бонус в центре
	]
	
	for i in range(territory_positions.size()):
		var territory = create_territory(i, territory_positions[i], territory_types[i])
		territories.append(territory)

func create_territory(id: int, position: Vector3, type: TerritoryType) -> Dictionary:
	var territory = {
		"id": id,
		"position": position,
		"type": type,
		"owner": "neutral",
		"capture_progress": 0.0,
		"max_capture_time": 5.0,
		"resource_generation_rate": get_resource_rate(type),
		"control_radius": 3.0
	}
	
	# Создаем визуальное представление территории
	create_territory_visual(territory)
	
	return territory

func create_territory_visual(territory: Dictionary):
	var mesh_instance = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = territory.control_radius
	cylinder.bottom_radius = territory.control_radius
	cylinder.height = 0.2
	mesh_instance.mesh = cylinder
	mesh_instance.position = territory.position
	
	# Материал в зависимости от типа территории
	var material = StandardMaterial3D.new()
	match territory.type:
		TerritoryType.ENERGY_MINE:
			material.albedo_color = Color(0.2, 0.8, 1.0, 0.5)  # Голубой
		TerritoryType.CRYSTAL_MINE:
			material.albedo_color = Color(1.0, 0.2, 1.0, 0.5)  # Пурпурный
		TerritoryType.STRATEGIC_POINT:
			material.albedo_color = Color(1.0, 1.0, 0.2, 0.5)  # Желтый
		TerritoryType.DEFENSIVE_TOWER:
			material.albedo_color = Color(0.8, 0.2, 0.2, 0.5)  # Красный
		TerritoryType.FACTORY:
			material.albedo_color = Color(0.5, 0.5, 0.5, 0.5)  # Серый
		TerritoryType.PORTAL:
			material.albedo_color = Color(0.2, 1.0, 0.2, 0.5)  # Зеленый
		TerritoryType.ANCIENT_ALTAR:
			material.albedo_color = Color(1.0, 0.8, 0.2, 0.5)  # Золотой
		TerritoryType.BATTLEFIELD_SHRINE:
			material.albedo_color = Color(0.8, 0.8, 1.0, 0.5)  # Светло-синий
		_:
			material.albedo_color = Color(0.5, 0.5, 0.5, 0.5)  # Серый
	
	material.flags_transparent = true
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
	
	var owner = territory.owner
	var amount = territory.resource_generation_rate
	
	match territory.type:
		TerritoryType.ENERGY_MINE:
			add_resource(owner, "energy", amount)
			
		TerritoryType.CRYSTAL_MINE:
			add_resource(owner, "crystals", amount)
			
		TerritoryType.STRATEGIC_POINT:
			add_resource(owner, "energy", amount)
			
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
			add_resource(owner, "crystals", amount)
			
		TerritoryType.BATTLEFIELD_SHRINE:
			# Лечение дружественных юнитов в радиусе
			heal_friendly_units(territory)

func add_resource(owner: String, resource_type: String, amount: int):
	match resource_type:
		"energy":
			if owner == "player":
				battle_manager.player_energy += amount
			else:
				battle_manager.enemy_energy += amount
		"crystals":
			if owner == "player":
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
	var _attack_radius = 5.0  # Префикс _ для неиспользуемой переменной
	
	# Здесь будет логика поиска и атаки врагов
	print("🔥 Defensive tower attacking ", enemy_team, " near territory ", territory.id)

func auto_produce_units(territory: Dictionary):
	# Автоматически производим базовых юнитов
	var owner = territory.owner
	var cost = 20
	
	if owner == "player" and battle_manager.player_energy >= cost:
		battle_manager.player_energy -= cost
		# Спавним юнита рядом с фабрикой
		var spawn_pos = territory.position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		battle_manager.spawn_unit_at_pos("player", spawn_pos, "soldier")
		print("🏭 Factory produced soldier for ", owner)
	elif owner == "enemy" and battle_manager.enemy_energy >= cost:
		battle_manager.enemy_energy -= cost
		var spawn_pos = territory.position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		battle_manager.spawn_unit_at_pos("enemy", spawn_pos, "soldier")
		print("🏭 Factory produced soldier for ", owner)

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
	var _heal_radius = 4.0  # Префикс _ для неиспользуемой переменной
	var _heal_amount = 10   # Префикс _ для неиспользуемой переменной
	print("💚 Battlefield shrine healing units for ", territory.owner)
