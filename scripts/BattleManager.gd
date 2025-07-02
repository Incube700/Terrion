class_name BattleManager
extends Node

# BattleManager — управляет логикой космических сражений между расами
# В мире TERRION командиры фракций сражаются за контроль над территориями

var player_energy = 100  # Энергетические ресурсы командира
var enemy_energy = 100   # Энергетические ресурсы противника
var player_crystals = 0  # Квантовые кристаллы для продвинутых технологий
var enemy_crystals = 0   # Кристаллы врага
var energy_gain_per_tick = 10  # Автоматическая генерация энергии
var energy_tick_time = 1.0     # Интервал пополнения ресурсов

var player_base_hp = 100  # Прочность командного центра игрока
var enemy_base_hp = 100   # Прочность командного центра врага

var lanes = []
var player_spawners = []  # Производственные модули игрока
var enemy_spawners = []   # Производственные модули врага

signal battle_finished(winner)

var unit_scene = preload("res://scenes/Unit.tscn")
var spawner_scene = preload("res://scenes/Spawner.tscn")
var battle_ui = null
var battle_started = false

var is_building_mode = false
var building_preview = null
var can_build_here = false
var building_cost = 30  # Стоимость постройки модуля

# Система ИИ для вражеской фракции
var enemy_ai_timer: Timer
var enemy_decision_timer: Timer
var energy_timer: Timer
var enemy_max_soldiers = 3  # Лимиты юнитов для ИИ
var enemy_max_tanks = 2
var enemy_max_drones = 2
var enemy_current_soldiers = 0
var enemy_current_tanks = 0
var enemy_current_drones = 0

var enemy_ai: EnemyAI = null
var ai_difficulty: String = "normal"

# Система кристаллов (заменяет территории)
var crystal_system: CrystalSystem = null

# Система технологий и способностей
var ability_system: AbilitySystem = null

# Система рас и фракций
var race_system: RaceSystem = null

# Система визуальных эффектов
var effect_system = null

# Система звуков
var audio_system = null

# Система уведомлений
var notification_system = null

# Система статистики
var statistics_system = null

# Система расовых способностей
var race_ability_system = null

# Менеджер систем для безопасной инициализации
var system_manager = null

var battle_camera: Camera3D
var camera_speed = 20.0
var zoom_speed = 5.0
var is_mouse_dragging = false
var last_mouse_position = Vector2.ZERO

# Система управления юнитами мышью
var selected_units = []  # Выбранные игроком юниты
var selection_indicator = null  # Визуальный индикатор выбора

# Переменные для drag&drop строительства
var current_drag_building_type = ""
var is_dragging_building = false

func _ready():
	# Получаем ссылку на камеру
	battle_camera = get_node("Camera3D")
	
	print("🎮 Начинаем инициализацию BattleManager...")
	
	# Инициализация всех систем
	call_deferred("init_all_systems")

func _input(event):
	if not battle_camera:
		return
		
	# Управление камерой мышкой
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_mouse_dragging = event.pressed
			last_mouse_position = event.position
			
		# Зум колесиком мыши - БЛИЖЕ для лучшего наблюдения
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var new_pos = battle_camera.position
			new_pos.y = max(20, new_pos.y - zoom_speed)  # Уменьшил с 30 до 20
			new_pos.z = max(15, new_pos.z - zoom_speed * 0.8)  # Уменьшил с 25 до 15
			battle_camera.position = new_pos
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var new_pos = battle_camera.position
			new_pos.y = min(120, new_pos.y + zoom_speed)  # Увеличил с 100 до 120
			new_pos.z = min(100, new_pos.z + zoom_speed * 0.8)  # Увеличил с 80 до 100
			battle_camera.position = new_pos
			
	elif event is InputEventMouseMotion and is_mouse_dragging:
		# Перемещение камеры
		var delta = (event.position - last_mouse_position) * 0.1
		var new_pos = battle_camera.position
		new_pos.x -= delta.x * 0.1
		new_pos.z += delta.y * 0.1
		# Ограничиваем перемещение камеры в пределах поля
		new_pos.x = clamp(new_pos.x, -30, 30)
		new_pos.z = clamp(new_pos.z, 20, 80)
		battle_camera.position = new_pos
		last_mouse_position = event.position

func init_all_systems():
	print("🚀 Командный центр TERRION инициализация...")
	
	# Инициализация систем
	init_system_manager()  # Сначала инициализируем менеджер систем
	init_enemy_ai()
	init_energy_timer()
	init_crystal_system()  # Включаем обратно после исправления ошибок
	init_ability_system()
	init_race_system()
	# Остальные системы уже инициализированы через SystemManager

	# Подключение к интерфейсу командира
	battle_ui = get_node_or_null("BattleUI")
	if battle_ui:
		print("✅ Интерфейс командира активен")
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)
		battle_ui.start_battle.connect(_on_start_battle)
		battle_ui.spawn_unit_drag.connect(_on_spawn_unit_drag)
		battle_ui.build_structure_drag.connect(_on_build_structure_drag)
		battle_ui.use_ability.connect(_on_use_ability)
		
		print("🔗 Системы управления подключены")
	else:
		print("❌ Интерфейс командира недоступен!")

	# Создание поля боя (территория конфликта)
	create_battlefield()

	# Создание командных центров фракций
	create_command_centers()

	# Ожидание начала операции
	battle_started = false
	update_ui()
	
	print("⚡ Командный центр готов! Начните операцию для развертывания войск.")

