extends Node
class_name AbilitySystem

# Система специальных способностей - магические заклинания и тактические умения

signal ability_used(ability_name, position, caster_team)
signal ability_cooldown_finished(ability_name)

var battle_manager = null
var active_abilities: Dictionary = {}
var ability_cooldowns: Dictionary = {}

# Типы способностей
enum AbilityType {
	OFFENSIVE,    # Атакующие способности
	DEFENSIVE,    # Защитные способности
	SUPPORT,      # Поддерживающие способности
	UTILITY       # Утилитарные способности
}

# Данные способностей
var abilities_data = {
	"fireball": {
		"name": "Fireball",
		"type": AbilityType.OFFENSIVE,
		"energy_cost": 40,
		"crystal_cost": 15,
		"cooldown": 8.0,
		"damage": 80,
		"radius": 4.0,
		"description": "Огненный шар наносит урон по площади"
	},
	"heal_wave": {
		"name": "Healing Wave", 
		"type": AbilityType.SUPPORT,
		"energy_cost": 30,
		"crystal_cost": 10,
		"cooldown": 12.0,
		"heal_amount": 60,
		"radius": 5.0,
		"description": "Лечит дружественные юниты в радиусе"
	},
	"shield_barrier": {
		"name": "Shield Barrier",
		"type": AbilityType.DEFENSIVE,
		"energy_cost": 50,
		"crystal_cost": 20,
		"cooldown": 15.0,
		"duration": 10.0,
		"shield_amount": 100,
		"radius": 3.0,
		"description": "Создает защитный барьер"
	},
	"lightning_storm": {
		"name": "Lightning Storm",
		"type": AbilityType.OFFENSIVE,
		"energy_cost": 60,
		"crystal_cost": 25,
		"cooldown": 20.0,
		"damage": 50,
		"radius": 6.0,
		"duration": 5.0,
		"description": "Молниевая буря поражает врагов"
	},
	"teleport_strike": {
		"name": "Teleport Strike",
		"type": AbilityType.UTILITY,
		"energy_cost": 35,
		"crystal_cost": 15,
		"cooldown": 10.0,
		"damage": 120,
		"description": "Телепортирует юнита к цели с уроном"
	}
}

func _ready():
	# Инициализируем кулдауны
	for ability_key in abilities_data.keys():
		ability_cooldowns[ability_key] = 0.0

func _process(delta):
	# Обновляем кулдауны
	update_cooldowns(delta)

func update_cooldowns(delta: float):
	for ability_key in ability_cooldowns.keys():
		if ability_cooldowns[ability_key] > 0:
			ability_cooldowns[ability_key] -= delta
			if ability_cooldowns[ability_key] <= 0:
				ability_cooldowns[ability_key] = 0.0
				ability_cooldown_finished.emit(ability_key)

func can_use_ability(team: String, ability_key: String) -> bool:
	if not abilities_data.has(ability_key):
		return false
	
	var ability = abilities_data[ability_key]
	
	# Проверяем кулдаун
	if ability_cooldowns[ability_key] > 0:
		return false
	
	# Проверяем усталость способностей (если система доступна)
	if battle_manager and battle_manager.ability_fatigue_system:
		if not battle_manager.ability_fatigue_system.can_use_ability(team, ability_key):
			return false
	
	# Проверяем ресурсы
	if team == "player":
		return (battle_manager.player_energy >= ability.energy_cost and 
				battle_manager.player_crystals >= ability.crystal_cost)
	else:
		return (battle_manager.enemy_energy >= ability.energy_cost and 
				battle_manager.enemy_crystals >= ability.crystal_cost)

