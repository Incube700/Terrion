# balance_metrics_system.gd - Система метрик баланса
# Отслеживает ключевые показатели для анализа и корректировки баланса

class_name BalanceMetricsSystem
extends Node

signal metrics_updated(metrics_data: Dictionary)

# Основные метрики баланса
var battle_metrics = {
	"unit_usage": {},           # Использование юнитов
	"unit_effectiveness": {},   # Эффективность юнитов
	"resource_efficiency": {},  # Эффективность ресурсов
	"win_conditions": {},       # Условия победы
	"battle_duration": [],      # Длительность битв
	"territory_control": {},    # Контроль территорий
	"ability_usage": {},        # Использование способностей
	"balance_issues": []        # Выявленные проблемы баланса
}

# Детальные метрики юнитов
var unit_detailed_metrics = {
	"spawn_count": {},          # Количество созданных
	"kill_count": {},           # Количество убийств
	"death_count": {},          # Количество смертей
	"damage_dealt": {},         # Нанесённый урон
	"damage_taken": {},         # Полученный урон
	"cost_efficiency": {},      # Эффективность по стоимости
	"lifetime": {},             # Время жизни
	"target_priority": {}       # Приоритет целей
}

# Метрики ресурсов
var resource_metrics = {
	"energy_generation": {},    # Генерация энергии
	"crystal_generation": {},   # Генерация кристаллов
	"resource_spending": {},    # Траты ресурсов
	"resource_efficiency": {}   # Эффективность использования
}

# Метрики территорий
var territory_metrics = {
	"capture_speed": {},        # Скорость захвата
	"control_time": {},         # Время контроля
	"strategic_value": {},      # Стратегическая ценность
	"defense_effectiveness": {} # Эффективность защиты
}

func _ready():
	print("📊 Система метрик баланса инициализирована")

# Регистрация создания юнита
func register_unit_spawn(team: String, unit_type: String, cost: int):
	if not battle_metrics.unit_usage.has(unit_type):
		battle_metrics.unit_usage[unit_type] = {"player": 0, "enemy": 0}
	
	battle_metrics.unit_usage[unit_type][team] += 1
	
	# Детальные метрики
	if not unit_detailed_metrics.spawn_count.has(unit_type):
		unit_detailed_metrics.spawn_count[unit_type] = {"player": 0, "enemy": 0}
	unit_detailed_metrics.spawn_count[unit_type][team] += 1
	
	print("📊 Зарегистрирован спавн: ", team, " ", unit_type)

# Регистрация убийства юнита
func register_unit_kill(attacker_team: String, attacker_type: String, victim_team: String, victim_type: String, damage: int):
	# Метрики убийств
	if not unit_detailed_metrics.kill_count.has(attacker_type):
		unit_detailed_metrics.kill_count[attacker_type] = {"player": 0, "enemy": 0}
	unit_detailed_metrics.kill_count[attacker_type][attacker_team] += 1
	
	# Метрики смертей
	if not unit_detailed_metrics.death_count.has(victim_type):
		unit_detailed_metrics.death_count[victim_type] = {"player": 0, "enemy": 0}
	unit_detailed_metrics.death_count[victim_type][victim_team] += 1
	
	# Эффективность против конкретных типов
	var effectiveness_key = attacker_type + "_vs_" + victim_type
	if not battle_metrics.unit_effectiveness.has(effectiveness_key):
		battle_metrics.unit_effectiveness[effectiveness_key] = {"kills": 0, "damage": 0}
	
	battle_metrics.unit_effectiveness[effectiveness_key].kills += 1
	battle_metrics.unit_effectiveness[effectiveness_key].damage += damage
	
	print("📊 Зарегистрировано убийство: ", attacker_type, " убил ", victim_type)

# Регистрация урона
func register_damage(attacker_team: String, attacker_type: String, victim_team: String, victim_type: String, damage: int):
	# Нанесённый урон
	if not unit_detailed_metrics.damage_dealt.has(attacker_type):
		unit_detailed_metrics.damage_dealt[attacker_type] = {"player": 0, "enemy": 0}
	unit_detailed_metrics.damage_dealt[attacker_type][attacker_team] += damage
	
	# Полученный урон
	if not unit_detailed_metrics.damage_taken.has(victim_type):
		unit_detailed_metrics.damage_taken[victim_type] = {"player": 0, "enemy": 0}
	unit_detailed_metrics.damage_taken[victim_type][victim_team] += damage

# Регистрация захвата территории
func register_territory_capture(team: String, territory_type: String, capture_time: float):
	if not territory_metrics.capture_speed.has(territory_type):
		territory_metrics.capture_speed[territory_type] = []
	
	territory_metrics.capture_speed[territory_type].append(capture_time)
	
	print("📊 Зарегистрирован захват: ", team, " захватил ", territory_type, " за ", capture_time, " сек")