func create_battlefield():
	# Создает поле боя - территорию конфликта между фракциями
	# Поверхность планеты (зеленая зона) - УВЕЛИЧЕНА для мобильных
	var field = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(40, 60)  # Увеличил с 30x50 до 40x60
	field.mesh = plane
	field.position = Vector3(0, 0, 0)
	var field_mat = StandardMaterial3D.new()
	field_mat.albedo_color = Color(0.2, 0.7, 0.2, 1.0)  # Поверхность планеты
	field.set_surface_override_material(0, field_mat)
	add_child(field)

	# Зона игрока (синяя, внизу карты) - УВЕЛИЧЕНА
	var player_zone = MeshInstance3D.new()
	var player_plane = PlaneMesh.new()
	player_plane.size = Vector2(40, 25)  # Увеличил с 30x20 до 40x25
	player_zone.mesh = player_plane
	player_zone.position = Vector3(0, 0.01, 17.5)  # Смещение к игроку
	var player_zone_mat = StandardMaterial3D.new()
	player_zone_mat.albedo_color = Color(0.2, 0.6, 1.0, 0.3)  # Синяя зона игрока
	player_zone_mat.flags_transparent = true
	player_zone.set_surface_override_material(0, player_zone_mat)
	add_child(player_zone)

	# Зона врага (красная, вверху карты) - УВЕЛИЧЕНА
	var enemy_zone = MeshInstance3D.new()
	var enemy_plane = PlaneMesh.new()
	enemy_plane.size = Vector2(40, 25)  # Увеличил с 30x20 до 40x25
	enemy_zone.mesh = enemy_plane
	enemy_zone.position = Vector3(0, 0.01, -17.5)  # Смещение к врагу
	var enemy_zone_mat = StandardMaterial3D.new()
	enemy_zone_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.3)  # Красная зона врага
	enemy_zone_mat.flags_transparent = true
	enemy_zone.set_surface_override_material(0, enemy_zone_mat)
	add_child(enemy_zone)

	# Демаркационная линия (граница территорий) - УВЕЛИЧЕНА
	var line = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(40, 0.2, 0.5)  # Увеличил ширину с 30 до 40
	line.mesh = box
	line.position = Vector3(0, 0.1, 0)
	var line_mat = StandardMaterial3D.new()
	line_mat.albedo_color = Color(1, 1, 1, 1)  # Нейтральная зона
	line_mat.emission_enabled = true
	line_mat.emission = Color(0.3, 0.3, 0.3)  # Слабое свечение
	line.set_surface_override_material(0, line_mat)
	add_child(line)

	# Подписи зон - БОЛЬШЕ ОТДАЛЕНЫ
	var player_zone_label = Label3D.new()
	player_zone_label.text = "ЗОНА ИГРОКА (СИНЯЯ)\nЮниты атакуют ВВЕРХ ↑"
	player_zone_label.position = Vector3(0, 1.0, 27)  # Увеличил с 22 до 27
	player_zone_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	player_zone_label.font_size = 64  # Увеличил с 48 до 64
	player_zone_label.modulate = Color(0.2, 0.6, 1, 1)
	player_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Добавляем контур для читаемости
	player_zone_label.outline_size = 8
	player_zone_label.outline_modulate = Color.BLACK
	add_child(player_zone_label)

	var enemy_zone_label = Label3D.new()
	enemy_zone_label.text = "ЗОНА ВРАГА (КРАСНАЯ)\nЮниты атакуют ВНИЗ ↓"
	enemy_zone_label.position = Vector3(0, 1.0, -27)  # Увеличил с -22 до -27
	enemy_zone_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	enemy_zone_label.font_size = 64  # Увеличил с 48 до 64
	enemy_zone_label.modulate = Color(1, 0.2, 0.2, 1)
	enemy_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Добавляем контур для читаемости
	enemy_zone_label.outline_size = 8
	enemy_zone_label.outline_modulate = Color.BLACK
	add_child(enemy_zone_label)

func create_command_centers():
	# Создает командные центры фракций
	# Командный центр игрока (синяя фракция) - ВНИЗУ карты
	var player_core = MeshInstance3D.new()
	var player_sphere = SphereMesh.new()
	player_sphere.radius = 1.5  # Увеличиваем размер для лучшей видимости
	player_sphere.height = 3.0
	player_core.mesh = player_sphere
	player_core.position = Vector3(0, 1.5, 25)  # Увеличил с 20 до 25
	player_core.name = "PlayerCoreVisual"
	var player_mat = StandardMaterial3D.new()
	player_mat.albedo_color = Color(0.2, 0.6, 1, 1)  # СИНИЙ = ИГРОК
	player_mat.emission_enabled = true
	player_mat.emission = Color(0.1, 0.3, 0.5)  # Синее свечение
	player_core.set_surface_override_material(0, player_mat)
	add_child(player_core)

	# Подпись для ядра игрока
	var player_label = Label3D.new()
	player_label.text = "ИГРОК (СИНИЙ)"
	player_label.position = Vector3(0, 3.5, 25)  # Увеличил с 20 до 25
	player_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	player_label.font_size = 80  # Увеличил с 56 до 80
	player_label.modulate = Color(0.2, 0.6, 1, 1)
	# Добавляем контур для читаемости
	player_label.outline_size = 10
	player_label.outline_modulate = Color.BLACK
	add_child(player_label)

	# Командный центр противника (красная фракция) - ВВЕРХУ карты
	var enemy_core = MeshInstance3D.new()
	var enemy_sphere = SphereMesh.new()
	enemy_sphere.radius = 1.5
	enemy_sphere.height = 3.0
	enemy_core.mesh = enemy_sphere
	enemy_core.position = Vector3(0, 1.5, -25)  # Увеличил с -20 до -25
	enemy_core.name = "EnemyCoreVisual"
	var enemy_mat = StandardMaterial3D.new()
	enemy_mat.albedo_color = Color(1, 0.2, 0.2, 1)  # КРАСНЫЙ = ВРАГ
	enemy_mat.emission_enabled = true
	enemy_mat.emission = Color(0.5, 0.1, 0.1)  # Красное свечение
	enemy_core.set_surface_override_material(0, enemy_mat)
	add_child(enemy_core)

	# Подпись для ядра врага
	var enemy_label = Label3D.new()
	enemy_label.text = "ВРАГ (КРАСНЫЙ)"
	enemy_label.position = Vector3(0, 3.5, -25)  # Увеличил с -20 до -25
	enemy_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	enemy_label.font_size = 80  # Увеличил с 56 до 80
	enemy_label.modulate = Color(1, 0.2, 0.2, 1)
	# Добавляем контур для читаемости
	enemy_label.outline_size = 10
	enemy_label.outline_modulate = Color.BLACK
	add_child(enemy_label)

	# Создание стартовых производственных модулей - ОБНОВЛЕНЫ ПОЗИЦИИ
	create_start_spawner("player", Vector3(-5, 0, 20))   # Увеличил с 15 до 20
	create_start_spawner("enemy", Vector3(5, 0, -20))    # Увеличил с -15 до -20

func init_energy_timer():
	# Таймер для автоматического пополнения энергии
	energy_timer = Timer.new()
	energy_timer.wait_time = energy_tick_time
	energy_timer.autostart = true
	energy_timer.timeout.connect(_on_energy_timer)
	add_child(energy_timer)

func init_crystal_system():
	# Создаем новую кристаллическую систему
	crystal_system = CrystalSystem.new()
	crystal_system.battle_manager = self
	add_child(crystal_system)
	
	# Подключаем сигналы
	crystal_system.crystal_captured.connect(_on_crystal_captured)
	crystal_system.crystal_depleted.connect(_on_crystal_depleted)
	# Убираем подключение к удаленному сигналу crystal_regenerated
	
	print("💎 Кристаллическая система инициализирована")

func init_ability_system():
	# Создаем систему способностей
	ability_system = AbilitySystem.new()
	ability_system.battle_manager = self
	add_child(ability_system)
	print("✨ Система способностей инициализирована")

func init_race_system():
	# Создаем систему рас
	race_system = RaceSystem.new()
	race_system.battle_manager = self
	add_child(race_system)
	
	# Устанавливаем расы по умолчанию
	race_system.set_player_race(RaceSystem.Race.HUMANS)
	race_system.set_enemy_race(RaceSystem.Race.UNDEAD)  # Теперь против техно-зануд Некрополя
	
	print("🏛️ Система рас инициализирована")

func init_system_manager():
	# Временно отключено для отладки
	print("🔧 SystemManager временно отключен")
	
	# Инициализируем системы напрямую (безопасно)
	init_systems_directly()

