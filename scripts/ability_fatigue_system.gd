# ability_fatigue_system.gd - Система усталости способностей
# Предотвращает спам сильных способностей через механику усталости

class_name AbilityFatigueSystem
extends Node

signal ability_fatigue_changed(ability_name: String, fatigue_level: float)

# Настройки усталости для каждого типа способностей
const FATIGUE_SETTINGS = {
	"damage_ability": {
		"base_cooldown": 5.0,      # Базовый кулдаун
		"fatigue_increase": 0.3,   # Увеличение усталости за использование
		"fatigue_decay": 0.1,      # Снижение усталости в секунду
		"max_fatigue": 2.0,        # Максимальная усталость
		"fatigue_multiplier": 1.5  # Множитель кулдауна от усталости
	},
	"heal_ability": {
		"base_cooldown": 8.0,
		"fatigue_increase": 0.4,
		"fatigue_decay": 0.08,
		"max_fatigue": 2.5,
		"fatigue_multiplier": 1.8
	},
	"buff_ability": {
		"base_cooldown": 12.0,
		"fatigue_increase": 0.5,
		"fatigue_decay": 0.06,
		"max_fatigue": 3.0,
		"fatigue_multiplier": 2.0
	},
	"ultimate_ability": {
		"base_cooldown": 30.0,
		"fatigue_increase": 1.0,
		"fatigue_decay": 0.03,
		"max_fatigue": 5.0,
		"fatigue_multiplier": 3.0
	}
}

# Текущая усталость для каждой команды и способности
var team_fatigue = {
	"player": {},
	"enemy": {}
}

# Время последнего использования способностей
var last_use_time = {
	"player": {},
	"enemy": {}
}

# Таймеры для обновления усталости
var fatigue_timers = {}

func _ready():
	print("😴 Система усталости способностей инициализирована")
	start_fatigue_timer()

# Запуск таймера обновления усталости
func start_fatigue_timer():
	var timer = Timer.new()
	timer.wait_time = 1.0  # Обновление каждую секунду
	timer.timeout.connect(_update_fatigue)
	add_child(timer)
	timer.start()
	fatigue_timers["main"] = timer

# Обновление усталости каждую секунду
func _update_fatigue():
	for team in team_fatigue:
		for ability_name in team_fatigue[team]:
			var ability_type = get_ability_type(ability_name)
			if ability_type in FATIGUE_SETTINGS:
				var settings = FATIGUE_SETTINGS[ability_type]
				var current_fatigue = team_fatigue[team][ability_name]
				
				# Снижение усталости со временем
				var new_fatigue = max(0.0, current_fatigue - settings.fatigue_decay)
				team_fatigue[team][ability_name] = new_fatigue
				
				# Сигнал об изменении усталости
				ability_fatigue_changed.emit(ability_name, new_fatigue)

# Определение типа способности по имени
func get_ability_type(ability_name: String) -> String:
	if ability_name.contains("damage") or ability_name.contains("attack"):
		return "damage_ability"
	elif ability_name.contains("heal") or ability_name.contains("repair"):
		return "heal_ability"
	elif ability_name.contains("buff") or ability_name.contains("boost"):
		return "buff_ability"
	elif ability_name.contains("ultimate") or ability_name.contains("special"):
		return "ultimate_ability"
	else:
		return "damage_ability"  # По умолчанию

# Проверка возможности использования способности
func can_use_ability(team: String, ability_name: String) -> bool:
	var ability_type = get_ability_type(ability_name)
	if ability_type not in FATIGUE_SETTINGS:
		return true  # Если нет настроек, разрешаем использование
	
	var settings = FATIGUE_SETTINGS[ability_type]
	var current_fatigue = team_fatigue[team].get(ability_name, 0.0)
	var last_use = last_use_time[team].get(ability_name, 0.0)
	var current_time = Time.get_time_dict_from_system()
	var time_since_last_use = current_time - last_use
	
	# Рассчитываем текущий кулдаун с учётом усталости
	var fatigue_multiplier = 1.0 + (current_fatigue * settings.fatigue_multiplier)
	var current_cooldown = settings.base_cooldown * fatigue_multiplier
	
	return time_since_last_use >= current_cooldown

