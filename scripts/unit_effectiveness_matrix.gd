# unit_effectiveness_matrix.gd - Система эффективности юнитов
# Реализует механику "камень-ножницы-бумага" для сбалансированного геймплея

class_name UnitEffectivenessMatrix
extends Resource

# Матрица эффективности: [атакующий][защищающийся] = множитель урона
const EFFECTIVENESS_MATRIX = {
	"warrior": {
		"warrior": 1.0,    # Нейтрально
		"heavy": 0.7,      # Слабо против тяжёлых
		"fast": 1.3,       # Сильно против быстрых
		"sniper": 1.5,     # Очень сильно против снайперов
		"collector": 1.2,  # Сильно против коллекторов
		"hero": 0.5        # Очень слабо против героев
	},
	"heavy": {
		"warrior": 1.4,    # Сильно против воинов
		"heavy": 1.0,      # Нейтрально
		"fast": 0.6,       # Очень слабо против быстрых
		"sniper": 1.2,     # Сильно против снайперов
		"collector": 1.8,  # Очень сильно против коллекторов
		"hero": 0.8        # Слабо против героев
	},
	"fast": {
		"warrior": 0.8,    # Слабо против воинов
		"heavy": 1.6,      # Очень сильно против тяжёлых
		"fast": 1.0,       # Нейтрально
		"sniper": 1.4,     # Сильно против снайперов
		"collector": 1.1,  # Немного сильно против коллекторов
		"hero": 0.7        # Слабо против героев
	},
	"sniper": {
		"warrior": 0.7,    # Слабо против воинов
		"heavy": 0.9,      # Немного слабо против тяжёлых
		"fast": 0.8,       # Слабо против быстрых
		"sniper": 1.0,     # Нейтрально
		"collector": 1.6,  # Очень сильно против коллекторов
		"hero": 1.3        # Сильно против героев
	},
	"collector": {
		"warrior": 0.9,    # Немного слабо против воинов
		"heavy": 0.5,      # Очень слабо против тяжёлых
		"fast": 0.9,       # Немного слабо против быстрых
		"sniper": 0.6,     # Очень слабо против снайперов
		"collector": 1.0,  # Нейтрально
		"hero": 0.3        # Крайне слабо против героев
	},
	"hero": {
		"warrior": 1.8,    # Очень сильно против воинов
		"heavy": 1.4,      # Сильно против тяжёлых
		"fast": 1.6,       # Очень сильно против быстрых
		"sniper": 0.9,     # Немного слабо против снайперов
		"collector": 2.0,  # Максимально сильно против коллекторов
		"hero": 1.0        # Нейтрально
	}
}

# Получение множителя эффективности
static func get_effectiveness_multiplier(attacker_type: String, defender_type: String) -> float:
	if EFFECTIVENESS_MATRIX.has(attacker_type) and EFFECTIVENESS_MATRIX[attacker_type].has(defender_type):
		return EFFECTIVENESS_MATRIX[attacker_type][defender_type]
	return 1.0  # По умолчанию нейтральный урон

# Получение описания эффективности
static func get_effectiveness_description(attacker_type: String, defender_type: String) -> String:
	var multiplier = get_effectiveness_multiplier(attacker_type, defender_type)
	
	if multiplier >= 1.5:
		return "Очень эффективно"
	elif multiplier >= 1.2:
		return "Эффективно"
	elif multiplier >= 0.9:
		return "Нейтрально"
	elif multiplier >= 0.7:
		return "Неэффективно"
	else:
		return "Очень неэффективно"

# Получение цветового индикатора эффективности
static func get_effectiveness_color(attacker_type: String, defender_type: String) -> Color:
	var multiplier = get_effectiveness_multiplier(attacker_type, defender_type)
	
	if multiplier >= 1.5:
		return Color.GREEN  # Очень эффективно
	elif multiplier >= 1.2:
		return Color.YELLOW_GREEN  # Эффективно
	elif multiplier >= 0.9:
		return Color.WHITE  # Нейтрально
	elif multiplier >= 0.7:
		return Color.ORANGE  # Неэффективно
	else:
		return Color.RED  # Очень неэффективно

# Получение рекомендаций по контрпикам
static func get_counter_recommendations(unit_type: String) -> Array[String]:
	var counters = []
	
	match unit_type:
		"warrior":
			counters = ["heavy", "hero"]  # Тяжёлые и герои контрпикают воинов
		"heavy":
			counters = ["fast", "hero"]   # Быстрые и герои контрпикают тяжёлых
		"fast":
			counters = ["warrior", "hero"] # Воины и герои контрпикают быстрых
		"sniper":
			counters = ["warrior", "heavy", "fast"] # Все ближние юниты контрпикают снайперов
		"collector":
			counters = ["warrior", "heavy", "fast", "sniper", "hero"] # Все контрпикают коллекторов
		"hero":
			counters = ["sniper"] # Только снайперы могут контрпикать героев
	
	return counters

# Получение сильных сторон юнита
static func get_strengths(unit_type: String) -> Array[String]:
	var strengths = []
	
	match unit_type:
		"warrior":
			strengths = ["fast", "sniper"]  # Воины сильны против быстрых и снайперов
		"heavy":
			strengths = ["warrior", "sniper", "collector"] # Тяжёлые сильны против многих
		"fast":
			strengths = ["heavy", "sniper"] # Быстрые сильны против тяжёлых и снайперов
		"sniper":
			strengths = ["collector", "hero"] # Снайперы сильны против коллекторов и героев
		"collector":
			strengths = [] # Коллекторы не сильны в бою
		"hero":
			strengths = ["warrior", "heavy", "fast", "collector"] # Герои сильны против всех
	
	return strengths 