func init_systems_directly():
	# Безопасная инициализация систем без SystemManager
	print("🔧 Прямая инициализация систем...")
	
	# EffectSystem
	var effect_script = load("res://scripts/EffectSystem.gd")
	if effect_script:
		effect_system = effect_script.new()
		effect_system.name = "EffectSystem"
		effect_system.battle_manager = self
		add_child(effect_system)
		print("✅ EffectSystem загружена")
	
	# AudioSystem  
	var audio_script = load("res://scripts/AudioSystem.gd")
	if audio_script:
		audio_system = audio_script.new()
		audio_system.name = "AudioSystem"
		audio_system.battle_manager = self
		add_child(audio_system)
		print("✅ AudioSystem загружена")
	
	# NotificationSystem
	var notification_script = load("res://scripts/NotificationSystem.gd")
	if notification_script:
		notification_system = notification_script.new()
		notification_system.name = "NotificationSystem"
		notification_system.battle_manager = self
		add_child(notification_system)
		print("✅ NotificationSystem загружена")
	
	# StatisticsSystem
	var statistics_script = load("res://scripts/StatisticsSystem.gd")
	if statistics_script:
		statistics_system = statistics_script.new()
		statistics_system.name = "StatisticsSystem"
		statistics_system.battle_manager = self
		add_child(statistics_system)
		print("✅ StatisticsSystem загружена")
	
	# RaceAbilitySystem
	var race_ability_script = load("res://scripts/RaceAbilitySystem.gd")
	if race_ability_script:
		race_ability_system = race_ability_script.new()
		race_ability_system.name = "RaceAbilitySystem"
		race_ability_system.set_battle_manager(self)
		add_child(race_ability_system)
		print("✅ RaceAbilitySystem загружена")
	
	print("🔧 Все системы инициализированы напрямую")

func init_effect_system():
	# Система эффектов теперь инициализируется через SystemManager
	print("✨ EffectSystem инициализирована через SystemManager")

func init_audio_system():
	# Аудиосистема теперь инициализируется через SystemManager
	print("🔊 AudioSystem инициализирована через SystemManager")

func init_notification_system():
	# Система уведомлений теперь инициализируется через SystemManager
	print("📢 NotificationSystem инициализирована через SystemManager")

func init_statistics_system():
	# Система статистики теперь инициализируется через SystemManager
	print("📊 StatisticsSystem инициализирована через SystemManager")

func create_cores_and_spawners():
	# Удаляем старые ядра, если есть
	for node in get_children():
		if node.name == "PlayerCore" or node.name == "EnemyCore":
			node.queue_free()

	# Создаём ядро игрока (синее) - внизу экрана
	var player_core_scene = preload("res://scenes/Core.tscn")
	var player_core = player_core_scene.instantiate()
	player_core.name = "PlayerCore"
	player_core.position = Vector3(0, 0.5, 20)  # Игрок внизу экрана
	# Проверяем, что есть MeshInstance3D
	if not player_core.has_node("MeshInstance3D"):
		var mesh = MeshInstance3D.new()
		mesh.mesh = SphereMesh.new()
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.6, 1, 1)
		mesh.set_surface_override_material(0, mat)
		player_core.add_child(mesh)
	add_child(player_core)

	# Создаём ядро врага (красное) - вверху экрана
	var enemy_core_scene = preload("res://scenes/Core.tscn")
	var enemy_core = enemy_core_scene.instantiate()
	enemy_core.name = "EnemyCore"
	enemy_core.position = Vector3(0, 0.5, -20)  # Враг вверху экрана
	if not enemy_core.has_node("MeshInstance3D"):
		var mesh = MeshInstance3D.new()
		mesh.mesh = SphereMesh.new()
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0.2, 0.2, 1)
		mesh.set_surface_override_material(0, mat)
		enemy_core.add_child(mesh)
	add_child(enemy_core)

	# Создаём стартовые спавнеры игрока и врага
	create_start_spawner("player", Vector3(-4, 0, 15))   # Игрок внизу экрана
	create_start_spawner("enemy", Vector3(4, 0, -15))    # Враг вверху экрана

func create_start_spawner(team: String, position: Vector3):
	var spawner = spawner_scene.instantiate()
	spawner.position = position
	spawner.name = team.capitalize() + "StartSpawner"
	spawner.set("team", team)
	add_child(spawner)
	spawner.add_to_group("spawners")

func _on_start_battle():
	print("🚀 === BattleManager получил сигнал start_battle ===")
	print("1. Устанавливаем battle_started = true")
	battle_started = true
	
	print("2. Показываем уведомление о начале битвы...")
	# Уведомление о начале битвы
	if notification_system:
		notification_system.show_battle_start()
	
	print("3. Запускаем статистику...")
	# Начинаем отслеживание статистики
	if statistics_system:
		statistics_system.start_battle()
	
	print("4. Запускаем таймеры спавнеров...")
	# Запустить таймеры спавна только после старта боя
	var spawners = get_tree().get_nodes_in_group("spawners")
	print("📍 Найдено спавнеров: ", spawners.size())
	for spawner in spawners:
		if spawner.has_node("SpawnTimer"):
			spawner.get_node("SpawnTimer").autostart = true
			spawner.get_node("SpawnTimer").start()
			print("⏰ Запущен таймер спавнера: ", spawner.name)
		else:
			print("❌ Спавнер без таймера: ", spawner.name)
	
	print("5. Запускаем AI врага...")
	# Запускаем AI врага
	if enemy_decision_timer:
		enemy_decision_timer.start()
		print("🤖 AI таймер решений запущен")
	if enemy_ai_timer:
		enemy_ai_timer.start()
		print("🤖 AI таймер спавна запущен")
	
	print("6. Создаем тестовых юнитов...")
	# Создаем тестовых юнитов для проверки
	spawn_unit_at_pos("player", Vector3(-2, 0, 12), "soldier")  # Игрок внизу экрана
	spawn_unit_at_pos("enemy", Vector3(2, 0, -12), "soldier")   # Враг вверху экрана
	
	print("🎮 === БИТВА УСПЕШНО ЗАПУЩЕНА! ===")

func _on_energy_timer():
	if not battle_started:
		return
	player_energy += energy_gain_per_tick
	enemy_energy += energy_gain_per_tick
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)
	
	# Периодически проверяем условия победы (каждую секунду)
	check_victory_conditions()

# НОВАЯ ЛОГИКА ПОБЕДЫ
func check_victory_conditions():
	if not battle_started:
		return
		
	# Условие 1: Уничтожение вражеского ядра (HP = 0)
	if enemy_base_hp <= 0:
		finish_battle("player")
		return
	elif player_base_hp <= 0:
		finish_battle("enemy")
		return
	
	# Условие 2: Уничтожение всех зданий противника
	var player_spawner_count = get_team_spawner_count("player")
	var enemy_spawner_count = get_team_spawner_count("enemy")
	
	# Игрок побеждает если у врага нет ядра или зданий
	if enemy_base_hp <= 0 or (enemy_spawner_count == 0 and player_spawner_count > 0):
		finish_battle("player")
		return
	
	# Враг побеждает если у игрока нет ядра или зданий
	if player_base_hp <= 0 or (player_spawner_count == 0 and enemy_spawner_count > 0):
		finish_battle("enemy")
		return

