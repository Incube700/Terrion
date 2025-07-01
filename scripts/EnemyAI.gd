extends Node
class_name EnemyAI

# Продвинутый AI для противника в TERRION
# Использует различные стратегии и анализирует состояние поля боя

var battle_manager: Node
var difficulty: String = "normal"  # easy, normal, hard

# Стратегические параметры
var current_strategy: String = "balanced"  # rush, defensive, balanced, economic
var strategy_timer: float = 0.0
var strategy_change_interval: float = 30.0  # Меняем стратегию каждые 30 секунд

# Анализ поля боя
var battlefield_analysis: Dictionary = {}
var last_analysis_time: float = 0.0
var analysis_interval: float = 2.0

# Приоритеты строительства
var build_priorities: Array = []
var unit_priorities: Array = []

func _init(manager: Node, diff: String = "normal"):
	battle_manager = manager
	difficulty = diff
	setup_difficulty_parameters()

func setup_difficulty_parameters():
	match difficulty:
		"easy":
			strategy_change_interval = 45.0  # Медленнее меняет стратегию
			analysis_interval = 3.0  # Реже анализирует
		"normal":
			strategy_change_interval = 30.0
			analysis_interval = 2.0
		"hard":
			strategy_change_interval = 20.0  # Быстрее адаптируется
			analysis_interval = 1.5  # Чаще анализирует

func _ready():
	print("EnemyAI инициализирован с уровнем сложности: ", difficulty)

func make_decision(delta: float) -> Dictionary:
	strategy_timer += delta
	
	# Периодически меняем стратегию
	if strategy_timer >= strategy_change_interval:
		change_strategy()
		strategy_timer = 0.0
	
	# Анализируем поле боя
	if Time.get_ticks_msec() / 1000.0 - last_analysis_time >= analysis_interval:
		analyze_battlefield()
		last_analysis_time = Time.get_ticks_msec() / 1000.0
	
	# Принимаем решение на основе текущей стратегии
	return make_strategic_decision()

func analyze_battlefield():
	if not battle_manager:
		return
	
	var analysis = {
		"player_units": count_units("player"),
		"enemy_units": count_units("enemy"),
		"player_spawners": count_spawners("player"),
		"enemy_spawners": count_spawners("enemy"),
		"player_energy": battle_manager.player_energy,
		"enemy_energy": battle_manager.enemy_energy,
		"battlefield_control": calculate_battlefield_control(),
		"threat_level": calculate_threat_level(),
		"economic_advantage": calculate_economic_advantage()
	}
	
	battlefield_analysis = analysis
	print("AI анализ: Игрок юниты=", analysis.player_units, 
		  " Враг юниты=", analysis.enemy_units,
		  " Контроль поля=", analysis.battlefield_control,
		  " Угроза=", analysis.threat_level)

func count_units(team: String) -> Dictionary:
	var units = get_tree().get_nodes_in_group("units")
	var count = {"soldier": 0, "tank": 0, "drone": 0, "total": 0}
	
	for unit in units:
		if unit.team == team:
			count[unit.unit_type] = count.get(unit.unit_type, 0) + 1
			count.total += 1
	
	return count

func count_spawners(team: String) -> Dictionary:
	var spawners = get_tree().get_nodes_in_group("spawners")
	var count = {"spawner": 0, "tower": 0, "barracks": 0, "total": 0}
	
	for spawner in spawners:
		if spawner.team == team:
			var type = spawner.spawner_type if spawner.has_method("get") else "spawner"
			count[type] = count.get(type, 0) + 1
			count.total += 1
	
	return count

func calculate_battlefield_control() -> float:
	# Рассчитываем контроль поля боя (0.0 = полный контроль игрока, 1.0 = полный контроль AI)
	var player_units = battlefield_analysis.get("player_units", {}).get("total", 0)
	var enemy_units = battlefield_analysis.get("enemy_units", {}).get("total", 0)
	var total_units = player_units + enemy_units
	
	if total_units == 0:
		return 0.5  # Нейтральное поле
	
	return float(enemy_units) / float(total_units)

func calculate_threat_level() -> float:
	# Рассчитываем уровень угрозы от игрока (0.0 = нет угрозы, 1.0 = критическая угроза)
	var player_units = battlefield_analysis.get("player_units", {})
	var enemy_units = battlefield_analysis.get("enemy_units", {})
	
	var player_power = calculate_army_power(player_units)
	var enemy_power = calculate_army_power(enemy_units)
	
	if enemy_power == 0:
		return 1.0  # Критическая угроза, если у нас нет армии
	
	var threat = float(player_power) / float(player_power + enemy_power)
	return clamp(threat, 0.0, 1.0)