# Регистрация использования способности
func register_ability_use(team: String, ability_name: String, cost: int, effectiveness: float):
	if not battle_metrics.ability_usage.has(ability_name):
		battle_metrics.ability_usage[ability_name] = {"uses": 0, "total_cost": 0, "effectiveness": []}
	
	battle_metrics.ability_usage[ability_name].uses += 1
	battle_metrics.ability_usage[ability_name].total_cost += cost
	battle_metrics.ability_usage[ability_name].effectiveness.append(effectiveness)
	
	print("📊 Зарегистрировано использование способности: ", team, " ", ability_name)

# Регистрация окончания битвы
func register_battle_end(winner: String, duration: float, player_units_remaining: int, enemy_units_remaining: int):
	battle_metrics.battle_duration.append(duration)
	
	if not battle_metrics.win_conditions.has(winner):
		battle_metrics.win_conditions[winner] = 0
	battle_metrics.win_conditions[winner] += 1
	
	# Анализ баланса
	analyze_balance_issues()
	
	print("📊 Зарегистрировано окончание битвы: ", winner, " победил за ", duration, " сек")

# Анализ проблем баланса
func analyze_balance_issues():
	var issues = []
	
	# Проверка доминирования юнитов
	for unit_type in battle_metrics.unit_usage:
		var player_usage = battle_metrics.unit_usage[unit_type].get("player", 0)
		var enemy_usage = battle_metrics.unit_usage[unit_type].get("enemy", 0)
		var total_usage = player_usage + enemy_usage
		
		if total_usage > 0:
			var usage_ratio = float(total_usage) / get_total_units_spawned()
			if usage_ratio > 0.4:  # Если юнит используется более 40% времени
				issues.append("Доминирование юнита: " + unit_type + " (" + str(usage_ratio * 100) + "%)")
	
	# Проверка эффективности юнитов
	for effectiveness_key in battle_metrics.unit_effectiveness:
		var data = battle_metrics.unit_effectiveness[effectiveness_key]
		if data.kills > 10:  # Если достаточно данных
			var avg_damage = float(data.damage) / data.kills
			if avg_damage > 100:  # Если средний урон слишком высок
				issues.append("Высокая эффективность: " + effectiveness_key + " (урон: " + str(avg_damage) + ")")
	
	# Проверка длительности битв
	if battle_metrics.battle_duration.size() > 0:
		var avg_duration = get_average_battle_duration()
		if avg_duration < 60:  # Если битвы слишком короткие
			issues.append("Слишком короткие битвы: " + str(avg_duration) + " сек в среднем")
		elif avg_duration > 600:  # Если битвы слишком длинные
			issues.append("Слишком длинные битвы: " + str(avg_duration) + " сек в среднем")
	
	battle_metrics.balance_issues = issues
	metrics_updated.emit(battle_metrics)

# Получение общего количества созданных юнитов
func get_total_units_spawned() -> int:
	var total = 0
	for unit_type in battle_metrics.unit_usage:
		total += battle_metrics.unit_usage[unit_type].get("player", 0)
		total += battle_metrics.unit_usage[unit_type].get("enemy", 0)
	return total

# Получение средней длительности битв
func get_average_battle_duration() -> float:
	if battle_metrics.battle_duration.size() == 0:
		return 0.0
	
	var total = 0.0
	for duration in battle_metrics.battle_duration:
		total += duration
	return total / battle_metrics.battle_duration.size()

# Получение отчёта по балансу
func get_balance_report() -> Dictionary:
	return {
		"unit_usage": battle_metrics.unit_usage,
		"unit_effectiveness": battle_metrics.unit_effectiveness,
		"win_conditions": battle_metrics.win_conditions,
		"average_battle_duration": get_average_battle_duration(),
		"total_units_spawned": get_total_units_spawned(),
		"balance_issues": battle_metrics.balance_issues
	}

# Сброс метрик (для новой сессии)
func reset_metrics():
	battle_metrics = {
		"unit_usage": {},
		"unit_effectiveness": {},
		"resource_efficiency": {},
		"win_conditions": {},
		"battle_duration": [],
		"territory_control": {},
		"ability_usage": {},
		"balance_issues": []
	}
	
	unit_detailed_metrics = {
		"spawn_count": {},
		"kill_count": {},
		"death_count": {},
		"damage_dealt": {},
		"damage_taken": {},
		"cost_efficiency": {},
		"lifetime": {},
		"target_priority": {}
	}
	
	print("�� Метрики сброшены") 