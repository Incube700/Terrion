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

# Система территориального контроля
var territory_system: TerritorySystem = null

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

# Менеджер систем для безопасной инициализации
var system_manager = null

var battle_camera: Camera3D
var camera_speed = 20.0
var zoom_speed = 5.0
var is_mouse_dragging = false
var last_mouse_position = Vector2.ZERO

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
	init_territory_system()
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

func init_territory_system():
	# Создаем систему территорий
	territory_system = TerritorySystem.new()
	territory_system.battle_manager = self
	add_child(territory_system)
	print("🏰 Система территорий инициализирована")

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

# Заготовка: обработка победы/поражения
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

func unit_reached_base(unit):
	if unit.team == "player":
		enemy_base_hp -= unit.damage
		if enemy_base_hp <= 0:
			finish_battle("player")
	elif unit.team == "enemy":
		player_base_hp -= unit.damage
		if player_base_hp <= 0:
			finish_battle("enemy")

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
	
	# Правый клик для способностей
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if battle_started and ability_system:
			var pos = get_mouse_map_position(event.position)
			# Используем огненный шар как базовую способность
			if ability_system.can_use_ability("player", "fireball"):
				ability_system.use_ability("player", "fireball", pos)
				update_ui()
			else:
				print("❌ Нельзя использовать Fireball")

func get_mouse_map_position(screen_pos):
	var camera_to_use = battle_camera if battle_camera else get_viewport().get_camera_3d()
	if not camera_to_use:
		print("❌ Камера недоступна!")
		return Vector3.ZERO
		
	var from = camera_to_use.project_ray_origin(screen_pos)
	var to = from + camera_to_use.project_ray_normal(screen_pos) * 1000
	var space_state = get_viewport().get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	var result = space_state.intersect_ray(query)
	if result and result.has("position"):
		return result.position
	return Vector3.ZERO

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
	var spawners = get_tree().get_nodes_in_group("spawners")
	for s in spawners:
		if s.global_position.distance_to(pos) < 1.5:
			return false
	return true

func is_valid_enemy_build_position(pos: Vector3) -> bool:
	var map_width = 40.0
	var map_height = 60.0
	if pos.z > 0:  # Враг строит только на верхней половине (отрицательные Z)
		return false
	if pos.x < -map_width/2 or pos.x > map_width/2:
		return false
	if pos.z > 0 or pos.z < -map_height/2:
		return false
	var spawners = get_tree().get_nodes_in_group("spawners")
	for s in spawners:
		if s.global_position.distance_to(pos) < 2.0:
			return false
	return true

# Drag&drop: спавн юнита
func _on_spawn_unit_drag(unit_type, screen_pos):
	if not battle_started:
		print("❌ Битва не началась!")
		return
		
	var energy_cost = get_unit_cost(unit_type)
	var crystal_cost = get_unit_crystal_cost(unit_type)
	
	if player_energy < energy_cost or player_crystals < crystal_cost:
		print("❌ Недостаточно ресурсов для ", unit_type, " (нужно: ", energy_cost, " энергии, ", crystal_cost, " кристаллов)")
		return
		
	var pos = get_mouse_map_position(screen_pos)
	print("🎯 Drag&Drop ", unit_type, " на позицию: ", pos)
	
	if is_valid_unit_position(pos):
		spawn_unit_at_pos("player", pos, unit_type)
		print("✅ ", unit_type, " успешно создан на позиции ", pos)
		update_ui()
	else:
		print("❌ Нельзя разместить ", unit_type, " в позиции ", pos)

# Drag&drop: строительство здания
func _on_build_structure_drag(screen_pos):
	if not battle_started or player_energy < 60:
		return
	var pos = get_mouse_map_position(screen_pos)
	if is_valid_build_position(pos):
		place_spawner("player", "tower", pos)
		player_energy -= 60
		update_ui()