func get_team_unit_count(team: String) -> int:
	var count = 0
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit.team == team:
			count += 1
	return count

func get_team_spawner_count(team: String) -> int:
	var count = 0
	var all_spawners = get_tree().get_nodes_in_group("spawners")
	for spawner in all_spawners:
		if spawner.team == team:
			count += 1
	return count

# Спавн юнита на линии
func spawn_unit(team, lane_idx):
	if not battle_started:
		return
	if lane_idx < 0 or lane_idx >= lanes.size():
		return
	var lane = lanes[lane_idx]
	var start_pos = lane.get_node("Start").global_position
	var end_pos = lane.get_node("End").global_position
	var unit = unit_scene.instantiate()
	unit.team = team
	unit.global_position = start_pos
	unit.target_pos = end_pos
	unit.battle_manager = self
	get_parent().add_child(unit)

# ВОССТАНАВЛИВАЕМ ЛОГИКУ АТАКИ ЯДРА
func unit_reached_base(unit):
	# Юниты наносят урон вражескому ядру при достижении
	if unit.team == "player":
		enemy_base_hp -= unit.damage
		print("💥 ", unit.unit_type, " атакует вражеское ядро! Урон: ", unit.damage, " HP ядра: ", enemy_base_hp)
		if enemy_base_hp <= 0:
			print("🏆 Вражеское ядро уничтожено!")
	elif unit.team == "enemy":
		player_base_hp -= unit.damage
		print("💥 Вражеский ", unit.unit_type, " атакует ваше ядро! Урон: ", unit.damage, " HP ядра: ", player_base_hp)
		if player_base_hp <= 0:
			print("💀 Ваше ядро уничтожено!")
	
	# Обновляем UI
	update_ui()
	
	# Проверяем условия победы после атаки ядра
	call_deferred("check_victory_conditions")

# Обработка победы/поражения
func finish_battle(winner):
	battle_finished.emit(winner)
	print("Битва завершена! Победитель: ", winner)
	
	# Завершаем статистику битвы
	if statistics_system:
		statistics_system.end_battle(winner)
	
	# Показываем уведомление о победе/поражении
	if notification_system:
		notification_system.show_victory(winner)
	
	# TODO: показать экран победы/поражения

# TODO: добавить обработку UI, победы, расширение логики по мере развития 

func _on_build_pressed():
	if player_energy >= building_cost:
		is_building_mode = true
		create_building_preview()

func create_building_preview():
	if building_preview:
		building_preview.queue_free()
	var preview = unit_scene.instantiate()
	preview.modulate = Color(0.5, 1, 0.5, 0.5) # зелёный по умолчанию
	preview.name = "BuildingPreview"
	preview.set_physics_process(false)
	add_child(preview)
	building_preview = preview

func _unhandled_input(event):
	if is_building_mode:
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			var pos = get_mouse_map_position(event.position)
			if building_preview:
				building_preview.global_position = pos
				can_build_here = is_valid_build_position(pos)
				building_preview.modulate = Color(0.5, 1, 0.5, 0.5) if can_build_here else Color(1, 0.3, 0.3, 0.5)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pass
			else:
				if can_build_here and player_energy >= building_cost:
					place_spawner("player", "spawner", building_preview.global_position)
					player_energy -= building_cost
					update_ui()
					building_preview.queue_free()
					building_preview = null
					is_building_mode = false
				else:
					pass
	else:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if battle_started and player_energy >= 30:
				var pos = get_mouse_map_position(event.position)
				if is_valid_build_position(pos):
					place_spawner("player", "spawner", pos)
					player_energy -= 30
					update_ui()
	
	# Правый клик для расовых способностей
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if battle_started and race_ability_system:
			var pos = get_mouse_map_position(event.position)
			# Используем ЭМИ-импульс как базовую способность нежити
			if race_ability_system.can_use_ability("player", "emp_pulse"):
				race_ability_system.use_ability("player", "emp_pulse", pos)
				update_ui()
			else:
				print("❌ Нельзя использовать ЭМИ-импульс")

func get_mouse_map_position(screen_pos):
	var camera_to_use = battle_camera if battle_camera else get_viewport().get_camera_3d()
	if not camera_to_use:
		print("❌ Камера недоступна!")
		return Vector3.ZERO
	
	# Получаем луч от камеры через позицию мыши
	var from = camera_to_use.project_ray_origin(screen_pos)
	var direction = camera_to_use.project_ray_normal(screen_pos)
	
	# Пересечение луча с плоскостью y = 0 (поле боя)
	var plane_y = 0.0
	if direction.y == 0:
		return Vector3.ZERO  # Луч параллелен плоскости
	
	var t = (plane_y - from.y) / direction.y
	if t < 0:
		return Vector3.ZERO  # Пересечение позади камеры
	
	var intersection = from + direction * t
	
	print("🎯 Экранная позиция: ", screen_pos, " → 3D позиция: ", intersection)
	return intersection

func get_mouse_world_position() -> Vector3:
	var mouse_pos = get_viewport().get_mouse_position()
	return get_mouse_map_position(mouse_pos)

func is_valid_build_position(pos: Vector3) -> bool:
	var map_width = 40.0
	var map_height = 60.0
	if pos.z < 0:  # Игрок строит только на нижней половине (положительные Z)
		return false
	if pos.x < -map_width/2 or pos.x > map_width/2:
		return false
	if pos.z > map_height/2 or pos.z < 0:
		return false
	var all_spawners = get_tree().get_nodes_in_group("spawners")
	for s in all_spawners:
		if s.global_position.distance_to(pos) < 1.5:
			return false
	return true

func is_valid_enemy_build_position(pos: Vector3) -> bool:
	# Проверяет, можно ли строить в данной позиции для врага
	# Враг может строить только в верхней половине карты (z < 0)
	if pos.z > -5.0:
		return false
	
	# Проверяем расстояние до других зданий
	var min_distance = 3.0
	var spawners = get_tree().get_nodes_in_group("spawners")
	for spawner in spawners:
		if spawner.global_position.distance_to(pos) < min_distance:
			return false
	
	return true

