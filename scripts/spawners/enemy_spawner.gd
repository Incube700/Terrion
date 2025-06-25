extends Node2D

# Скрипт спавнера врагов - создает волны врагов
class_name EnemySpawner

@onready var spawn_timer = $SpawnTimer
@onready var wave_timer = $WaveTimer
@onready var spawn_points = $SpawnPoints

# Параметры волн
var current_wave: int = 1
var enemies_per_wave: int = 3
var enemies_spawned: int = 0
var wave_in_progress: bool = false

# Ссылка на контейнер врагов
var enemies_container: Node2D

# Префаб врага
var enemy_scene = preload("res://scenes/enemy.tscn")

func _ready():
	# Добавляем в группу для связи с HUD
	add_to_group("enemy_spawner")
	
	# Подключаем сигналы таймеров
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	wave_timer.timeout.connect(_on_wave_timer_timeout)
	
	# Получаем ссылку на контейнер врагов
	var main = get_tree().get_first_node_in_group("main")
	if main:
		enemies_container = main.get_node("EnemiesContainer")
	
	# Начинаем первую волну
	start_wave()

func start_wave():
	wave_in_progress = true
	enemies_spawned = 0
	print("Волна ", current_wave, " началась!")
	
	# Настраиваем количество врагов в зависимости от волны
	enemies_per_wave = 3 + (current_wave - 1) * 2
	
	# Запускаем спавн врагов
	spawn_timer.start()

func _on_spawn_timer_timeout():
	if enemies_spawned < enemies_per_wave:
		spawn_enemy()
		enemies_spawned += 1
		
		# Если это не последний враг в волне, продолжаем спавн
		if enemies_spawned < enemies_per_wave:
			spawn_timer.start()
		else:
			# Волна завершена
			wave_in_progress = false
			print("Волна ", current_wave, " завершена!")
			
			# Ждем перед следующей волной
			wave_timer.start()

func _on_wave_timer_timeout():
	# Начинаем следующую волну
	current_wave += 1
	start_wave()

func spawn_enemy():
	if not enemies_container:
		return
	
	# Выбираем случайную точку спавна
	var spawn_points_array = spawn_points.get_children()
	if spawn_points_array.size() == 0:
		return
	
	var random_spawn_point = spawn_points_array[randi() % spawn_points_array.size()]
	
	# Создаем врага
	var enemy = enemy_scene.instantiate()
	enemy.position = random_spawn_point.global_position
	
	# Увеличиваем характеристики врага с каждой волной
	var health_boost = (current_wave - 1) * 10
	var damage_boost = (current_wave - 1) * 2
	
	if enemy.has_method("set_enhanced_stats"):
		enemy.set_enhanced_stats(health_boost, damage_boost)
	
	enemies_container.add_child(enemy)
	print("Враг создан в волне ", current_wave, "! HP: ", enemy.health + health_boost)

func get_current_wave() -> int:
	return current_wave

func is_wave_in_progress() -> bool:
	return wave_in_progress 