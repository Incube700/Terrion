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
	ENERGY_MINE,    # Дает энергию
	CRYSTAL_MINE,   # Дает кристаллы (новый ресурс)
	STRATEGIC_POINT # Дает бонус к атаке/защите
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
	# Создаем 6 территорий на карте в стиле Tiny Clash
	var territory_positions = [
		Vector3(-8, 0.1, -8),   # Левая нижняя
		Vector3(8, 0.1, -8),    # Правая нижняя  
		Vector3(-8, 0.1, 8),    # Левая верхняя
		Vector3(8, 0.1, 8),     # Правая верхняя
		Vector3(-5, 0.1, 0),    # Центр левый
		Vector3(5, 0.1, 0)      # Центр правый
	]
	
	var territory_types = [
		TerritoryType.ENERGY_MINE,
		TerritoryType.CRYSTAL_MINE,
		TerritoryType.ENERGY_MINE,
		TerritoryType.CRYSTAL_MINE,
		TerritoryType.STRATEGIC_POINT,
		TerritoryType.STRATEGIC_POINT
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
		_:
			return 0

func _on_resource_generation():
	for territory in territories:
		if territory.owner != "neutral":
			var amount = territory.resource_generation_rate
			resource_generated.emit(territory.id, territory.owner, amount)
			
			# Передаем ресурсы в BattleManager
			if battle_manager:
				if territory.owner == "player":
					if territory.type == TerritoryType.CRYSTAL_MINE:
						battle_manager.player_crystals += amount
					else:
						battle_manager.player_energy += amount
				elif territory.owner == "enemy":
					if territory.type == TerritoryType.CRYSTAL_MINE:
						battle_manager.enemy_crystals += amount
					else:
						battle_manager.enemy_energy += amount

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
		var old_owner = territory.owner
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