class_name StatisticsSystem
extends Node

# StatisticsSystem — система статистики и достижений для TERRION
# Отслеживает игровые достижения и прогресс игрока

var battle_manager = null

# Статистика текущей битвы
var battle_stats = {
	"units_spawned": {"player": 0, "enemy": 0},
	"units_killed": {"player": 0, "enemy": 0},
	"buildings_built": {"player": 0, "enemy": 0},
	"abilities_used": {"player": 0, "enemy": 0},
	"territories_captured": {"player": 0, "enemy": 0},
	"resources_spent": {"player": {"energy": 0, "crystals": 0}, "enemy": {"energy": 0, "crystals": 0}},
	"battle_duration": 0.0,
	"winner": ""
}

# Общая статистика игрока
var player_stats = {
	"battles_won": 0,
	"battles_lost": 0,
	"total_units_spawned": 0,
	"total_enemies_killed": 0,
	"total_buildings_built": 0,
	"favorite_unit": "",
	"longest_battle": 0.0,
	"achievements_unlocked": []
}

# Достижения
var achievements = {
	"first_victory": {"name": "Первая Победа", "description": "Выиграйте первую битву", "unlocked": false},
	"unit_master": {"name": "Мастер Войск", "description": "Создайте 50 юнитов", "unlocked": false},
	"builder": {"name": "Строитель", "description": "Постройте 20 зданий", "unlocked": false},
	"survivor": {"name": "Выживший", "description": "Выиграйте битву, длившуюся более 5 минут", "unlocked": false},
	"destroyer": {"name": "Разрушитель", "description": "Уничтожьте 100 вражеских юнитов", "unlocked": false},
	"collector_master": {"name": "Мастер Коллекторов", "description": "Захватите 10 территорий", "unlocked": false}
}

var battle_start_time: float = 0.0

func _ready():
	# Загружаем сохраненную статистику
	load_statistics()
	print("📊 Система статистики инициализирована")

# Начало битвы
func start_battle():
	battle_start_time = Time.get_unix_time_from_system()
	reset_battle_stats()
	print("📊 Статистика битвы сброшена")

# Сброс статистики битвы
func reset_battle_stats():
	battle_stats = {
		"units_spawned": {"player": 0, "enemy": 0},
		"units_killed": {"player": 0, "enemy": 0},
		"buildings_built": {"player": 0, "enemy": 0},
		"abilities_used": {"player": 0, "enemy": 0},
		"territories_captured": {"player": 0, "enemy": 0},
		"resources_spent": {"player": {"energy": 0, "crystals": 0}, "enemy": {"energy": 0, "crystals": 0}},
		"battle_duration": 0.0,
		"winner": ""
	}

# Окончание битвы
func end_battle(winner: String):
	battle_stats.winner = winner
	battle_stats.battle_duration = Time.get_unix_time_from_system() - battle_start_time
	
	# Обновляем общую статистику
	if winner == "player":
		player_stats.battles_won += 1
	else:
		player_stats.battles_lost += 1
	
	# Проверяем достижения
	check_achievements()
	
	# Сохраняем статистику
	save_statistics()
	
	print("📊 Битва завершена. Статистика обновлена.")
	print_battle_summary()

# Регистрация событий
func register_unit_spawned(team: String, unit_type: String):
	battle_stats.units_spawned[team] += 1
	if team == "player":
		player_stats.total_units_spawned += 1
		update_favorite_unit(unit_type)
	print("📊 Юнит создан: ", team, " ", unit_type)

func register_unit_killed(team: String, unit_type: String):
	battle_stats.units_killed[team] += 1
	if team == "enemy":  # Игрок убил врага
		player_stats.total_enemies_killed += 1
	print("📊 Юнит убит: ", team, " ", unit_type)

func register_building_built(team: String, building_type: String):
	battle_stats.buildings_built[team] += 1
	if team == "player":
		player_stats.total_buildings_built += 1
	print("📊 Здание построено: ", team, " ", building_type)

func register_ability_used(team: String, _ability_name: String):
	battle_stats.abilities_used[team] += 1

func register_territory_captured(team: String, _territory_name: String):
	battle_stats.territories_captured[team] += 1

func register_resource_spent(team: String, resource_type: String, amount: int):
	battle_stats.resources_spent[team][resource_type] += amount

# Обновление любимого юнита
func update_favorite_unit(unit_type: String):
	# Простая логика - последний созданный юнит
	player_stats.favorite_unit = unit_type