func calculate_army_power(units: Dictionary) -> int:
	# Рассчитываем общую силу армии
	var power = 0
	power += units.get("soldier", 0) * 20  # Базовая сила солдата
	power += units.get("tank", 0) * 40     # Танки сильнее
	power += units.get("drone", 0) * 15    # Дроны быстрые, но слабые
	return power

func calculate_economic_advantage() -> float:
	# Рассчитываем экономическое преимущество (-1.0 = игрок сильнее, 1.0 = AI сильнее)
	var player_energy = battlefield_analysis.get("player_energy", 100)
	var enemy_energy = battlefield_analysis.get("enemy_energy", 100)
	var player_spawners = battlefield_analysis.get("player_spawners", {}).get("total", 1)
	var enemy_spawners = battlefield_analysis.get("enemy_spawners", {}).get("total", 1)
	
	var player_economy = player_energy + player_spawners * 10
	var enemy_economy = enemy_energy + enemy_spawners * 10
	
	var total_economy = player_economy + enemy_economy
	if total_economy == 0:
		return 0.0
	
	return (float(enemy_economy) - float(player_economy)) / float(total_economy)

func change_strategy():
	var threat = battlefield_analysis.get("threat_level", 0.5)
	var control = battlefield_analysis.get("battlefield_control", 0.5)
	var economy = battlefield_analysis.get("economic_advantage", 0.0)
	
	# Выбираем стратегию на основе анализа
	if threat > 0.7:
		current_strategy = "defensive"  # Высокая угроза - обороняемся
	elif control > 0.6 and economy > 0.2:
		current_strategy = "rush"  # Контролируем поле и есть ресурсы - атакуем
	elif economy < -0.3:
		current_strategy = "economic"  # Слабая экономика - развиваемся
	else:
		current_strategy = "balanced"  # Сбалансированная стратегия
	
	print("AI сменил стратегию на: ", current_strategy)
	update_priorities()

func update_priorities():
	match current_strategy:
		"rush":
			unit_priorities = ["soldier", "tank", "drone"]
			build_priorities = ["spawner", "barracks", "tower"]
		"defensive":
			unit_priorities = ["tank", "soldier", "drone"]
			build_priorities = ["tower", "spawner", "barracks"]
		"economic":
			unit_priorities = ["soldier", "drone", "tank"]
			build_priorities = ["spawner", "spawner", "barracks"]
		"balanced":
			unit_priorities = ["soldier", "tank", "drone"]
			build_priorities = ["spawner", "tower", "barracks"]

func make_strategic_decision() -> Dictionary:
	var decision = {
		"action": "none",
		"unit_type": "",
		"structure_type": "",
		"position": Vector3.ZERO,
		"priority": 0
	}
	
	if not battle_manager:
		return decision
	
	var enemy_energy = battle_manager.enemy_energy
	var enemy_crystals = battle_manager.enemy_crystals
	var threat = battlefield_analysis.get("threat_level", 0.5)
	var control = battlefield_analysis.get("battlefield_control", 0.5)
	
	# Принимаем решение на основе приоритетов и ситуации
	var ability_decision = consider_ability_use(enemy_energy, enemy_crystals)
	var spawn_decision = consider_unit_spawn(enemy_energy, threat, control)
	var build_decision = consider_building(enemy_energy, threat, control)
	
	# Выбираем решение с наивысшим приоритетом
	if ability_decision.priority > spawn_decision.priority and ability_decision.priority > build_decision.priority:
		return ability_decision
	elif spawn_decision.priority > build_decision.priority:
		return spawn_decision
	elif build_decision.priority > 0:
		return build_decision
	
	return decision

func consider_unit_spawn(energy: int, threat: float, control: float) -> Dictionary:
	var decision = {"action": "none", "unit_type": "", "priority": 0, "position": Vector3.ZERO}
	
	for unit_type in unit_priorities:
		var cost = battle_manager.get_unit_cost(unit_type)
		if energy >= cost:
			var priority = calculate_unit_priority(unit_type, threat, control)
			if priority > decision.priority:
				decision.action = "spawn"
				decision.unit_type = unit_type
				decision.priority = priority
				decision.position = get_optimal_spawn_position(unit_type)
	
	return decision

func consider_building(energy: int, threat: float, control: float) -> Dictionary:
	var decision = {"action": "none", "structure_type": "", "priority": 0, "position": Vector3.ZERO}
	
	for structure_type in build_priorities:
		var cost = battle_manager.get_structure_cost(structure_type)
		if energy >= cost:
			var priority = calculate_build_priority(structure_type, threat, control)
			if priority > decision.priority:
				decision.action = "build"
				decision.structure_type = structure_type
				decision.priority = priority
				decision.position = get_optimal_build_position(structure_type)
	
	return decision