func use_ability(team: String, ability_key: String, target_position: Vector3) -> bool:
	if not can_use_ability(team, ability_key):
		print("❌ Нельзя использовать способность: ", ability_key)
		return false
	
	var ability = abilities_data[ability_key]
	
	# Снимаем ресурсы
	if team == "player":
		battle_manager.player_energy -= ability.energy_cost
		battle_manager.player_crystals -= ability.crystal_cost
	else:
		battle_manager.enemy_energy -= ability.energy_cost
		battle_manager.enemy_crystals -= ability.crystal_cost
	
	# Запускаем кулдаун
	ability_cooldowns[ability_key] = ability.cooldown
	
	# Регистрируем использование в системе усталости способностей
	if battle_manager and battle_manager.ability_fatigue_system:
		battle_manager.ability_fatigue_system.use_ability(team, ability_key)
	
	# Регистрируем использование в системе метрик баланса
	if battle_manager and battle_manager.balance_metrics_system:
		var effectiveness = 1.0  # Базовая эффективность, можно рассчитать на основе результатов
		battle_manager.balance_metrics_system.register_ability_use(team, ability_key, ability.energy_cost, effectiveness)
	
	# Выполняем способность
	execute_ability(team, ability_key, target_position)
	
	ability_used.emit(ability_key, target_position, team)
	print("✨ ", team, " использует ", ability.name, " в позиции ", target_position)
	
	return true

func execute_ability(team: String, ability_key: String, position: Vector3):
	var ability = abilities_data[ability_key]
	
	match ability_key:
		"fireball":
			cast_fireball(team, position, ability)
		"heal_wave":
			cast_heal_wave(team, position, ability)
		"shield_barrier":
			cast_shield_barrier(team, position, ability)
		"lightning_storm":
			cast_lightning_storm(team, position, ability)
		"teleport_strike":
			cast_teleport_strike(team, position, ability)

func cast_fireball(team: String, position: Vector3, ability: Dictionary):
	# Создаем визуальный эффект
	create_explosion_effect(position, ability.radius, Color.ORANGE)
	
	# Наносим урон всем вражеским юнитам в радиусе
	var enemy_team = "enemy" if team == "player" else "player"
	var units = get_tree().get_nodes_in_group("units")
	
	for unit in units:
		if unit.team == enemy_team:
			var distance = unit.global_position.distance_to(position)
			if distance <= ability.radius:
				var damage = ability.damage
				# Урон уменьшается с расстоянием
				var damage_multiplier = 1.0 - (distance / ability.radius) * 0.5
				damage = int(damage * damage_multiplier)
				unit.take_damage(damage)
				print("🔥 Fireball наносит ", damage, " урона ", unit.team, " ", unit.unit_type)

func cast_heal_wave(team: String, position: Vector3, ability: Dictionary):
	# Создаем визуальный эффект
	create_healing_effect(position, ability.radius, Color.GREEN)
	
	# Лечим дружественные юниты в радиусе
	var units = get_tree().get_nodes_in_group("units")
	
	for unit in units:
		if unit.team == team:
			var distance = unit.global_position.distance_to(position)
			if distance <= ability.radius:
				var heal = ability.heal_amount
				unit.health = min(unit.health + heal, unit.max_health)
				unit.update_health_display()
				print("💚 Heal Wave лечит ", unit.team, " ", unit.unit_type, " на ", heal, " HP")

func cast_shield_barrier(team: String, position: Vector3, ability: Dictionary):
	# Создаем защитный барьер
	create_shield_effect(position, ability.radius, Color.CYAN)
	
	# Добавляем временную защиту юнитам
	var units = get_tree().get_nodes_in_group("units")
	
	for unit in units:
		if unit.team == team:
			var distance = unit.global_position.distance_to(position)
			if distance <= ability.radius:
				# Добавляем временный щит (можно расширить Unit.gd для поддержки щитов)
				unit.health += ability.shield_amount
				print("🛡️ Shield Barrier защищает ", unit.team, " ", unit.unit_type)