# Drag&drop: спавн юнита
func _on_spawn_unit_drag(unit_type, screen_pos):
	print("🎮 === DRAG & DROP ЮНИТА ===")
	print("1. Тип юнита: ", unit_type)
	print("2. Позиция экрана: ", screen_pos)
	print("3. Битва началась: ", battle_started)
	
	if not battle_started:
		print("❌ Битва не началась!")
		return
	
	# Специальная обработка для коллекторов - автоматическое размещение
	if unit_type == "collector":
		print("🏃 Коллектор: автоматическое размещение на игровой половине")
		var spawn_pos = Vector3(randf_range(-4.0, 4.0), 0, randf_range(8.0, 18.0))
		
		var energy_cost = get_unit_cost(unit_type)
		var crystal_cost = get_unit_crystal_cost(unit_type)
		
		if player_energy >= energy_cost and player_crystals >= crystal_cost:
			spawn_unit_at_pos("player", spawn_pos, unit_type)
			print("✅ Коллектор автоматически создан на позиции ", spawn_pos)
			update_ui()
		else:
			print("❌ Недостаточно ресурсов для коллектора (нужно: ", energy_cost, " энергии, ", crystal_cost, " кристаллов)")
		return
	
	# Обычная обработка для других юнитов (если понадобится в будущем)
	var energy_cost = get_unit_cost(unit_type)
	var crystal_cost = get_unit_crystal_cost(unit_type)
	
	print("4. Стоимость: ", energy_cost, " энергии, ", crystal_cost, " кристаллов")
	print("5. Ресурсы игрока: ", player_energy, " энергии, ", player_crystals, " кристаллов")
	
	if player_energy < energy_cost or player_crystals < crystal_cost:
		print("❌ Недостаточно ресурсов для ", unit_type, " (нужно: ", energy_cost, " энергии, ", crystal_cost, " кристаллов)")
		return
		
	var pos = get_mouse_map_position(screen_pos)
	print("6. 3D позиция на карте: ", pos)
	
	if pos == Vector3.ZERO:
		print("❌ Не удалось определить позицию на карте!")
		return
	
	if is_valid_unit_position(pos):
		spawn_unit_at_pos("player", pos, unit_type)
		print("✅ ", unit_type, " успешно создан на позиции ", pos)
		update_ui()
	else:
		print("❌ Нельзя разместить ", unit_type, " в позиции ", pos)
		print("   Причина: позиция вне игровой зоны или слишком близко к зданию")

# Drag&drop: строительство здания (определяем тип по drag_type из UI)
func _on_build_structure_drag(screen_pos):
	print("🏗️ === DRAG & DROP ЗДАНИЯ ===")
	print("1. Позиция экрана: ", screen_pos)
	print("2. Битва началась: ", battle_started)
	
	if not battle_started:
		print("❌ Битва не началась!")
		return
	
	# Определяем тип здания по drag_type из BattleUI
	var building_type = "tower"  # По умолчанию башня
	var building_cost = 60
	var crystal_cost = 0
	
	# Получаем тип здания из UI (нужно будет передать из BattleUI)
	if battle_ui and battle_ui.drag_type:
		match battle_ui.drag_type:
			"barracks":
				building_type = "barracks"
				building_cost = 80
			"training_camp":
				building_type = "training_camp"
				building_cost = 120
				crystal_cost = 20
			"magic_academy":
				building_type = "magic_academy"
				building_cost = 100
				crystal_cost = 30
			"collector_facility":
				building_type = "collector_facility"
				building_cost = 90
				crystal_cost = 15
			"mech_factory":
				building_type = "mech_factory"
				building_cost = 150
				crystal_cost = 25
			"drone_factory":
				building_type = "drone_factory"
				building_cost = 130
				crystal_cost = 20
			_:
				building_type = "tower"
				building_cost = 60
	
	print("3. Тип здания: ", building_type)
	print("4. Стоимость: ", building_cost, " энергии, ", crystal_cost, " кристаллов")
	print("5. У игрока: ", player_energy, " энергии, ", player_crystals, " кристаллов")
	
	if player_energy < building_cost or player_crystals < crystal_cost:
		print("❌ Недостаточно ресурсов для постройки ", building_type, "!")
		return
		
	var pos = get_mouse_map_position(screen_pos)
	print("6. 3D позиция на карте: ", pos)
	
	if pos == Vector3.ZERO:
		print("❌ Не удалось определить позицию на карте!")
		return
		
	if is_valid_build_position(pos):
		print("✅ Позиция валидна, строим ", building_type, "...")
		place_spawner("player", building_type, pos)
		player_energy -= building_cost
		player_crystals -= crystal_cost
		update_ui()
		print("✅ ", building_type, " построено успешно!")
	else:
		print("❌ Нельзя построить ", building_type, " в позиции ", pos)
		print("   Причина: вне игровой зоны или слишком близко к другому зданию")

func is_valid_unit_position(pos: Vector3) -> bool:
	var map_width = 40.0
	var map_height = 60.0
	if pos.z < 0:  # Игрок размещает юнитов только на нижней половине (положительные Z)
		return false
	if pos.x < -map_width/2 or pos.x > map_width/2:
		return false
	if pos.z > map_height/2 or pos.z < 0:
		return false
	var all_spawners = get_tree().get_nodes_in_group("spawners")
	for s in all_spawners:
		if s.global_position.distance_to(pos) < 2.5:
			return false
	return true

func spawn_unit_at_pos(team, pos, unit_type="soldier"):
	if not can_spawn_unit(team, unit_type):
		print("❌ Недостаточно ресурсов!")
		return
	
	var energy_cost = get_unit_cost(unit_type)
	var crystal_cost = get_unit_crystal_cost(unit_type)
	
	print("🔨 Создаем юнита: ", team, " ", unit_type, " в позиции ", pos)
	var unit = unit_scene.instantiate()
	add_child(unit)
	unit.team = team
	unit.unit_type = unit_type
	unit.global_position = pos
	# ПРАВИЛЬНАЯ ЛОГИКА: Юниты идут к вражескому ядру
	if team == "player":
		unit.target_pos = Vector3(0, 0, -25)  # Игрок атакует вражеское ядро (север)
		player_energy -= energy_cost
		player_crystals -= crystal_cost
	else:
		unit.target_pos = Vector3(0, 0, 25)   # Враг атакует ядро игрока (юг)
		enemy_energy -= energy_cost
		enemy_crystals -= crystal_cost
	unit.battle_manager = self
	unit.add_to_group("units")
	
	# Эффект спавна юнита
	if effect_system:
		effect_system.create_spawn_effect(pos, team)
	
	# Звук спавна юнита
	if audio_system:
		audio_system.play_unit_spawn_sound(pos)
	
	# Уведомление о создании юнита
	if notification_system:
		notification_system.show_unit_spawned(unit_type, team)
	
	# Регистрируем в статистике
	if statistics_system:
		statistics_system.register_unit_spawned(team, unit_type)
	
	print("✅ Юнит создан успешно: ", unit.name, " команда: ", unit.team)
	print("🎯 Цель юнита: ", unit.target_pos)
	var units_in_group = get_tree().get_nodes_in_group("units")
	print("📊 Всего юнитов в группе: ", units_in_group.size())
	
	# Проверяем условия победы после создания юнита
	call_deferred("check_victory_conditions")

# Добавляю функцию update_ui, если её нет
func update_ui():
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy, player_crystals, enemy_crystals)

