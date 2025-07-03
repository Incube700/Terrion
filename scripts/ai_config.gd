# ai_config.gd — Конфигурация AI для TERRION RTS

# Интервалы смены стратегии и анализа по сложности
const STRATEGY_CHANGE_INTERVAL = {
	"easy": 45.0,
	"normal": 30.0,
	"hard": 20.0
}
const ANALYSIS_INTERVAL = {
	"easy": 3.0,
	"normal": 2.0,
	"hard": 1.5
}

# Сила юнитов для расчёта power
const UNIT_POWER = {
	"soldier": 20,
	"tank": 40,
	"drone": 15
}

# Приоритеты юнитов и построек по стратегии
const UNIT_PRIORITIES = {
	"rush": ["soldier", "tank", "drone"],
	"defensive": ["tank", "soldier", "drone"],
	"economic": ["soldier", "drone", "tank"],
	"balanced": ["soldier", "tank", "drone"],
	"capture": ["collector", "soldier", "drone"],
	"fortify": ["tank", "collector", "soldier"],
	"harass": ["drone", "soldier", "collector"]
}
const BUILD_PRIORITIES = {
	"rush": ["spawner", "barracks", "tower"],
	"defensive": ["tower", "spawner", "barracks"],
	"economic": ["spawner", "spawner", "barracks"],
	"balanced": ["spawner", "tower", "barracks"],
	"capture": ["spawner", "tower", "collector_facility"],
	"fortify": ["tower", "collector_facility", "spawner"],
	"harass": ["spawner", "barracks", "collector_facility"]
}

# Веса для анализа поля боя
const WEIGHTS_UNIT_TYPE = {
	"soldier": 1.0,
	"tank": 2.0,
	"drone": 0.7
}
const WEIGHT_CRYSTAL = 3.0  # Влияние захваченных кристаллов
const WEIGHT_BASE_THREAT = 5.0  # Влияние угрозы базе
const WEIGHT_ECON_ADVANTAGE = 2.0  # Влияние экономического преимущества

# Параметры для расчёта приоритетов и спавна
const SAFE_DISTANCE = 8.0  # Минимальная дистанция до врага для безопасного спавна
const THREAT_RADIUS = 15.0  # Радиус, в котором учитываются угрозы 