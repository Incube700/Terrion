extends Node
class_name RaceAbilitySystem

# Система расовых способностей TERRION RTS
# Управляет пассивными и активными способностями для всех 4 рас

signal ability_used(race, ability_name, position)

var battle_manager = null
var ability_cooldowns: Dictionary = {}
var passive_timers: Dictionary = {}
var active_effects: Array[Dictionary] = []

# Типы рас
enum Race {
	ELECTRIC_UNDEAD,    # Электрическая Нежить
	NATURE_ELVES,       # Эльфы-Друиды
	HUMAN_CORPORATION,  # Корпорация Людей
	SPACE_ORCS         # Космические Орки
}

# Данные способностей
var race_abilities = {
	Race.ELECTRIC_UNDEAD: {
		"name": "Электрическая Нежить",
		"active_ability": {
			"name": "emp_pulse",
			"display_name": "ЭМИ-импульс",
			"description": "Отключает все вражеские здания в радиусе 20м на 30 сек",
			"cooldown": 120.0,
			"cost_energy": 150,
			"cost_crystals": 0,
			"radius": 20.0,
			"duration": 30.0
		},
		"passive_abilities": [
			{
				"name": "electric_discharge",
				"display_name": "Электрический разряд",
				"description": "10% шанс оглушить врага на 1 сек при атаке",
				"chance": 0.1,
				"duration": 1.0
			},
			{
				"name": "cyber_regeneration",
				"display_name": "Кибер-регенерация",
				"description": "+2 HP/сек всем юнитам",
				"heal_rate": 2.0,
				"interval": 1.0
			},
			{
				"name": "techno_virus",
				"display_name": "Техно-вирус",
				"description": "Убитые враги дают +25% ресурсов",
				"resource_bonus": 0.25
			}
		]
	},
	
	Race.NATURE_ELVES: {
		"name": "Эльфы-Друиды",
		"active_ability": {
			"name": "spore_storm",
			"display_name": "Споровая буря",
			"description": "Создает споровое поле 25м радиуса на 60 сек (+25% урона союзникам, -25% врагам)",
			"cooldown": 180.0,
			"cost_energy": 0,
			"cost_crystals": 200,
			"radius": 25.0,
			"duration": 60.0,
			"damage_modifier": 0.25
		},
		"passive_abilities": [
			{
				"name": "nature_regeneration",
				"display_name": "Природная регенерация",
				"description": "+3 HP/сек всем юнитам рядом с био-кристаллами",
				"heal_rate": 3.0,
				"radius": 15.0,
				"interval": 1.0
			},
			{
				"name": "symbiosis",
				"display_name": "Симбиоз",
				"description": "Здания медленно самовосстанавливаются (+1 HP/сек)",
				"heal_rate": 1.0,
				"interval": 1.0
			},
			{
				"name": "spore_protection",
				"display_name": "Споровая защита",
				"description": "-20% урона от дальних атак",
				"damage_reduction": 0.2
			}
		]
	},
	
	Race.HUMAN_CORPORATION: {
		"name": "Корпорация Людей",
		"active_ability": {
			"name": "orbital_strike",
			"display_name": "Орбитальный удар",
			"description": "Мощная атака с орбиты (300 урона) через 5 сек задержки",
			"cooldown": 90.0,
			"cost_energy": 100,
			"cost_crystals": 0,
			"damage": 300,
			"delay": 5.0,
			"radius": 8.0
		},
		"passive_abilities": [
			{
				"name": "tech_network",
				"display_name": "Технологическая сеть",
				"description": "Здания дают +10% эффективности соседним зданиям",
				"efficiency_bonus": 0.1,
				"radius": 12.0
			},
			{
				"name": "automation",
				"display_name": "Автоматизация",
				"description": "Спавнеры работают на 20% быстрее",
				"speed_bonus": 0.2
			},
			{
				"name": "shields",
				"display_name": "Щиты",
				"description": "Все здания имеют +50 HP щитов",
				"shield_amount": 50
			}
		]
	},
	
	Race.SPACE_ORCS: {
		"name": "Космические Орки",
		"active_ability": {
			"name": "mass_rush",
			"display_name": "Массовый раш",
			"description": "Все юниты получают +100% скорости на 20 сек",
			"cooldown": 150.0,
			"cost_energy": 120,
			"cost_crystals": 0,
			"speed_bonus": 1.0,
			"duration": 20.0
		},
		"passive_abilities": [
			{
				"name": "fire_trails",
				"display_name": "Огненные следы",
				"description": "Движущиеся юниты оставляют огонь (5 урона/сек)",
				"damage_per_second": 5.0,
				"trail_duration": 3.0
			},
			{
				"name": "battle_frenzy",
				"display_name": "Боевое безумие",
				"description": "При HP < 50% урон увеличивается на 50%",
				"health_threshold": 0.5,
				"damage_bonus": 0.5
			},
			{
				"name": "fast_construction",
				"display_name": "Быстрое строительство",
				"description": "Здания строятся на 30% быстрее",
				"speed_bonus": 0.3
			}
		]
	}
}

