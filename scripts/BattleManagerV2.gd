class_name BattleManagerV2
extends Node

# BattleManagerV2 — улучшенный менеджер битв с модульной архитектурой
# Использует EventBus для слабой связанности систем

# Основные игровые переменные
var player_energy = 100
var enemy_energy = 100
var player_crystals = 0
var enemy_crystals = 0
var energy_gain_per_tick = 10
var energy_tick_time = 1.0

var player_base_hp = 100
var enemy_base_hp = 100

var battle_started = false
var battle_ui = null

# Системы игры
var systems: Dictionary = {}
var system_load_order: Array[String] = [
	"TerritorySystem",
	"AbilitySystem", 
	"RaceSystem",
	"EffectSystem",
	"AudioSystem",
	"NotificationSystem",
	"StatisticsSystem"
]

# Сцены
var unit_scene = preload("res://scenes/Unit.tscn")
var spawner_scene = preload("res://scenes/Spawner.tscn")

signal battle_finished(winner)

func _ready():
	print("🚀 BattleManagerV2 инициализация...")
	
	# Инициализируем EventBus
	init_event_bus()
	
	# Подключаем UI
	setup_ui()
	
	# Создаем поле боя
	create_battlefield()
	create_command_centers()
	
	# Инициализируем системы
	init_all_systems()
	
	# Настройка таймеров
	init_energy_timer()
	
	print("⚡ BattleManagerV2 готов!")

func init_event_bus():
	# (documentation comment)
	if not has_node("/root/EventBus"):
		var event_bus = preload("res://scripts/EventBus.gd").new()
		event_bus.name = "EventBus"
		get_tree().root.add_child(event_bus)
		print("📡 EventBus создан")
	
	# Подключаемся к событиям
	var event_bus = get_node("/root/EventBus")
	event_bus.battle_started.connect(_on_battle_started_event)
	event_bus.battle_ended.connect(_on_battle_ended_event)
	event_bus.unit_spawned.connect(_on_unit_spawned_event)

func init_all_systems():
	# (documentation comment)
	print("🔧 Инициализация игровых систем...")
	
	for system_name in system_load_order:
		init_system(system_name)
	
	print("✅ Все системы инициализированы")

func init_system(system_name: String) -> bool:
	# (documentation comment)
	var system_instance = null
	
	match system_name:
		"TerritorySystem":
			system_instance = TerritorySystem.new()
		"AbilitySystem":
			system_instance = AbilitySystem.new()
		"RaceSystem":
			system_instance = RaceSystem.new()
		"EffectSystem":
			system_instance = EffectSystem.new()
		"AudioSystem":
			system_instance = AudioSystem.new()
		"NotificationSystem":
			system_instance = NotificationSystem.new()
		"StatisticsSystem":
			system_instance = StatisticsSystem.new()
		_:
			print("⚠️ Неизвестная система: ", system_name)
			return false
	
	if system_instance:
		system_instance.name = system_name
		system_instance.battle_manager = self
		add_child(system_instance)
		systems[system_name] = system_instance
		print("✅ Система ", system_name, " инициализирована")
		return true
	else:
		print("❌ Ошибка создания системы ", system_name)
		return false
	
	return false

func get_system(system_name: String):
	# (documentation comment)
	return systems.get(system_name, null)

func is_system_available(system_name: String) -> bool:
	# (documentation comment)
	var system = get_system(system_name)
	return system != null and system.has_method("is_initialized") and system.is_initialized

func setup_ui():
	# (documentation comment)
	battle_ui = get_node_or_null("BattleUI")
	if battle_ui:
		print("✅ Интерфейс подключен")
		# Подключаем сигналы UI
		if battle_ui.has_signal("start_battle"):
			battle_ui.start_battle.connect(_on_start_battle)
		if battle_ui.has_signal("spawn_soldier"):
			battle_ui.spawn_soldier.connect(_on_spawn_soldier)
		# ... другие подключения
	else:
		print("⚠️ Интерфейс не найден")

func create_battlefield():
	# (documentation comment)
	# Основное поле
	var field = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(30, 50)
	field.mesh = plane
	field.position = Vector3(0, 0, 0)
	
	var field_mat = StandardMaterial3D.new()
	field_mat.albedo_color = Color(0.2, 0.7, 0.2, 1.0)
	field.set_surface_override_material(0, field_mat)
	add_child(field)
	
	print("🌍 Поле боя создано")