func is_valid_unit_position(pos: Vector3) -> bool:
	var map_width = 40.0
	var map_height = 60.0
	if pos.z < 0:  # Игрок размещает юнитов только на нижней половине (положительные Z)
		return false
	if pos.x < -map_width/2 or pos.x > map_width/2:
		return false
	if pos.z > map_height/2 or pos.z < 0:
		return false
	var spawners = get_tree().get_nodes_in_group("spawners")
	for s in spawners:
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
	if team == "player":
		unit.target_pos = Vector3(0, 0, -20)  # Игрок атакует вверх (к врагу)
		player_energy -= energy_cost
		player_crystals -= crystal_cost
	else:
		unit.target_pos = Vector3(0, 0, 20)   # Враг атакует вниз (к игроку)
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
	
	# Специальная настройка для collector_facility
	if spawner_type == "collector_facility":
		spawner.unit_type = "collector"
	
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

func init_enemy_ai():
	# Создаем продвинутый AI
	enemy_ai = EnemyAI.new(self, ai_difficulty)
	add_child(enemy_ai)
	
	# Таймер для принятия решений AI
	enemy_decision_timer = Timer.new()
	enemy_decision_timer.wait_time = 2.0  # Решение каждые 2 секунды
	enemy_decision_timer.autostart = false  # Запускаем только после старта боя
	enemy_decision_timer.timeout.connect(_on_enemy_ai_decision)
	add_child(enemy_decision_timer)
	
	# Таймер для спавна юнитов врага
	enemy_ai_timer = Timer.new()
	enemy_ai_timer.wait_time = 4.0  # Спавн каждые 4 секунды
	enemy_ai_timer.autostart = false  # Запускаем только после старта боя
	enemy_ai_timer.timeout.connect(_on_enemy_ai_spawn)
	add_child(enemy_ai_timer)

func _on_enemy_ai_decision():
	if not battle_started or not enemy_ai:
		return
	
	print("AI врага принимает стратегическое решение...")
	
	# Подсчитываем текущих юнитов врага для совместимости
	count_enemy_units()
	
	# Используем продвинутый AI для принятия решений
	var decision = enemy_ai.make_decision(enemy_decision_timer.wait_time)
	execute_advanced_ai_decision(decision)

func count_enemy_units():
	enemy_current_soldiers = 0
	enemy_current_tanks = 0
	enemy_current_drones = 0
	
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit.team == "enemy":
			match unit.unit_type:
				"soldier":
					enemy_current_soldiers += 1
				"tank":
					enemy_current_tanks += 1
				"drone":
					enemy_current_drones += 1
	
	print("Вражеские юниты: солдаты=", enemy_current_soldiers, 
		  ", танки=", enemy_current_tanks, 
		  ", дроны=", enemy_current_drones)

func make_enemy_decision() -> Dictionary:
	var decision = {
		"action": "none",
		"unit_type": "",
		"position": Vector3.ZERO
	}
	
	# Анализируем ситуацию на поле боя
	var _player_units = get_player_unit_count()  # Для будущего использования
	var enemy_spawners_count = get_enemy_spawner_count()
	
	# Если мало солдат - создаем солдат
	if enemy_current_soldiers < enemy_max_soldiers and enemy_energy >= get_unit_cost("soldier"):
		decision.action = "spawn"
		decision.unit_type = "soldier"
		return decision
	
	# Если есть солдаты, но мало танков - создаем танк
	if enemy_current_soldiers > 0 and enemy_current_tanks < enemy_max_tanks and enemy_energy >= get_unit_cost("tank"):
		decision.action = "spawn"
		decision.unit_type = "tank"
		return decision
	
	# Если есть танки, но мало дронов - создаем дрон
	if enemy_current_tanks > 0 and enemy_current_drones < enemy_max_drones and enemy_energy >= get_unit_cost("drone"):
		decision.action = "spawn"
		decision.unit_type = "drone"
		return decision
	
	# Если много ресурсов и мало спавнеров - строим спавнер
	if enemy_energy >= get_structure_cost("spawner") and enemy_spawners_count < 3:
		decision.action = "build"
		decision.unit_type = "spawner"
		return decision
	
	# Если очень много ресурсов - строим башню
	if enemy_energy >= get_structure_cost("tower"):
		decision.action = "build"
		decision.unit_type = "tower"
		return decision
	
	return decision

func get_player_unit_count() -> int:
	var count = 0
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit.team == "player":
			count += 1
	return count