# Добавляю функцию place_spawner, если её нет
func place_spawner(team: String, spawner_type: String, position: Vector3):
	if not can_build_structure(team, spawner_type):
		print("Недостаточно энергии для постройки!")
		return
	var spawner = spawner_scene.instantiate()
	add_child(spawner)
	spawner.team = team
	spawner.spawner_type = spawner_type
	spawner.global_position = position
	spawner.name = team.capitalize() + spawner_type.capitalize() + str(randi())
	spawner.add_to_group("spawners")
	
	# Специальная настройка для разных типов зданий
	match spawner_type:
		"collector_facility":
			spawner.unit_type = "collector"
		"barracks":
			spawner.unit_type = "soldier"
		"training_camp":
			spawner.unit_type = "elite_soldier"
		"magic_academy":
			spawner.unit_type = "crystal_mage"
		"mech_factory":
			spawner.unit_type = "battle_robot"  # Новый тип юнита
		"drone_factory":
			spawner.unit_type = "attack_drone"  # Новый тип юнита
		"tower":
			spawner.unit_type = "tower"  # Башня не производит юнитов
	
	# Устанавливаем цвет здания
	set_building_visual(spawner, spawner_type, team)
	
	# Звук постройки здания
	if audio_system:
		audio_system.play_building_place_sound(position)
	
	# Уведомление о постройке
	if notification_system:
		notification_system.show_building_constructed(spawner_type, team)
	
	# Регистрируем в статистике
	if statistics_system:
		statistics_system.register_building_built(team, spawner_type)
	
	print("Построен спавнер: ", team, " ", spawner_type, " в позиции ", position)

func set_building_visual(spawner, spawner_type: String, team: String):
	# Устанавливаем визуальный стиль зданий
	var mesh_node = spawner.get_node_or_null("MeshInstance3D")
	if not mesh_node:
		mesh_node = MeshInstance3D.new()
		spawner.add_child(mesh_node)
	
	# Создаем разные формы для разных зданий
	match spawner_type:
		"barracks":
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(2, 1.5, 2)
			mesh_node.mesh = box_mesh
		"tower":
			var cylinder_mesh = CylinderMesh.new()
			cylinder_mesh.height = 3
			cylinder_mesh.top_radius = 0.5
			cylinder_mesh.bottom_radius = 0.8
			mesh_node.mesh = cylinder_mesh
		"training_camp":
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(2.5, 1.2, 2.5)
			mesh_node.mesh = box_mesh
		"magic_academy":
			var sphere_mesh = SphereMesh.new()
			sphere_mesh.radius = 1.2
			mesh_node.mesh = sphere_mesh
		"mech_factory":
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(3, 2, 2)
			mesh_node.mesh = box_mesh
		"drone_factory":
			var cylinder_mesh = CylinderMesh.new()
			cylinder_mesh.height = 2.5
			cylinder_mesh.top_radius = 1.5
			cylinder_mesh.bottom_radius = 1.2
			mesh_node.mesh = cylinder_mesh
		_:
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(1.5, 1.5, 1.5)
			mesh_node.mesh = box_mesh
	
	# Устанавливаем цвет по команде и типу здания
	var material = StandardMaterial3D.new()
	if team == "player":
		material.albedo_color = get_building_color(spawner_type, Color.BLUE)
	else:
		material.albedo_color = get_building_color(spawner_type, Color.RED)
	
	material.emission_enabled = true
	material.emission = material.albedo_color * 0.3
	mesh_node.material_override = material

func get_building_color(building_type: String, base_color: Color) -> Color:
	match building_type:
		"barracks": return base_color.lerp(Color.CYAN, 0.5)
		"tower": return base_color.lerp(Color.ORANGE, 0.5)
		"training_camp": return base_color.lerp(Color.GOLD, 0.5)
		"magic_academy": return base_color.lerp(Color.MAGENTA, 0.5)
		"mech_factory": return base_color.lerp(Color.STEEL_BLUE, 0.5)
		"drone_factory": return base_color.lerp(Color.LIGHT_BLUE, 0.5)
		_: return base_color

func get_unit_cost(unit_type: String) -> int:
	match unit_type:
		"soldier":
			return 25        # Базовый юнит - доступная цена
		"tank":
			return 60        # Танки дороже из-за высокого HP
		"drone":
			return 30        # Снижена цена для баланса
		"elite_soldier":
			return 35        # Премиум юнит
		"crystal_mage":
			return 30        # Снижена энергия, но нужны кристаллы
		"heavy_tank":
			return 100       # Супертанк - очень дорого
		"collector":
			return 40        # Специализированный юнит
		_:
			return 25

func get_unit_crystal_cost(unit_type: String) -> int:
	match unit_type:
		"crystal_mage":
			return 12        # Снижено для баланса
		"elite_soldier":
			return 8         # Снижено для доступности
		"heavy_tank":
			return 15        # Снижено, но все еще дорого
		"collector":
			return 5         # Небольшая стоимость кристаллов
		_:
			return 0

func get_structure_cost(structure_type: String) -> int:
	match structure_type:
		"tower":
			return 60
		"spawner":
			return 30
		"barracks":
			return 80
		"collector_facility":
			return 50  # Средняя стоимость для комплекса коллекторов
		"training_camp":
			return 120
		"magic_academy":
			return 100
		"mech_factory":
			return 150  # Новое здание для роботов
		"drone_factory":
			return 130  # Новое здание для дронов
		"orbital_drop":
			return 100
		"energy_generator":
			return 70
		"shield_generator":
			return 90
		"tech_lab":
			return 120
		_:
			return 60

func get_structure_crystal_cost(structure_type: String) -> int:
	match structure_type:
		"training_camp":
			return 20
		"magic_academy":
			return 30
		"mech_factory":
			return 25  # Кристаллы для мех завода
		"drone_factory":
			return 20  # Кристаллы для дрон фабрики
		"collector_facility":
			return 15
		_:
			return 0

func get_random_enemy_spawn_position() -> Vector3:
	# Случайная позиция на вражеской стороне (z < 0, вверху экрана)
	var x = randf_range(-8.0, 8.0)
	var z = randf_range(-18.0, -8.0)
	return Vector3(x, 0, z)

func get_random_enemy_build_position() -> Vector3:
	# Позиция для постройки на вражеской стороне (вверху экрана)
	var attempts = 0
	var max_attempts = 10
	
	while attempts < max_attempts:
		var x = randf_range(-6.0, 6.0)
		var z = randf_range(-18.0, -5.0)
		var pos = Vector3(x, 0, z)
		
		if is_valid_enemy_build_position(pos):
			return pos
		
		attempts += 1
	
	# Если не нашли подходящую позицию, возвращаем базовую
	return Vector3(randf_range(-4.0, 4.0), 0, -12.0)

func _on_enemy_ai_spawn():
	if not battle_started:
		return
	
	# Автоматический спавн базовых юнитов каждые 5 секунд
	if enemy_energy >= 20 and enemy_current_soldiers < 2:
		spawn_enemy_unit("soldier")

func _on_spawn_soldier():
	print("Кнопка спавна солдата нажата!")
	if battle_started and can_spawn_unit("player", "soldier"):
		# Спавн юнита-солдата рядом с игроком (внизу экрана)
		var spawn_pos = Vector3(randf_range(-4.0, 4.0), 0, 12.0)
		spawn_unit_at_pos("player", spawn_pos, "soldier")
		update_ui()

func _on_build_tower():
	print("Кнопка постройки башни нажата!")
	if battle_started and can_build_structure("player", "tower"):
		# Строим башню рядом с базой игрока (внизу экрана)
		var build_pos = Vector3(randf_range(-6.0, 6.0), 0, 15.0)
		if is_valid_build_position(build_pos):
			place_spawner("player", "tower", build_pos)
			player_energy -= get_structure_cost("tower")
			update_ui()

