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

var ai_config = preload("res://scripts/ai_config.gd")

func _init(manager: Node, diff: String = "normal"):
	battle_manager = manager
	difficulty = diff
	setup_difficulty_parameters()

func setup_difficulty_parameters():
	strategy_change_interval = ai_config.STRATEGY_CHANGE_INTERVAL.get(difficulty, 30.0)
	analysis_interval = ai_config.ANALYSIS_INTERVAL.get(difficulty, 2.0)

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
		"economic_advantage": calculate_economic_advantage(),
		"player_crystals": 0,
		"enemy_crystals": 0,
		"base_threat": 0.0
	}

	# Подсчёт захваченных кристаллов
	if battle_manager.has("crystal_system") and battle_manager.crystal_system:
		var crystals = battle_manager.crystal_system.get_crystal_info()
		for crystal in crystals:
			if crystal.owner == "player":
				analysis.player_crystals += 1
			elif crystal.owner == "enemy":
				analysis.enemy_crystals += 1

	# Угроза базе: враги в радиусе THREAT_RADIUS от ядра
	var base_pos = battle_manager.enemy_core.global_position if battle_manager.has("enemy_core") and battle_manager.enemy_core else Vector3.ZERO
	var units = get_tree().get_nodes_in_group("units")
	var threat_count = 0
	for unit in units:
		if unit.team == "player" and unit.global_position.distance_to(base_pos) < ai_config.THREAT_RADIUS:
			threat_count += 1
	analysis.base_threat = float(threat_count) * ai_config.WEIGHT_BASE_THREAT

	# Итоговый анализ с весами
	analysis.total_score = (
		analysis.enemy_crystals * ai_config.WEIGHT_CRYSTAL
		- analysis.player_crystals * ai_config.WEIGHT_CRYSTAL
		+ analysis.base_threat
		+ analysis.economic_advantage * ai_config.WEIGHT_ECON_ADVANTAGE
	)

	battlefield_analysis = analysis
	print("AI анализ: ", analysis)

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
	power += units.get("soldier", 0) * ai_config.UNIT_POWER["soldier"] * ai_config.WEIGHTS_UNIT_TYPE["soldier"]
	power += units.get("tank", 0) * ai_config.UNIT_POWER["tank"] * ai_config.WEIGHTS_UNIT_TYPE["tank"]
	power += units.get("drone", 0) * ai_config.UNIT_POWER["drone"] * ai_config.WEIGHTS_UNIT_TYPE["drone"]
	return power

func calculate_economic_advantage() -> float:
	# Рассчитываем экономическое преимущество (-1.0 = игрок сильнее, 1.0 = AI сильнее)
	var player_energy = battlefield_analysis.get("player_energy", 100)
	var enemy_energy = battle_manager.enemy_energy
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
	var base_threat = battlefield_analysis.get("base_threat", 0.0)
	var player_collectors = battlefield_analysis.get("player_units", {}).get("collector", 0)
	var player_towers = battlefield_analysis.get("player_spawners", {}).get("tower", 0)
	var free_crystals = 0
	if battle_manager.has("crystal_system") and battle_manager.crystal_system:
		var crystals = battle_manager.crystal_system.get_crystal_info()
		for crystal in crystals:
			if crystal.owner == "neutral":
				free_crystals += 1

	# Новые условия для стратегий
	if free_crystals >= 2:
		current_strategy = "capture"  # Много свободных кристаллов — захват
	elif base_threat > ai_config.WEIGHT_BASE_THREAT * 1.5:
		current_strategy = "fortify"  # База или кристаллы под угрозой — усиленная оборона
	elif player_collectors >= 3 and player_towers < 2:
		current_strategy = "harass"  # У врага много коллекторов и мало башен — рейды
	elif threat > 0.7:
		current_strategy = "defensive"
	elif control > 0.6 and economy > 0.2:
		current_strategy = "rush"
	elif economy < -0.3:
		current_strategy = "economic"
	else:
		current_strategy = "balanced"

	print("AI сменил стратегию на: ", current_strategy)
	update_priorities()

