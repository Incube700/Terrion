extends Node
class_name RaceSystem

# Система фракций TERRION - управление различными расами после Великого Коллапса
# Каждая фракция имеет уникальную философию, технологии и способности

signal hero_summoned(faction_name, commander_name)
signal faction_ability_used(faction_name, ability_name)

enum Race {
	HUMANS,          # Солнечная Корпорация™ - корпоративные оптимисты
	ORCS,            # Железная Орда - космические байкеры
	ELVES,           # Зеленое Сопротивление - экологи-экстремисты
	UNDEAD           # Цифровой Некрополь - техно-зануды (по мотивам Некронов)
}

var player_race: Race = Race.HUMANS
var enemy_race: Race = Race.ORCS
var battle_manager = null

# Информация о фракциях TERRION
var race_data = {
	Race.HUMANS: {
		"name": "Солнечная Корпорация™",
		"description": "Эффективные корпоративные менеджеры с оптимизированными процессами",
		"color": Color(0.2, 0.6, 1.0),
		"motto": "Солнце взойдет, акции вырастут, галактика наша!",
		"philosophy": "Управление галактикой через KPI, презентации и корпоративную культуру",
		"commander": {
			"name": "CEO Солариус",
			"title": "Корпоративный Мессия",
			"cost_energy": 100,
			"cost_crystals": 50,
			"hp": 300,
			"damage": 50,
			"special": "Мотивирующая Презентация - +200% эффективности всех юнитов"
		},
		"units": {
			"manager": {"cost_energy": 40, "cost_crystals": 5, "hp": 120, "damage": 30, "name": "Менеджер среднего звена"},
			"analyst": {"cost_energy": 25, "cost_crystals": 0, "hp": 60, "damage": 35, "name": "Аналитик данных"},
			"consultant": {"cost_energy": 60, "cost_crystals": 15, "hp": 180, "damage": 40, "name": "Корпоративный консультант"}
		},
		"abilities": {
			"quarterly_bonus": {"cost_energy": 50, "cost_crystals": 20, "effect": "Квартальная премия - все юниты получают KPI-бонус"},
			"efficiency_audit": {"cost_energy": 40, "cost_crystals": 10, "effect": "Аудит эффективности - оптимизирует вражеские здания"}
		}
	},
	
	Race.ORCS: {
		"name": "Железная Орда",
		"description": "Космические байкеры, решающие проблемы честно и прямо",
		"color": Color(0.8, 0.2, 0.2),
		"motto": "Если проблему нельзя решить честно - значит, кто-то врет!",
		"philosophy": "Простые решения сложных проблем: больше мощности, меньше бюрократии",
		"commander": {
			"name": "Вождь Громобой",
			"title": "Космический Байкер",
			"cost_energy": 120,
			"cost_crystals": 30,
			"hp": 400,
			"damage": 70,
			"special": "Боевое Неистовство - все орки получают +100% скорости и урона"
		},
		"units": {
			"biker": {"cost_energy": 35, "cost_crystals": 0, "hp": 140, "damage": 45, "name": "Реактивный байкер"},
			"mechanic": {"cost_energy": 50, "cost_crystals": 10, "hp": 100, "damage": 60, "name": "Боевой механик"},
			"shaman": {"cost_energy": 45, "cost_crystals": 15, "hp": 80, "damage": 25, "name": "Техно-шаман"}
		},
		"abilities": {
			"honest_fight": {"cost_energy": 60, "cost_crystals": 15, "effect": "Честная драка - увеличивает урон всех юнитов"},
			"engine_roar": {"cost_energy": 80, "cost_crystals": 25, "effect": "Рев двигателей - оглушает и деморализует врагов"}
		}
	},
	
	Race.ELVES: {
		"name": "Зеленое Сопротивление",
		"description": "Экологи-экстремисты, использующие биотехнологии против цивилизации",
		"color": Color(0.2, 1.0, 0.2),
		"motto": "Природа - это не ресурс, а партнер! Кремний должен уступить место углероду!",
		"philosophy": "Симбиоз с природой против технологического безумия",
		"commander": {
			"name": "Био-Хакер Элунара",
			"title": "Экстремальная Эколожка",
			"cost_energy": 80,
			"cost_crystals": 80,
			"hp": 200,
			"damage": 80,
			"special": "Гнев Леса - призывает энты и лечащие деревья"
		},
		"units": {
			"eco_warrior": {"cost_energy": 30, "cost_crystals": 5, "hp": 80, "damage": 50, "name": "Эко-воин"},
			"bio_hacker": {"cost_energy": 40, "cost_crystals": 20, "hp": 60, "damage": 70, "name": "Био-хакер"},
			"tree_guardian": {"cost_energy": 70, "cost_crystals": 25, "hp": 250, "damage": 35, "name": "Страж леса"}
		},
		"abilities": {
			"viral_growth": {"cost_energy": 70, "cost_crystals": 30, "effect": "Вирусный рост - превращает технику в растения"},
			"bio_teleport": {"cost_energy": 30, "cost_crystals": 15, "effect": "Био-телепорт через грибную сеть"}
		}
	},
	
	Race.UNDEAD: {
		"name": "Цифровой Некрополь",
		"description": "Бессмертные техно-зануды, оцифровавшие свои души ради вечного совершенства",
		"color": Color(0.1, 0.8, 0.1),
		"motto": "Плоть слаба, код вечен. Ошибка найдена - ошибка исправлена. Сопротивление бесполезно.",
		"philosophy": "Достижение технологического бессмертия через слияние сознания с машинами",
		"commander": {
			"name": "Крипт-Лорд Некротех",
			"title": "Цифровой Фараон",
			"cost_energy": 150,
			"cost_crystals": 100,
			"hp": 500,
			"damage": 80,
			"special": "Армия Мертвых - воскрешает павших врагов как цифровых слуг"
		},
		"units": {
			"necron_warrior": {"cost_energy": 45, "cost_crystals": 20, "hp": 150, "damage": 60, "name": "Некрон-воин"},
			"scarab_swarm": {"cost_energy": 30, "cost_crystals": 10, "hp": 80, "damage": 40, "name": "Рой скарабеев"},
			"immortal": {"cost_energy": 70, "cost_crystals": 35, "hp": 200, "damage": 75, "name": "Бессмертный"}
		},
		"abilities": {
			"reanimation": {"cost_energy": 80, "cost_crystals": 40, "effect": "Реанимация - воскрешает павших союзников"},
			"quantum_entanglement": {"cost_energy": 100, "cost_crystals": 50, "effect": "Квантовая запутанность - телепортирует всю армию"}
		}
	}
}