func _on_spawn_elite_soldier():
	print("Кнопка спавна элитного солдата нажата!")
	if battle_started and can_spawn_unit("player", "elite_soldier"):
		var spawn_pos = Vector3(randf_range(-4.0, 4.0), 0, 12.0)
		spawn_unit_at_pos("player", spawn_pos, "elite_soldier")
		update_ui()

func _on_spawn_crystal_mage():
	print("Кнопка спавна кристального мага нажата!")
	if battle_started and can_spawn_unit("player", "crystal_mage"):
		var spawn_pos = Vector3(randf_range(-4.0, 4.0), 0, 12.0)
		spawn_unit_at_pos("player", spawn_pos, "crystal_mage")
		update_ui()

func _on_use_ability(ability_name: String, position: Vector3):
	print("Кнопка способности ", ability_name, " нажата!")
	if battle_started and race_ability_system and race_ability_system.can_use_ability("player", ability_name):
		race_ability_system.use_ability("player", ability_name, position)
		update_ui()
	else:
		print("❌ Нельзя использовать ", ability_name)

func can_spawn_unit(team, unit_type):
	var energy_cost = get_unit_cost(unit_type)
	var crystal_cost = get_unit_crystal_cost(unit_type)
	
	if team == "player":
		return player_energy >= energy_cost and player_crystals >= crystal_cost
	else:
		return enemy_energy >= energy_cost and enemy_crystals >= crystal_cost

func can_build_structure(team, structure_type):
	var cost = get_structure_cost(structure_type)
	if team == "player":
		return player_energy >= cost
	else:
		return enemy_energy >= cost

func on_spawner_drop(spawner_type, global_pos):
	if not battle_started:
		print("[DragDrop] Битва не начата, нельзя строить спавнеры!")
		return
	
	var cost = get_structure_cost(spawner_type)
	if player_energy < cost:
		print("[DragDrop] Недостаточно энергии для постройки ", spawner_type, " (нужно: ", cost, ", есть: ", player_energy, ")")
		return
	
	# Преобразуем экранные координаты в 3D-позицию на поле
	var pos = get_mouse_map_position(global_pos)
	print("[DragDrop] Попытка построить спавнер '", spawner_type, "' в точке ", pos)
	if is_valid_build_position(pos):
		place_spawner("player", spawner_type, pos)
		player_energy -= cost
		update_ui()
		print("[DragDrop] Спавнер '", spawner_type, "' успешно построен за ", cost, " энергии!")
	else:
		print("[DragDrop] Нельзя построить спавнер в этой позиции!")

# Обработчики системы рас
func _on_summon_hero(position: Vector3):
	print("🦸 Кнопка призыва героя нажата!")
	if not race_system or not battle_started:
		return
		
	var player_race_value = race_system.player_race
	if race_system.can_summon_hero(player_race_value, player_energy, player_crystals):
		if race_system.summon_hero(player_race_value, position, "player"):
			update_ui()
			print("✅ Герой успешно призван!")
	else:
		print("❌ Недостаточно ресурсов для призыва героя")

func _on_use_race_ability(ability_name: String, position: Vector3):
	print("🎭 Расовая способность ", ability_name, " использована!")
	if not race_system or not battle_started:
		return
		
	var player_race_value = race_system.player_race
	if race_system.use_race_ability(player_race_value, ability_name, position, "player"):
		update_ui()
		print("✅ Расовая способность использована!")
	else:
		print("❌ Нельзя использовать расовую способность")

func _on_spawn_collector():
	print("🏃 Кнопка спавна коллектора нажата!")
	if battle_started and can_spawn_unit("player", "collector"):
		var spawn_pos = Vector3(randf_range(-4.0, 4.0), 0, 13.0)
		spawn_unit_at_pos("player", spawn_pos, "collector")
		update_ui()
		print("✅ Коллектор отправлен для захвата территорий!")

func ai_consider_collector_strategy():
	# Дополнительная стратегия AI для использования коллекторов
	if enemy_energy >= get_unit_cost("collector") and enemy_crystals >= get_unit_crystal_cost("collector"):
		# Проверяем доступные кристаллы
		if crystal_system:
			var available_crystals = crystal_system.get_crystal_info()
			var neutral_crystals = 0
			for crystal in available_crystals:
				if crystal.owner == "neutral" or crystal.owner != "enemy":
					neutral_crystals += 1
			
			if neutral_crystals > 0:
				# 30% шанс создать коллектора если есть свободные кристаллы
				if randf() < 0.3:
					var spawn_pos = get_random_enemy_spawn_position()
					spawn_unit_at_pos("enemy", spawn_pos, "collector")
					enemy_energy -= get_unit_cost("collector")
					enemy_crystals -= get_unit_crystal_cost("collector")
					print("🤖 AI создал коллектора для захвата кристаллов")
					update_ui()

func _on_crystal_captured(crystal_id: int, new_owner: String, crystal_type):
	print("💎 Кристалл ", crystal_id, " захвачен командой ", new_owner)
	
	# Показываем уведомление
	if notification_system:
		var type_name = get_crystal_type_name(crystal_type)
		notification_system.show_notification("Кристалл " + type_name + " захвачен!")
	
	# Проверяем условия победы
	call_deferred("check_victory_conditions")

func _on_crystal_depleted(crystal_id: int):
	print("💎 Кристалл ", crystal_id, " истощен")
	if notification_system:
		notification_system.show_notification("Кристалл истощен!")

# Убираем функцию _on_crystal_regenerated так как сигнал удален

# Обновляем методы для работы с кристаллами
func get_controlled_crystals(team: String) -> int:
	if crystal_system:
		return crystal_system.get_controlled_crystals(team)
	return 0

func get_crystal_type_name(crystal_type: int) -> String:
	# Безопасное получение имени типа кристалла
	match crystal_type:
		0: return "MAIN_CRYSTAL"
		1: return "ENERGY_CRYSTAL"
		2: return "TECH_CRYSTAL"
		3: return "BIO_CRYSTAL"
		4: return "PSI_CRYSTAL"
		_: return "UNKNOWN"

# СИСТЕМА УПРАВЛЕНИЯ ЮНИТАМИ МЫШЬЮ
func handle_left_click_selection(screen_pos: Vector2):
	# ЛКМ - выбор юнитов игрока
	if not battle_started:
		return
	
	var world_pos = screen_to_world_position(screen_pos)
	if not world_pos:
		return
	
	# Ищем ближайший юнит игрока
	var closest_unit = find_closest_player_unit(world_pos)
	
	if closest_unit:
		# Выбираем юнит
		select_unit(closest_unit)
		print("🎯 Выбран юнит: ", closest_unit.unit_type, " в позиции ", closest_unit.global_position)
	else:
		# Снимаем выбор
		clear_selection()
		print("❌ Выбор снят")