func create_command_centers():
	# (documentation comment)
	# Центр игрока (синий)
	var player_core = create_core(Vector3(0, 1.5, 20), Color(0.2, 0.6, 1, 1), "PlayerCore")
	add_child(player_core)
	
	# Центр врага (красный)  
	var enemy_core = create_core(Vector3(0, 1.5, -20), Color(1, 0.2, 0.2, 1), "EnemyCore")
	add_child(enemy_core)
	
	print("🏰 Командные центры созданы")

func create_core(position: Vector3, color: Color, core_name: String) -> MeshInstance3D:
	# (documentation comment)
	var core = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3.0
	core.mesh = sphere
	core.position = position
	core.name = core_name
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.5
	core.set_surface_override_material(0, mat)
	
	return core

func init_energy_timer():
	# (documentation comment)
	var energy_timer = Timer.new()
	energy_timer.wait_time = energy_tick_time
	energy_timer.autostart = true
	energy_timer.timeout.connect(_on_energy_timer)
	add_child(energy_timer)

func _on_start_battle():
	# (documentation comment)
	if battle_started:
		return
	
	print("🚀 Битва началась!")
	battle_started = true
	
	# Отправляем событие через EventBus
	var event_bus = get_node("/root/EventBus")
	if event_bus:
		event_bus.emit_battle_started()
	
	# Скрываем кнопку старта
	if battle_ui and battle_ui.has_node("Panel/MainButtonContainer/StartButton"):
		battle_ui.get_node("Panel/MainButtonContainer/StartButton").hide()

func _on_energy_timer():
	# (documentation comment)
	if not battle_started:
		return
	
	player_energy += energy_gain_per_tick
	enemy_energy += energy_gain_per_tick
	
	update_ui()

func update_ui():
	# (documentation comment)
	if battle_ui and battle_ui.has_method("update_info"):
		battle_ui.update_info(player_base_hp, player_energy, enemy_base_hp, enemy_energy, player_crystals, enemy_crystals)

func spawn_unit_at_pos(team: String, pos: Vector3, unit_type: String):
	# (documentation comment)
	if not battle_started:
		return
	
	var unit = unit_scene.instantiate()
	add_child(unit)
	unit.team = team
	unit.unit_type = unit_type
	unit.global_position = pos
	unit.battle_manager = self
	unit.add_to_group("units")
	
	# Устанавливаем цель
	if team == "player":
		unit.target_pos = Vector3(0, 0, -20)
	else:
		unit.target_pos = Vector3(0, 0, 20)
	
	# Отправляем событие
	var event_bus = get_node("/root/EventBus")
	if event_bus:
		event_bus.emit_unit_spawned(team, unit_type, pos)
	
	print("✅ Юнит создан: ", team, " ", unit_type)

func _on_spawn_soldier():
	# (documentation comment)
	if battle_started and player_energy >= 25:
		var spawn_pos = Vector3(randf_range(-4.0, 4.0), 0, 12.0)
		spawn_unit_at_pos("player", spawn_pos, "soldier")
		player_energy -= 25
		update_ui()

# Обработчики событий EventBus
func _on_battle_started_event():
	# (documentation comment)
	print("📡 Получено событие: битва началась")

func _on_battle_ended_event(winner: String):
	# (documentation comment)
	print("📡 Получено событие: битва завершена, победитель: ", winner)
	battle_finished.emit(winner)

func _on_unit_spawned_event(team: String, unit_type: String, position: Vector3):
	# (documentation comment)
	print("📡 Получено событие: юнит создан - ", team, " ", unit_type)

# Получение статистики систем
func get_systems_status() -> Dictionary:
	# (documentation comment)
	var status = {}
	for system_name in systems:
		var system = systems[system_name]
		if system and system.has_method("get_system_status"):
			status[system_name] = system.get_system_status()
		else:
			status[system_name] = {"error": "Система недоступна"}
	return status

func cleanup_all_systems():
	# (documentation comment)
	for system_name in systems:
		var system = systems[system_name]
		if system and system.has_method("cleanup_system"):
			system.cleanup_system()
	systems.clear()
	print("🧹 Все системы очищены") 