func _ready():
	print("🚀 Система фракций TERRION инициализирована")
	print("📊 Доступно фракций: ", race_data.size())
	# Подключаем сигналы к battle_manager, если он есть
	if battle_manager:
		hero_summoned.connect(_on_commander_summoned)
		faction_ability_used.connect(_on_faction_ability_used)

func _on_commander_summoned(faction_name: String, commander_name: String):
	print("👔 Командир призван: ", commander_name, " из фракции ", faction_name)

func _on_faction_ability_used(faction_name: String, ability_name: String):
	print("⚡ Способность фракции использована: ", ability_name, " фракцией ", faction_name)

func set_player_race(race: Race):
	player_race = race
	print("👑 Фракция игрока: ", race_data[race]["name"])
	print("📜 Девиз: ", race_data[race]["motto"])
	print("🧠 Философия: ", race_data[race]["philosophy"])

func set_enemy_race(race: Race):
	enemy_race = race
	print("👹 Вражеская фракция: ", race_data[race]["name"])

func get_race_info(race: Race) -> Dictionary:
	return race_data[race]

func can_summon_commander(race: Race, energy: int, crystals: int) -> bool:
	var commander = race_data[race]["commander"]
	return energy >= commander["cost_energy"] and crystals >= commander["cost_crystals"]

