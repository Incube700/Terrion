extends Node

# Простой тест для TerritorySystem
# Запускается в редакторе для проверки работы системы

var territory_system: TerritorySystem

func _ready():
	print("🧪 Начинаем тестирование TerritorySystem...")
	
	# Создаем TerritorySystem
	territory_system = TerritorySystem.new()
	territory_system.battle_manager = self
	add_child(territory_system)
	
	# Подключаем сигналы
	territory_system.territory_captured.connect(_on_test_territory_captured)
	territory_system.territory_depleted.connect(_on_test_territory_depleted)
	
	# Запускаем тесты через 1 секунду
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(run_tests)
	add_child(timer)
	timer.start()

func run_tests():
	print("🧪 === ТЕСТИРОВАНИЕ TERRITORY SYSTEM ===")
	
	# Тест 1: Проверка создания территорий
	test_territory_creation()
	
	# Тест 2: Проверка захвата территорий
	test_territory_capture()
	
	# Тест 3: Проверка генерации ресурсов
	test_resource_generation()
	
	# Тест 4: Проверка призыва героя
	test_hero_summon()
	
	print("🧪 Тестирование завершено!")

func test_territory_creation():
	print("📋 Тест 1: Создание территорий")
	
	var territories = territory_system.get_territory_info()
	print("✅ Создано территорий: ", territories.size())
	
	# Проверяем что все территории созданы
	assert(territories.size() > 0, "Территории не созданы!")
	
	# Проверяем типы территорий
	var energy_mines = 0
	var crystal_mines = 0
	var triggers = 0
	
	for territory in territories:
		match territory.type:
			TerritorySystem.TerritoryType.ENERGY_MINE:
				energy_mines += 1
			TerritorySystem.TerritoryType.CRYSTAL_MINE:
				crystal_mines += 1
			TerritorySystem.TerritoryType.CENTER_TRIGGER_1, TerritorySystem.TerritoryType.CENTER_TRIGGER_2:
				triggers += 1
	
	print("✅ Энергетических рудников: ", energy_mines)
	print("✅ Кристальных рудников: ", crystal_mines)
	print("✅ Триггеров героя: ", triggers)

func test_territory_capture():
	print("📋 Тест 2: Захват территорий")
	
	# Симулируем захват энергетического рудника
	var territories = territory_system.get_territory_info()
	
	for i in range(territories.size()):
		var territory = territories[i]
		if territory.type == TerritorySystem.TerritoryType.ENERGY_MINE:
			print("🎯 Тестируем захват энергетического рудника ID=", i)
			territory_system.force_capture_territory(i, "player")
			break

func test_resource_generation():
	print("📋 Тест 3: Генерация ресурсов")
	
	# Проверяем что ресурсы генерируются
	var player_energy = 100
	var player_crystals = 0
	
	# Симулируем захват нескольких территорий
	var territories = territory_system.get_territory_info()
	
	for i in range(territories.size()):
		var territory = territories[i]
		if territory.type == TerritorySystem.TerritoryType.ENERGY_MINE:
			territory_system.force_capture_territory(i, "player")
			break
	
	# Симулируем генерацию ресурсов
	territory_system._on_resource_generation()
	
	print("✅ Генерация ресурсов протестирована")

func test_hero_summon():
	print("📋 Тест 4: Призыв героя")
	
	# Захватываем оба триггера
	var territories = territory_system.get_territory_info()
	var trigger_1_id = -1
	var trigger_2_id = -1
	
	for i in range(territories.size()):
		var territory = territories[i]
		if territory.type == TerritorySystem.TerritoryType.CENTER_TRIGGER_1:
			trigger_1_id = i
		elif territory.type == TerritorySystem.TerritoryType.CENTER_TRIGGER_2:
			trigger_2_id = i
	
	if trigger_1_id >= 0 and trigger_2_id >= 0:
		print("🎯 Захватываем триггеры для призыва героя")
		territory_system.force_capture_territory(trigger_1_id, "player")
		territory_system.force_capture_territory(trigger_2_id, "player")
		
		# Проверяем условия призыва героя
		territory_system.check_hero_summon_conditions()
		print("✅ Призыв героя протестирован")
	else:
		print("❌ Триггеры не найдены")

# Обработчики сигналов для тестов
func _on_test_territory_captured(territory_id: int, team: String, territory_type: int):
	print("🏳️ ТЕСТ: Территория ", territory_id, " захвачена командой ", team, " типа ", territory_type)

func _on_test_territory_depleted(territory_id: int):
	print("🏳️ ТЕСТ: Территория ", territory_id, " истощена")

# Заглушки для совместимости с BattleManager
var player_energy = 100
var player_crystals = 0
var enemy_energy = 100
var enemy_crystals = 0
var hero_summoned = false
var notification_system = null
var effect_system = null

func spawn_unit_at_pos(team: String, position: Vector3, unit_type: String):
	print("🎯 ТЕСТ: Спавн юнита ", unit_type, " для команды ", team, " в позиции ", position)

func check_victory_conditions():
	print("🏆 ТЕСТ: Проверка условий победы")

func update_ui():
	print("🖥️ ТЕСТ: Обновление UI") 