func get_enemy_spawner_count() -> int:
	var count = 0
	var spawners = get_tree().get_nodes_in_group("spawners")
	for spawner in spawners:
		if spawner.team == "enemy":
			count += 1
	return count

func execute_enemy_decision(decision: Dictionary):
	match decision.action:
		"spawn":
			spawn_enemy_unit(decision.unit_type)
		"build":
			build_enemy_structure(decision.unit_type)
		"none":
			print("AI врага: нет действий")

func execute_advanced_ai_decision(decision: Dictionary):
	match decision.action:
		"spawn":
			spawn_enemy_unit_at_position(decision.unit_type, decision.position)
		"build":
			build_enemy_structure_at_position(decision.structure_type, decision.position)
		"ability":
			if ability_system and ability_system.can_use_ability("enemy", decision.ability_type):
				ability_system.use_ability("enemy", decision.ability_type, decision.position)
				update_ui()
				print("🤖 AI использует способность: ", decision.ability_type)
		"none":
			print("AI врага: нет стратегических действий (приоритет: ", decision.priority, ")")
	
	# Дополнительная логика AI для коллекторов
	ai_consider_collector_strategy()

func spawn_enemy_unit(unit_type: String):
	var cost = get_unit_cost(unit_type)
	if enemy_energy < cost:
		print("AI врага: недостаточно энергии для ", unit_type)
		return
	
	# Выбираем случайную позицию на вражеской стороне
	var spawn_pos = get_random_enemy_spawn_position()
	
	spawn_unit_at_pos("enemy", spawn_pos, unit_type)
	enemy_energy -= cost
	
	print("AI врага создал ", unit_type, " за ", cost, " энергии")
	
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)

func build_enemy_structure(structure_type: String):
	var cost = get_structure_cost(structure_type)
	if enemy_energy < cost:
		print("AI врага: недостаточно энергии для постройки ", structure_type)
		return
	
	# Выбираем позицию для постройки на вражеской стороне
	var build_pos = get_random_enemy_build_position()
	
	# Проверяем, можно ли строить в этой позиции
	if not is_valid_enemy_build_position(build_pos):
		print("AI врага: не может построить в позиции ", build_pos)
		return
	
	place_spawner("enemy", structure_type, build_pos)
	enemy_energy -= cost
	
	print("AI врага построил ", structure_type, " за ", cost, " энергии")
	
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)

func spawn_enemy_unit_at_position(unit_type: String, position: Vector3):
	var cost = get_unit_cost(unit_type)
	if enemy_energy < cost:
		print("AI врага: недостаточно энергии для ", unit_type)
		return
	
	spawn_unit_at_pos("enemy", position, unit_type)
	enemy_energy -= cost
	
	print("AI врага создал ", unit_type, " в позиции ", position, " за ", cost, " энергии")
	
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)

func build_enemy_structure_at_position(structure_type: String, position: Vector3):
	var cost = get_structure_cost(structure_type)
	if enemy_energy < cost:
		print("AI врага: недостаточно энергии для постройки ", structure_type)
		return
	
	# Проверяем, можно ли строить в этой позиции
	if not is_valid_enemy_build_position(position):
		print("AI врага: не может построить ", structure_type, " в позиции ", position)
		return
	
	place_spawner("enemy", structure_type, position)
	enemy_energy -= cost
	
	print("AI врага построил ", structure_type, " в позиции ", position, " за ", cost, " энергии")
	
	if battle_ui:
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy)

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
	if battle_started and ability_system and ability_system.can_use_ability("player", ability_name):
		ability_system.use_ability("player", ability_name, position)
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
		# Проверяем доступные территории
		if territory_system:
			var available_territories = territory_system.get_available_territories_for_team("enemy")
			if available_territories.size() > 0:
				# 30% шанс создать коллектора если есть свободные территории
				if randf() < 0.3:
					var spawn_pos = get_random_enemy_spawn_position()
					spawn_unit_at_pos("enemy", spawn_pos, "collector")
					enemy_energy -= get_unit_cost("collector")
					enemy_crystals -= get_unit_crystal_cost("collector")
					print("🤖 AI создал коллектора для захвата территорий")
					update_ui()
 
 
 
