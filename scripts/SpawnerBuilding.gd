extends Node3D
class_name SpawnerBuilding

# Система спавнера зданий для создания групп юнитов
# Каждые 5 секунд спавнит группу из 4 юнитов

signal group_spawned(group_unit)
signal building_destroyed

@export var team: String = "player"
@export var spawner_type: String = "spawner"

var config = SPAWNER_CONFIG.get(spawner_type, {})
var build_progress: float = 0.0
var is_built: bool = false
var active_groups: Array = []
var spawn_timer: Timer
var build_timer: Timer

# Визуальные компоненты
var building_mesh: MeshInstance3D
var progress_bar: ProgressBar
var spawn_effect: GPUParticles3D

func _ready():
	setup_timers()
	setup_visuals()
	start_building_process()

func setup_timers():
	# Таймер постройки
	build_timer = Timer.new()
	build_timer.wait_time = config.get("build_time", 3.0)
	build_timer.one_shot = true
	build_timer.timeout.connect(_on_building_complete)
	add_child(build_timer)
	
	# Таймер спавна групп
	spawn_timer = Timer.new()
	spawn_timer.wait_time = config.get("group_spawn_interval", 5.0)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

func setup_visuals():
	# Создаем меш здания
	building_mesh = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(3, 2, 3)
	building_mesh.mesh = box_mesh
	
	# Материал в зависимости от команды
	var material = StandardMaterial3D.new()
	if team == "player":
		material.albedo_color = Color(0.2, 0.6, 1.0, 0.8)
	else:
		material.albedo_color = Color(1.0, 0.2, 0.2, 0.8)
	building_mesh.set_surface_override_material(0, material)
	add_child(building_mesh)
	
	# Прогресс-бар постройки
	progress_bar = ProgressBar.new()
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.position = Vector2(50, 50)
	progress_bar.size = Vector2(200, 20)
	# Добавляем в UI слой
	get_tree().current_scene.get_node("UI").add_child(progress_bar)

func start_building_process():
	print("🏗️ Начинается постройка спавнера для команды ", team)
	build_timer.start()
	
	# Анимация постройки
	var tween = create_tween()
	tween.tween_method(update_build_progress, 0.0, 100.0, config.get("build_time", 3.0))

func update_build_progress(progress: float):
	build_progress = progress
	if progress_bar:
		progress_bar.value = progress

func _on_building_complete():
	is_built = true
	build_progress = 100.0
	if progress_bar:
		progress_bar.queue_free()
	
	print("✅ Спавнер построен для команды ", team)
	
	# Начинаем спавн групп
	spawn_timer.start()
	spawn_group()  # Первая группа сразу

func _on_spawn_timer_timeout():
	if is_built and can_spawn_group():
		spawn_group()

func can_spawn_group() -> bool:
	var max_groups = config.get("max_active_groups", 5)
	
	# Удаляем мертвые группы
	active_groups = active_groups.filter(func(group): return is_instance_valid(group))
	
	return active_groups.size() < max_groups

func spawn_group():
	if not is_built:
		return
	
	var group_size = config.get("group_size", 4)
	var spawn_position = global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	
	# Создаем группу юнитов
	var group_unit = preload("res://scripts/GroupUnit.gd").new()
	group_unit.team = team
	group_unit.spawner = self
	group_unit.global_position = spawn_position
	
	# Добавляем в сцену
	get_tree().current_scene.add_child(group_unit)
	active_groups.append(group_unit)
	
	# Подключаем сигнал смерти группы
	group_unit.group_died.connect(_on_group_died)
	
	# Эффект спавна
	create_spawn_effect(spawn_position)
	
	print("⚔️ Группа юнитов создана для команды ", team, " (всего групп: ", active_groups.size(), ")")
	group_spawned.emit(group_unit)

func _on_group_died(group_unit):
	active_groups.erase(group_unit)
	print("💀 Группа юнитов погибла для команды ", team, " (осталось групп: ", active_groups.size(), ")")

func create_spawn_effect(position: Vector3):
	# Создаем эффект спавна
	if spawn_effect:
		spawn_effect.global_position = position
		spawn_effect.emitting = true

func take_damage(damage: int):
	if not is_built:
		return
	
	# Логика получения урона
	config["hp"] -= damage
	
	if config["hp"] <= 0:
		destroy_building()

func destroy_building():
	print("💥 Спавнер уничтожен для команды ", team)
	
	# Останавливаем спавн
	spawn_timer.stop()
	
	# Уничтожаем все активные группы
	for group in active_groups:
		if is_instance_valid(group):
			group.destroy_group()
	
	# Эффект разрушения
	create_destruction_effect()
	
	building_destroyed.emit()
	queue_free()

func create_destruction_effect():
	# Создаем эффект разрушения здания
	var explosion = GPUParticles3D.new()
	explosion.global_position = global_position
	explosion.emitting = true
	get_tree().current_scene.add_child(explosion)
	
	# Удаляем эффект через 2 секунды
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(func(): explosion.queue_free())
	explosion.add_child(timer)
	timer.start()

# Функция для применения бонуса эффективности от кристалла пустоты
func apply_efficiency_bonus(multiplier: float):
	if spawn_timer:
		spawn_timer.wait_time = config.get("group_spawn_interval", 5.0) / multiplier
		print("💜 Эффективность спавнера увеличена в ", multiplier, " раз")

func get_spawner_info() -> Dictionary:
	return {
		"team": team,
		"type": spawner_type,
		"is_built": is_built,
		"active_groups": active_groups.size(),
		"max_groups": config.get("max_active_groups", 5),
		"hp": config.get("hp", 500)
	} 