# Проверка достижений
func check_achievements():
	# Первая победа
	if not achievements.first_victory.unlocked and player_stats.battles_won >= 1:
		unlock_achievement("first_victory")
	
	# Мастер войск
	if not achievements.unit_master.unlocked and player_stats.total_units_spawned >= 50:
		unlock_achievement("unit_master")
	
	# Строитель
	if not achievements.builder.unlocked and player_stats.total_buildings_built >= 20:
		unlock_achievement("builder")
	
	# Выживший
	if not achievements.survivor.unlocked and battle_stats.battle_duration >= 300 and battle_stats.winner == "player":
		unlock_achievement("survivor")
	
	# Разрушитель
	if not achievements.destroyer.unlocked and player_stats.total_enemies_killed >= 100:
		unlock_achievement("destroyer")
	
	# Мастер коллекторов
	var total_territories = 0
	for team in battle_stats.territories_captured:
		if team == "player":
			total_territories += battle_stats.territories_captured[team]
	if not achievements.collector_master.unlocked and total_territories >= 10:
		unlock_achievement("collector_master")

# Разблокировка достижения
func unlock_achievement(achievement_id: String):
	if achievement_id in achievements:
		achievements[achievement_id].unlocked = true
		player_stats.achievements_unlocked.append(achievement_id)
		
		# Уведомление о достижении
		if battle_manager and battle_manager.notification_system:
			var achievement = achievements[achievement_id]
			battle_manager.notification_system.show_notification(
				"🏆 ДОСТИЖЕНИЕ: " + achievement.name + "\n" + achievement.description,
				"achievement",
				5.0
			)
		
		print("🏆 Достижение разблокировано: ", achievements[achievement_id].name)

# Вывод итогов битвы
func print_battle_summary():
	print("=== ИТОГИ БИТВЫ ===")
	print("Победитель: ", battle_stats.winner)
	print("Длительность: ", battle_stats.battle_duration, " секунд")
	print("Юниты созданы - Игрок: ", battle_stats.units_spawned.player, " | Враг: ", battle_stats.units_spawned.enemy)
	print("Юниты убиты - Игрок: ", battle_stats.units_killed.player, " | Враг: ", battle_stats.units_killed.enemy)
	print("Здания построены - Игрок: ", battle_stats.buildings_built.player, " | Враг: ", battle_stats.buildings_built.enemy)
	print("Способности использованы - Игрок: ", battle_stats.abilities_used.player, " | Враг: ", battle_stats.abilities_used.enemy)
	print("==================")

# Получение статистики для UI
func get_battle_stats() -> Dictionary:
	return battle_stats

func get_player_stats() -> Dictionary:
	return player_stats

func get_achievements() -> Dictionary:
	return achievements

# Сохранение и загрузка статистики
func save_statistics():
	var save_file = FileAccess.open("user://player_stats.save", FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(player_stats))
		save_file.close()
		print("📊 Статистика сохранена")

func load_statistics():
	var save_file = FileAccess.open("user://player_stats.save", FileAccess.READ)
	if save_file:
		var json_string = save_file.get_as_text()
		save_file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			player_stats = json.data
			print("📊 Статистика загружена")
		else:
			print("📊 Ошибка загрузки статистики")
	else:
		print("📊 Файл статистики не найден, используем значения по умолчанию")

# Получение процента достижений
func get_achievement_progress() -> float:
	var total_achievements = achievements.size()
	var unlocked_achievements = player_stats.achievements_unlocked.size()
	return float(unlocked_achievements) / float(total_achievements) * 100.0

# Получение статистики для отображения
func get_stats_display_text() -> String:
	var text = "=== СТАТИСТИКА ИГРОКА ===\n"
	text += "🏆 Побед: " + str(player_stats.battles_won) + "\n"
	text += "💀 Поражений: " + str(player_stats.battles_lost) + "\n"
	text += "⚔️ Юнитов создано: " + str(player_stats.total_units_spawned) + "\n"
	text += "🎯 Врагов убито: " + str(player_stats.total_enemies_killed) + "\n"
	text += "🏗️ Зданий построено: " + str(player_stats.total_buildings_built) + "\n"
	text += "❤️ Любимый юнит: " + str(player_stats.favorite_unit) + "\n"
	text += "🏅 Достижений: " + str(player_stats.achievements_unlocked.size()) + "/" + str(achievements.size()) + "\n"
	text += "📊 Прогресс: " + str(int(get_achievement_progress())) + "%"
	return text 
 