# Использование способности
func use_ability(team: String, ability_name: String) -> bool:
	if not can_use_ability(team, ability_name):
		return false
	
	var ability_type = get_ability_type(ability_name)
	if ability_type not in FATIGUE_SETTINGS:
		return true
	
	var settings = FATIGUE_SETTINGS[ability_type]
	var current_fatigue = team_fatigue[team].get(ability_name, 0.0)
	
	# Увеличение усталости
	var new_fatigue = min(settings.max_fatigue, current_fatigue + settings.fatigue_increase)
	team_fatigue[team][ability_name] = new_fatigue
	
	# Обновление времени последнего использования
	last_use_time[team][ability_name] = Time.get_time_dict_from_system()
	
	# Сигнал об изменении усталости
	ability_fatigue_changed.emit(ability_name, new_fatigue)
	
	print("😴 Использована способность: ", team, " ", ability_name, " (усталость: ", new_fatigue, ")")
	return true

# Получение текущего кулдауна способности
func get_ability_cooldown(team: String, ability_name: String) -> float:
	var ability_type = get_ability_type(ability_name)
	if ability_type not in FATIGUE_SETTINGS:
		return 0.0
	
	var settings = FATIGUE_SETTINGS[ability_type]
	var current_fatigue = team_fatigue[team].get(ability_name, 0.0)
	var last_use = last_use_time[team].get(ability_name, 0.0)
	var current_time = Time.get_time_dict_from_system()
	var time_since_last_use = current_time - last_use
	
	var fatigue_multiplier = 1.0 + (current_fatigue * settings.fatigue_multiplier)
	var current_cooldown = settings.base_cooldown * fatigue_multiplier
	
	return max(0.0, current_cooldown - time_since_last_use)

# Получение уровня усталости способности
func get_ability_fatigue(team: String, ability_name: String) -> float:
	return team_fatigue[team].get(ability_name, 0.0)

# Получение множителя усталости для способности
func get_fatigue_multiplier(team: String, ability_name: String) -> float:
	var ability_type = get_ability_type(ability_name)
	if ability_type not in FATIGUE_SETTINGS:
		return 1.0
	
	var settings = FATIGUE_SETTINGS[ability_type]
	var current_fatigue = team_fatigue[team].get(ability_name, 0.0)
	return 1.0 + (current_fatigue * settings.fatigue_multiplier)

# Получение описания усталости
func get_fatigue_description(team: String, ability_name: String) -> String:
	var fatigue = get_ability_fatigue(team, ability_name)
	var ability_type = get_ability_type(ability_name)
	
	if ability_type not in FATIGUE_SETTINGS:
		return "Нормальная"
	
	var max_fatigue = FATIGUE_SETTINGS[ability_type].max_fatigue
	var fatigue_percentage = (fatigue / max_fatigue) * 100
	
	if fatigue_percentage < 25:
		return "Свежая"
	elif fatigue_percentage < 50:
		return "Лёгкая усталость"
	elif fatigue_percentage < 75:
		return "Средняя усталость"
	elif fatigue_percentage < 100:
		return "Сильная усталость"
	else:
		return "Критическая усталость"

# Получение цветового индикатора усталости
func get_fatigue_color(team: String, ability_name: String) -> Color:
	var fatigue = get_ability_fatigue(team, ability_name)
	var ability_type = get_ability_type(ability_name)
	
	if ability_type not in FATIGUE_SETTINGS:
		return Color.WHITE
	
	var max_fatigue = FATIGUE_SETTINGS[ability_type].max_fatigue
	var fatigue_percentage = fatigue / max_fatigue
	
	if fatigue_percentage < 0.25:
		return Color.GREEN  # Свежая
	elif fatigue_percentage < 0.5:
		return Color.YELLOW  # Лёгкая усталость
	elif fatigue_percentage < 0.75:
		return Color.ORANGE  # Средняя усталость
	elif fatigue_percentage < 1.0:
		return Color.RED  # Сильная усталость
	else:
		return Color.DARK_RED  # Критическая усталость

# Сброс усталости для команды (при новой игре)
func reset_team_fatigue(team: String):
	team_fatigue[team] = {}
	last_use_time[team] = {}
	print("😴 Усталость сброшена для команды: ", team)

# Получение статистики усталости
func get_fatigue_statistics() -> Dictionary:
	var stats = {
		"player": {},
		"enemy": {}
	}
	
	for team in team_fatigue:
		for ability_name in team_fatigue[team]:
			var fatigue = team_fatigue[team][ability_name]
			var cooldown = get_ability_cooldown(team, ability_name)
			var description = get_fatigue_description(team, ability_name)
			
			stats[team][ability_name] = {
				"fatigue": fatigue,
				"cooldown": cooldown,
				"description": description
			}
	
	return stats 