func handle_right_click_command(screen_pos: Vector2):
	# ПКМ - команда выбранным юнитам
	if not battle_started or selected_units.is_empty():
		return
	
	var world_pos = screen_to_world_position(screen_pos)
	if not world_pos:
		return
	
	# Командуем всем выбранным юнитам
	for unit in selected_units:
		if is_instance_valid(unit):
			command_unit_to_position(unit, world_pos)
	
	print("📍 Команда ", selected_units.size(), " юнитам: двигаться к ", world_pos)
	
	# Создаем визуальный эффект команды
	create_command_indicator(world_pos)

func screen_to_world_position(screen_pos: Vector2) -> Vector3:
	# Преобразуем экранные координаты в мировые
	if not battle_camera:
		return Vector3.ZERO
	
	# Используем raycast от камеры через экранную позицию
	var ray_origin = battle_camera.project_ray_origin(screen_pos)
	var ray_direction = battle_camera.project_ray_normal(screen_pos)
	
	# Пересечение луча с плоскостью y=0 (поверхность поля)
	var plane_y = 0.0
	var t = (plane_y - ray_origin.y) / ray_direction.y
	
	if t > 0:
		var intersection = ray_origin + ray_direction * t
		return intersection
	
	return Vector3.ZERO

func find_closest_player_unit(world_pos: Vector3) -> Unit:
	var closest_unit = null
	var closest_distance = 3.0  # Максимальное расстояние для выбора
	
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit.team == "player":
			var distance = unit.global_position.distance_to(world_pos)
			if distance < closest_distance:
				closest_distance = distance
				closest_unit = unit
	
	return closest_unit

func select_unit(unit: Unit):
	# Снимаем предыдущий выбор
	clear_selection()
	
	# Выбираем новый юнит
	selected_units.append(unit)
	
	# Создаем визуальный индикатор выбора
	create_selection_indicator(unit)

func clear_selection():
	selected_units.clear()
	
	# Удаляем визуальные индикаторы
	if selection_indicator:
		selection_indicator.queue_free()
		selection_indicator = null

func create_selection_indicator(unit: Unit):
	# Создаем визуальный индикатор выбранного юнита
	selection_indicator = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.8
	ring_mesh.outer_radius = 1.2
	selection_indicator.mesh = ring_mesh
	selection_indicator.position = Vector3(0, 0.1, 0)
	
	# Материал с зеленым свечением
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN
	material.emission_enabled = true
	material.emission = Color.GREEN * 0.5
	material.flags_transparent = true
	material.flags_unshaded = true
	selection_indicator.material_override = material
	
	# Добавляем к юниту
	unit.add_child(selection_indicator)
	
	# Анимация вращения
	var tween = create_tween()
	tween.set_loops()
	tween.tween_method(func(angle): selection_indicator.rotation.y = angle, 0.0, TAU, 2.0)

func command_unit_to_position(unit: Unit, target_pos: Vector3):
	# Командуем юниту двигаться к позиции
	if not is_instance_valid(unit):
		return
	
	# Устанавливаем новую цель
	unit.target_pos = target_pos
	unit.target = null  # Сбрасываем текущую цель атаки
	
	print("🚶 Юнит ", unit.unit_type, " получил команду двигаться к ", target_pos)

func create_command_indicator(world_pos: Vector3):
	# Создаем визуальный эффект команды
	var indicator = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.3
	indicator.mesh = sphere_mesh
	indicator.position = world_pos + Vector3(0, 0.2, 0)
	
	# Материал с синим свечением
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.CYAN
	material.emission_enabled = true
	material.emission = Color.CYAN * 0.8
	material.flags_transparent = true
	indicator.material_override = material
	
	add_child(indicator)
	
	# Анимация исчезновения
	var tween = create_tween()
	tween.parallel().tween_property(indicator, "scale", Vector3.ZERO, 1.0)
	tween.parallel().tween_property(indicator, "modulate", Color.TRANSPARENT, 1.0)
	tween.tween_callback(indicator.queue_free)

func init_enemy_ai():
	# Инициализация AI врага
	print("🤖 Инициализация AI врага...")
	
	# Таймер для принятия решений AI
	enemy_decision_timer = Timer.new()
	enemy_decision_timer.wait_time = 3.0  # AI принимает решения каждые 3 секунды
	enemy_decision_timer.autostart = false  # Запускается только после начала битвы
	enemy_decision_timer.timeout.connect(_on_enemy_ai_decision)
	add_child(enemy_decision_timer)
	
	# Таймер для автоматического спавна врагов
	enemy_ai_timer = Timer.new()
	enemy_ai_timer.wait_time = 5.0  # Спавн каждые 5 секунд
	enemy_ai_timer.autostart = false  # Запускается только после начала битвы
	enemy_ai_timer.timeout.connect(_on_enemy_ai_spawn)
	add_child(enemy_ai_timer)
	
	print("✅ AI врага инициализирован")

func _on_enemy_ai_decision():
	# AI принимает решения о стратегии
	if not battle_started:
		return
	
	print("🤖 AI принимает решение...")
	
	# Простая логика AI
	var player_unit_count = get_team_unit_count("player")
	var enemy_unit_count = get_team_unit_count("enemy")
	
	# Если у игрока больше юнитов, AI строит защиту
	if player_unit_count > enemy_unit_count + 1:
		ai_consider_defense()
	else:
		ai_consider_attack()
	
	# AI также рассматривает использование коллекторов
	ai_consider_collector_strategy()

func ai_consider_defense():
	# AI рассматривает оборонительную стратегию
	if enemy_energy >= get_structure_cost("tower"):
		var build_pos = get_random_enemy_build_position()
		if is_valid_enemy_build_position(build_pos):
			place_spawner("enemy", "tower", build_pos)
			enemy_energy -= get_structure_cost("tower")
			print("🤖 AI построил оборонительную башню")
			update_ui()

func ai_consider_attack():
	# AI рассматривает атакующую стратегию
	if enemy_energy >= get_unit_cost("soldier"):
		spawn_enemy_unit("soldier")
		print("🤖 AI создал солдата для атаки")
	elif enemy_energy >= get_structure_cost("barracks"):
		var build_pos = get_random_enemy_build_position()
		if is_valid_enemy_build_position(build_pos):
			place_spawner("enemy", "barracks", build_pos)
			enemy_energy -= get_structure_cost("barracks")
			print("🤖 AI построил казармы")
			update_ui()

func spawn_enemy_unit(unit_type: String):
	# Спавн вражеского юнита
	if not battle_started:
		return
	
	var energy_cost = get_unit_cost(unit_type)
	var crystal_cost = get_unit_crystal_cost(unit_type)
	
	if enemy_energy < energy_cost or enemy_crystals < crystal_cost:
		print("🤖 AI: недостаточно ресурсов для ", unit_type)
		return
	
	var spawn_pos = get_random_enemy_spawn_position()
	spawn_unit_at_pos("enemy", spawn_pos, unit_type)
	
	enemy_energy -= energy_cost
	enemy_crystals -= crystal_cost
	
	print("🤖 AI создал ", unit_type, " за ", energy_cost, "⚡ + ", crystal_cost, "💎")
	update_ui()