func _ready():
	print("🎭 Инициализация системы расовых способностей...")
	
	# Таймер для обработки пассивных эффектов
	var passive_timer = Timer.new()
	passive_timer.wait_time = 1.0
	passive_timer.autostart = true
	passive_timer.timeout.connect(_process_passive_effects)
	add_child(passive_timer)
	
	# Таймер для обработки активных эффектов
	var effect_timer = Timer.new()
	effect_timer.wait_time = 0.5
	effect_timer.autostart = true
	effect_timer.timeout.connect(_process_active_effects)
	add_child(effect_timer)

func set_battle_manager(manager):
	battle_manager = manager
	print("🎭 Система расовых способностей подключена к BattleManager")

# Проверка возможности использования активной способности
func can_use_ability(team: String, ability_name: String) -> bool:
	if not battle_manager:
		return false
	
	# Проверяем кулдаун
	var cooldown_key = team + "_" + ability_name
	if ability_cooldowns.has(cooldown_key):
		var time_left = ability_cooldowns[cooldown_key] - Time.get_unix_time_from_system()
		if time_left > 0:
			print("❌ Способность ", ability_name, " на кулдауне еще ", time_left, " сек")
			return false
	
	return true

# Использование активной способности
func use_ability(team: String, ability_name: String, position: Vector3) -> bool:
	if not can_use_ability(team, ability_name):
		return false
	
	# Устанавливаем кулдаун
	var cooldown_key = team + "_" + ability_name
	var current_time = Time.get_unix_time_from_system()
	var cooldown_time = get_ability_cooldown_time(ability_name)
	ability_cooldowns[cooldown_key] = current_time + cooldown_time
	
	# Выполняем способность
	execute_ability(team, ability_name, position)
	
	ability_used.emit(0, ability_name, position)  # 0 - заглушка для race
	print("✨ ", team, " использует ", ability_name, " в позиции ", position)
	
	return true

func get_ability_cooldown_time(ability_name: String) -> float:
	match ability_name:
		"emp_pulse": return 120.0
		"spore_storm": return 180.0
		"orbital_strike": return 90.0
		"mass_rush": return 150.0
		_: return 60.0

# Выполнение конкретной способности
func execute_ability(team: String, ability_name: String, position: Vector3):
	match ability_name:
		"emp_pulse":
			execute_emp_pulse(team, position)
		"spore_storm":
			execute_spore_storm(team, position)
		"orbital_strike":
			execute_orbital_strike(team, position)
		"mass_rush":
			execute_mass_rush(team)
		_:
			print("❌ Неизвестная способность: ", ability_name)

# === РЕАЛИЗАЦИЯ АКТИВНЫХ СПОСОБНОСТЕЙ ===

func execute_emp_pulse(team: String, position: Vector3):
	print("⚡ ЭМИ-импульс активирован!")
	
	var radius = 20.0
	var duration = 30.0
	
	# Ищем все вражеские здания в радиусе
	var enemy_team = "enemy" if team == "player" else "player"
	var buildings = get_tree().get_nodes_in_group("spawners")
	
	var affected_buildings = []
	for building in buildings:
		if "team" in building and building.team == enemy_team:
			var distance = position.distance_to(building.global_position)
			if distance <= radius:
				affected_buildings.append(building)
	
	# Отключаем здания
	for building in affected_buildings:
		disable_building(building, duration)
		print("🔌 Здание ", building.name, " отключено на ", duration, " секунд")
	
	# Показываем уведомление
	if battle_manager and battle_manager.notification_system:
		battle_manager.notification_system.show_notification("⚡ ЭМИ-импульс отключил " + str(affected_buildings.size()) + " зданий!")

func execute_spore_storm(team: String, position: Vector3):
	print("🌿 Споровая буря активирована!")
	
	var effect = {
		"type": "spore_storm",
		"team": team,
		"position": position,
		"radius": 25.0,
		"duration": 60.0,
		"damage_modifier": 0.25,
		"start_time": Time.get_unix_time_from_system()
	}
	
	active_effects.append(effect)
	
	if battle_manager and battle_manager.notification_system:
		battle_manager.notification_system.show_notification("🌿 Споровая буря создана! Союзники получают бонус к урону!")

