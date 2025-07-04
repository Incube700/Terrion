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
	"warrior": 20,
	"heavy": 40,
	"fast": 15,
	"sniper": 25,
	"collector": 5
}

# Приоритеты юнитов и построек по стратегии
const UNIT_PRIORITIES = {
	"rush": ["warrior", "heavy", "fast"],
	"defensive": ["heavy", "warrior", "sniper"],
	"economic": ["warrior", "fast", "collector"],
	"balanced": ["warrior", "heavy", "fast"],
	"capture": ["collector", "warrior", "fast"],
	"fortify": ["heavy", "collector", "sniper"],
	"harass": ["fast", "warrior", "sniper"]
}
const BUILD_PRIORITIES = {
	"rush": ["barracks", "mech_factory", "recon_center"],
	"defensive": ["tower", "barracks", "mech_factory"],
	"economic": ["barracks", "recon_center", "shooting_range"],
	"balanced": ["barracks", "tower", "mech_factory"],
	"capture": ["tower", "barracks", "recon_center"],
	"fortify": ["tower", "shooting_range", "mech_factory"],
	"harass": ["recon_center", "barracks", "shooting_range"]
}

# Веса для анализа поля боя
const WEIGHTS_UNIT_TYPE = {
	"warrior": 1.0,
	"heavy": 2.0,
	"fast": 0.7,
	"sniper": 1.5,
	"collector": 0.3
}
const WEIGHT_CRYSTAL = 3.0  # Влияние захваченных кристаллов
const WEIGHT_BASE_THREAT = 5.0  # Влияние угрозы базе
const WEIGHT_ECON_ADVANTAGE = 2.0  # Влияние экономического преимущества

# Параметры для расчёта приоритетов и спавна
const SAFE_DISTANCE = 8.0  # Минимальная дистанция до врага для безопасного спавна
const THREAT_RADIUS = 15.0  # Радиус, в котором учитываются угрозы 