func calculate_unit_priority(unit_type: String, threat: float, control: float) -> int:
	var base_priority = 0
	var enemy_units = battlefield_analysis.get("enemy_units", {})
	
	match unit_type:
		"soldier":
			base_priority = 50
			# Больше приоритет если мало солдат
			if enemy_units.get("soldier", 0) < 2:
				base_priority += 30
		"tank":
			base_priority = 30
			# Больше приоритет при высокой угрозе
			if threat > 0.6:
				base_priority += 40
		"drone":
			base_priority = 20
			# Больше приоритет при хорошем контроле поля
			if control > 0.5:
				base_priority += 25
	
	# Модификаторы стратегии
	match current_strategy:
		"rush":
			if unit_type == "soldier":
				base_priority += 20
		"defensive":
			if unit_type == "tank":
				base_priority += 25
		"economic":
			base_priority = int(base_priority * 0.7)  # Меньше фокуса на юнитах
	
	return base_priority

func calculate_build_priority(structure_type: String, threat: float, _control: float) -> int:
	var base_priority = 0
	var enemy_spawners = battlefield_analysis.get("enemy_spawners", {})
	
	match structure_type:
		"spawner":
			base_priority = 40
			# Больше приоритет если мало спавнеров
			if enemy_spawners.get("total", 0) < 3:
				base_priority += 30
		"tower":
			base_priority = 25
			# Больше приоритет при угрозе
			if threat > 0.5:
				base_priority += 35
		"barracks":
			base_priority = 20
			# Больше приоритет при хорошей экономике
			var economy = battlefield_analysis.get("economic_advantage", 0.0)
			if economy > 0.2:
				base_priority += 30
	
	# Модификаторы стратегии
	match current_strategy:
		"rush":
			if structure_type == "barracks":
				base_priority += 25
		"defensive":
			if structure_type == "tower":
				base_priority += 30
		"economic":
			if structure_type == "spawner":
				base_priority += 35
	
	return base_priority

func get_optimal_spawn_position(_unit_type: String) -> Vector3:
	# Выбираем оптимальную позицию для спавна в зависимости от стратегии
	match current_strategy:
		"rush":
			# Агрессивная позиция ближе к центру
			return Vector3(randf_range(-6.0, 6.0), 0, randf_range(2.0, 6.0))
		"defensive":
			# Оборонительная позиция ближе к базе
			return Vector3(randf_range(-8.0, 8.0), 0, randf_range(8.0, 12.0))
		_:
			# Сбалансированная позиция
			return Vector3(randf_range(-7.0, 7.0), 0, randf_range(5.0, 10.0))

func get_optimal_build_position(structure_type: String) -> Vector3:
	# Выбираем оптимальную позицию для постройки
	match structure_type:
		"tower":
			# Башни ближе к линии фронта
			return Vector3(randf_range(-5.0, 5.0), 0, randf_range(3.0, 7.0))
		"spawner", "barracks":
			# Спавнеры и бараки ближе к базе
			return Vector3(randf_range(-6.0, 6.0), 0, randf_range(8.0, 12.0))
		_:
			return Vector3(randf_range(-6.0, 6.0), 0, randf_range(5.0, 10.0))

func consider_ability_use(_energy: int, _crystals: int) -> Dictionary:
	# Анализируем, стоит ли использовать способности
	var threat_level = analyze_threat_level()
	var field_control = analyze_field_control()
	
	if threat_level > 70 and _crystals >= 20:
		return {
			"action": "ability",
			"ability_type": "shield_barrier",
			"position": get_defensive_position(),
			"priority": 85
		}
	
	if _energy >= 60 and _crystals >= 25 and field_control < 30:
		return {
			"action": "ability", 
			"ability_type": "lightning_storm",
			"position": get_offensive_position(),
			"priority": 75
		}
	
	return {"action": "none", "priority": 0}

func analyze_threat_level() -> float:
	# Реализация функции анализа угрозы
	return 0.0  # Заглушка, реальная реализация должна быть реализована

func analyze_field_control() -> float:
	# Реализация функции анализа контроля поля
	return 0.0  # Заглушка, реальная реализация должна быть реализована

func get_defensive_position() -> Vector3:
	# Реализация функции получения оборонительной позиции
	return Vector3.ZERO  # Заглушка, реальная реализация должна быть реализована

func get_offensive_position() -> Vector3:
	# Реализация функции получения атакующей позиции
	return Vector3.ZERO  # Заглушка, реальная реализация должна быть реализована

func get_strategy_info() -> Dictionary:
	return {
		"current_strategy": current_strategy,
		"difficulty": difficulty,
		"battlefield_analysis": battlefield_analysis,
		"unit_priorities": unit_priorities,
		"build_priorities": build_priorities
	}