func summon_hero(race: Race, position: Vector3, team: String) -> bool:
	if not battle_manager:
		return false
		
	var hero = race_data[race]["commander"]
	var cost_energy = hero["cost_energy"]
	var cost_crystals = hero["cost_crystals"]
	
	# Проверяем ресурсы
	var has_resources = false
	if team == "player":
		has_resources = battle_manager.player_energy >= cost_energy and battle_manager.player_crystals >= cost_crystals
		if has_resources:
			battle_manager.player_energy -= cost_energy
			battle_manager.player_crystals -= cost_crystals
	else:
		has_resources = battle_manager.enemy_energy >= cost_energy and battle_manager.enemy_crystals >= cost_crystals
		if has_resources:
			battle_manager.enemy_energy -= cost_energy
			battle_manager.enemy_crystals -= cost_crystals
	
	if has_resources:
		# Создаем героя (используем базовый юнит как основу)
		battle_manager.spawn_unit_at_pos(team, position, "elite_soldier")
		hero_summoned.emit(race_data[race]["name"], hero["name"])
		print("⚔️ Командир призван: ", hero["name"])
		return true
	
	return false

func use_faction_ability(race: Race, ability_name: String, position: Vector3, team: String) -> bool:
	if not battle_manager:
		return false
		
	var race_info = race_data[race]
	if ability_name not in race_info["abilities"]:
		return false
		
	var ability = race_info["abilities"][ability_name]
	var cost_energy = ability["cost_energy"]
	var cost_crystals = ability["cost_crystals"]
	
	# Проверяем ресурсы
	var has_resources = false
	if team == "player":
		has_resources = battle_manager.player_energy >= cost_energy and battle_manager.player_crystals >= cost_crystals
		if has_resources:
			battle_manager.player_energy -= cost_energy
			battle_manager.player_crystals -= cost_crystals
	else:
		has_resources = battle_manager.enemy_energy >= cost_energy and battle_manager.enemy_crystals >= cost_crystals
		if has_resources:
			battle_manager.enemy_energy -= cost_energy
			battle_manager.enemy_crystals -= cost_crystals
	
	if has_resources:
		apply_faction_ability_effect(race, ability_name, position, team)
		faction_ability_used.emit(race_data[race]["name"], ability_name)
		return true
	
	return false

func apply_faction_ability_effect(race: Race, ability_name: String, position: Vector3, team: String):
	match race:
		Race.HUMANS:
			match ability_name:
				"quarterly_bonus":
					print("💼 Квартальная премия повышает эффективность всех юнитов")
				"efficiency_audit":
					print("📊 Аудит эффективности оптимизирует вражеские структуры")
		Race.ORCS:
			match ability_name:
				"honest_fight":
					print("🤼 Честная драка увеличивает урон")
				"engine_roar":
					print("🚨 Рев двигателей оглушает и деморализует врагов")
		Race.ELVES:
			match ability_name:
				"viral_growth":
					print("🌱 Вирусный рост превращает технику в растения")
				"bio_teleport":
					print("🌀 Био-телепорт перемещает юнитов через грибную сеть")
		Race.UNDEAD:
			match ability_name:
				"reanimation":
					print("⚰️ Реанимация воскрешает павших союзников")
				"quantum_entanglement":
					print("🌌 Квантовая запутанность телепортирует всю армию")

func get_race_color(race: Race) -> Color:
	return race_data[race]["color"]

func get_available_units(race: Race) -> Array:
	return race_data[race]["units"].keys()

func get_available_abilities(race: Race) -> Array:
	return race_data[race]["abilities"].keys()

func get_race_philosophy(race: Race) -> String:
	return race_data[race]["philosophy"]

func get_all_races() -> Array:
	return [Race.HUMANS, Race.ORCS, Race.ELVES, Race.UNDEAD]

func get_race_name(race: Race) -> String:
	return race_data[race]["name"]