func execute_orbital_strike(team: String, position: Vector3):
	print("🚀 Орбитальный удар запущен командой ", team, "!")
	
	var delay = 5.0
	
	# Создаем таймер для задержки - правильно захватываем position
	var strike_timer = Timer.new()
	strike_timer.wait_time = delay
	strike_timer.one_shot = true
	# Правильный capture переменной position
	strike_timer.timeout.connect(execute_orbital_damage.bind(position))
	add_child(strike_timer)
	strike_timer.start()
	
	if battle_manager and battle_manager.notification_system:
		battle_manager.notification_system.show_notification("🚀 Орбитальный удар через " + str(delay) + " секунд!")

func execute_orbital_damage(position: Vector3):
	print("💥 Орбитальный удар наносит урон!")
	
	var damage = 300
	var radius = 8.0
	
	# Ищем всех юнитов в радиусе поражения
	var units = get_tree().get_nodes_in_group("units")
	var buildings = get_tree().get_nodes_in_group("spawners")
	
	var targets = units + buildings
	var hit_count = 0
	
	for target in targets:
		var distance = position.distance_to(target.global_position)
		if distance <= radius and target.has_method("take_damage"):
			target.take_damage(damage)
			hit_count += 1
	
	print("💥 Орбитальный удар поразил ", hit_count, " целей")

func execute_mass_rush(team: String):
	print("🏍️ Массовый раш активирован!")
	
	var speed_bonus = 1.0
	var duration = 20.0
	
	# Находим всех юнитов команды
	var units = get_tree().get_nodes_in_group("units")
	var affected_units = []
	
	for unit in units:
		if "team" in unit and unit.team == team:
			affected_units.append(unit)
			# Увеличиваем скорость
			unit.speed *= (1.0 + speed_bonus)
	
	# Создаем эффект для отмены бонуса через время
	var effect = {
		"type": "mass_rush",
		"team": team,
		"affected_units": affected_units,
		"speed_bonus": speed_bonus,
		"duration": duration,
		"start_time": Time.get_unix_time_from_system()
	}
	
	active_effects.append(effect)
	
	if battle_manager and battle_manager.notification_system:
		battle_manager.notification_system.show_notification("🏍️ Массовый раш! " + str(affected_units.size()) + " юнитов ускорены!")

# === ОБРАБОТКА ПАССИВНЫХ ЭФФЕКТОВ ===

func _process_passive_effects():
	# Обрабатываем пассивные способности для каждой команды
	process_team_passives("player")
	process_team_passives("enemy")
	
	# Обрабатываем активные эффекты
	_process_active_effects()

func process_team_passives(team: String):
	# Кибер-регенерация для нежити
	if team == "player":  # Пока игрок = нежить
		apply_cyber_regeneration(team)

func apply_cyber_regeneration(team: String):
	var heal_rate = 2.0
	var units = get_tree().get_nodes_in_group("units")
	
	for unit in units:
		if "team" in unit and unit.team == team:
			if unit.health < unit.max_health:
				unit.health = min(unit.health + heal_rate, unit.max_health)
				unit.update_health_display()

# === ОБРАБОТКА АКТИВНЫХ ЭФФЕКТОВ ===

func _process_active_effects():
	var current_time = Time.get_unix_time_from_system()
	
	# Удаляем истекшие эффекты
	for i in range(active_effects.size() - 1, -1, -1):
		var effect = active_effects[i]
		var elapsed = current_time - effect["start_time"]
		
		if elapsed >= effect["duration"]:
			remove_active_effect(effect)
			active_effects.remove_at(i)

func remove_active_effect(effect: Dictionary):
	match effect["type"]:
		"mass_rush":
			# Возвращаем нормальную скорость юнитам
			for unit in effect["affected_units"]:
				if is_instance_valid(unit):
					unit.speed /= (1.0 + effect["speed_bonus"])
			print("🏍️ Массовый раш закончился")

# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===

func disable_building(building, duration: float):
	if building.has_method("disable"):
		building.disable(duration)
	else:
		# Временно отключаем производство
		building.set("production_disabled", true)
		
		var timer = Timer.new()
		timer.wait_time = duration
		timer.one_shot = true
		# Правильный capture переменной building
		timer.timeout.connect(func(): 
			if is_instance_valid(building):
				building.set("production_disabled", false)
		)
		add_child(timer)
		timer.start()

# === ПУБЛИЧНЫЕ МЕТОДЫ ===

func get_ability_cooldown(team: String, ability_name: String) -> float:
	var cooldown_key = team + "_" + ability_name
	
	if ability_cooldowns.has(cooldown_key):
		var current_time = Time.get_unix_time_from_system()
		var time_left = ability_cooldowns[cooldown_key] - current_time
		return max(0.0, time_left)
	
	return 0.0

func is_ability_ready(team: String, ability_name: String) -> bool:
	return get_ability_cooldown(team, ability_name) <= 0.0 
 
 