func update_priorities():
	unit_priorities = ai_config.UNIT_PRIORITIES.get(current_strategy, ["soldier", "tank", "drone"])
	build_priorities = ai_config.BUILD_PRIORITIES.get(current_strategy, ["spawner", "tower", "barracks"])

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

	# Если угроза базе высокая — строим башню
	if battlefield_analysis.get("base_threat", 0.0) > ai_config.WEIGHT_BASE_THREAT:
		decision.action = "build"
		decision.structure_type = "tower"
		decision.position = get_optimal_build_position("tower")
		decision.priority = calculate_build_priority("tower")
		return decision

	# Если экономическое преимущество — атакуем
	if battlefield_analysis.get("economic_advantage", 0.0) > 0.2:
		decision.action = "spawn"
		decision.unit_type = unit_priorities[0]
		decision.position = get_optimal_spawn_position(unit_priorities[0])
		decision.priority = 2
		return decision

	# Если мало кристаллов — захватываем
	if battlefield_analysis.get("enemy_crystals", 0) < 2:
		decision.action = "capture"
		decision.unit_type = "collector"
		decision.position = get_optimal_spawn_position("collector")
		decision.priority = 1.5
		return decision

	# По умолчанию — сбалансированное поведение
	decision.action = "spawn"
	decision.unit_type = unit_priorities[0]
	decision.position = get_optimal_spawn_position(unit_priorities[0])
	decision.priority = 1
	return decision

func calculate_build_priority(structure_type: String) -> float:
	# Базовый приоритет по стратегии
	var base_priority = 1.0
	if build_priorities.has(structure_type):
		base_priority += 2.0 - build_priorities.find(structure_type) * 0.5

	# Динамические параметры
	var control = battlefield_analysis.get("battlefield_control", 0.5)
	var econ = battlefield_analysis.get("economic_advantage", 0.0)
	var base_threat = battlefield_analysis.get("base_threat", 0.0)
	var enemy_crystals = battlefield_analysis.get("enemy_crystals", 0)
	var player_crystals = battlefield_analysis.get("player_crystals", 0)

	# Весовые коэффициенты
	var score = base_priority
	score += econ * ai_config.WEIGHT_ECON_ADVANTAGE
	score += (enemy_crystals - player_crystals) * ai_config.WEIGHT_CRYSTAL
	score += base_threat
	if structure_type == "tower":
		score += base_threat * 2.0  # Усиливаем приоритет башен при угрозе
	if structure_type == "spawner":
		score += econ * 1.5  # Усиливаем приоритет спавнеров при экономическом преимуществе
	return score

func get_optimal_spawn_position(unit_type: String) -> Vector3:
	# Получаем все возможные позиции спавна (например, позиции спавнеров AI)
	var spawners = get_tree().get_nodes_in_group("spawners")
	var positions = []
	for spawner in spawners:
		if spawner.team == "enemy":
			positions.append(spawner.global_position)

	# Фильтруем позиции: нет врагов ближе SAFE_DISTANCE
	var units = get_tree().get_nodes_in_group("units")
	var safe_positions = []
	for pos in positions:
		var safe = true
		for unit in units:
			if unit.team == "player" and unit.global_position.distance_to(pos) < ai_config.SAFE_DISTANCE:
				safe = false
				break
		if safe:
			safe_positions.append(pos)

	# Если есть безопасные позиции — выбираем ближайшую к базе игрока
	if safe_positions.size() > 0:
		var player_core = battle_manager.player_core.global_position if battle_manager.has("player_core") and battle_manager.player_core else Vector3.ZERO
		safe_positions.sort_custom(func(a, b): return a.distance_to(player_core) < b.distance_to(player_core))
		return safe_positions[0]

	# Если нет безопасных — возвращаем любую доступную
	return positions.size() > 0 ? positions[0] : Vector3.ZERO

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
 