func cast_lightning_storm(team: String, position: Vector3, ability: Dictionary):
	# Создаем эффект молниевой бури
	create_lightning_effect(position, ability.radius, Color.YELLOW)
	
	# Создаем таймер для периодического урона
	var storm_timer = Timer.new()
	storm_timer.wait_time = 1.0
	storm_timer.autostart = true
	add_child(storm_timer)
	
	var enemy_team = "enemy" if team == "player" else "player"
	var storm_duration = int(ability.duration)
	
	# Создаем объект для хранения состояния бури
	var storm_data = {
		"ticks_remaining": storm_duration,
		"enemy_team": enemy_team,
		"position": position,
		"radius": ability.radius,
		"damage": ability.damage
	}
	
	storm_timer.timeout.connect(func():
		storm_data.ticks_remaining -= 1
		
		# Наносим урон каждую секунду
		var units = get_tree().get_nodes_in_group("units")
		for unit in units:
			if unit.team == storm_data.enemy_team:
				var distance = unit.global_position.distance_to(storm_data.position)
				if distance <= storm_data.radius:
					unit.take_damage(storm_data.damage)
					print("⚡ Lightning Storm поражает ", unit.team, " ", unit.unit_type)
		
		if storm_data.ticks_remaining <= 0:
			storm_timer.queue_free()
	)

func cast_teleport_strike(team: String, position: Vector3, ability: Dictionary):
	# Находим ближайшего дружественного юнита для телепортации
	var units = get_tree().get_nodes_in_group("units")
	var closest_unit = null
	var closest_distance = 999999.0
	
	for unit in units:
		if unit.team == team:
			var distance = unit.global_position.distance_to(position)
			if distance < closest_distance:
				closest_unit = unit
				closest_distance = distance
	
	if closest_unit:
		# Телепортируем юнита
		closest_unit.global_position = position
		
		# Наносим урон ближайшему врагу
		var enemy_team = "enemy" if team == "player" else "player"
		var target = find_closest_enemy(position, enemy_team, 3.0)
		
		if target:
			target.take_damage(ability.damage)
			print("🌀 Teleport Strike телепортирует ", closest_unit.team, " ", closest_unit.unit_type, " и наносит ", ability.damage, " урона")

func find_closest_enemy(position: Vector3, enemy_team: String, max_range: float):
	var units = get_tree().get_nodes_in_group("units")
	var closest_enemy = null
	var closest_distance = max_range
	
	for unit in units:
		if unit.team != enemy_team or unit.health <= 0:
			continue  # Пропускаем союзников и мертвых
			
		var distance = unit.global_position.distance_to(position)
		if distance < closest_distance:
			closest_enemy = unit
			closest_distance = distance
	
	return closest_enemy

# Визуальные эффекты (упрощенные)
func create_explosion_effect(position: Vector3, radius: float, color: Color):
	create_visual_effect(position, radius, color, 1.0)

func create_healing_effect(position: Vector3, radius: float, color: Color):
	create_visual_effect(position, radius, color, 2.0)

func create_shield_effect(position: Vector3, radius: float, color: Color):
	create_visual_effect(position, radius, color, 3.0)

func create_lightning_effect(position: Vector3, radius: float, color: Color):
	create_visual_effect(position, radius, color, 0.5)

func create_visual_effect(position: Vector3, radius: float, color: Color, duration: float):
	# Создаем временный визуальный эффект
	var effect = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	effect.mesh = sphere
	effect.position = position + Vector3(0, 1, 0)  # Поднимаем над землей
	
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.flags_transparent = true
	material.albedo_color.a = 0.6
	effect.set_surface_override_material(0, material)
	
	get_parent().add_child(effect)
	
	# Удаляем эффект через время
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(func(): effect.queue_free())
	effect.add_child(timer)
	timer.start()

func get_ability_info(ability_key: String) -> Dictionary:
	if abilities_data.has(ability_key):
		var info = abilities_data[ability_key].duplicate()
		info["cooldown_remaining"] = ability_cooldowns.get(ability_key, 0.0)
		return info
	return {}

func get_available_abilities(team: String) -> Array:
	var available = []
	for ability_key in abilities_data.keys():
		if can_use_ability(team, ability_key):
			available.append(ability_key)
	return available 
