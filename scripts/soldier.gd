extends CharacterBody2D

# Скрипт солдата - автоматически ищет и атакует врагов
class_name Soldier

@onready var detection_area = $DetectionArea
@onready var attack_timer = $AttackTimer

# Параметры солдата
var speed: float = 100.0
var attack_damage: int = 15
var attack_range: float = 50.0
var health: int = 100
var max_health: int = 100

# Текущая цель
var current_target: Node2D = null
var enemies_in_range: Array[Node2D] = []

func _ready():
	# Подключаем сигналы области обнаружения
	detection_area.body_entered.connect(_on_enemy_entered)
	detection_area.body_exited.connect(_on_enemy_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)

func _physics_process(delta):
	if current_target and is_instance_valid(current_target):
		# Двигаемся к цели
		var direction = (current_target.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		
		# Проверяем расстояние до цели
		var distance = global_position.distance_to(current_target.global_position)
		if distance <= attack_range:
			velocity = Vector2.ZERO
			if attack_timer.is_stopped():
				attack_timer.start()
	else:
		# Ищем новую цель
		_find_new_target()

func _on_enemy_entered(body):
	# Проверяем, что это враг (имеет скрипт Enemy)
	if body.has_method("take_damage") and body is Enemy and body not in enemies_in_range:
		enemies_in_range.append(body)
		if not current_target:
			current_target = body

func _on_enemy_exited(body):
	if body in enemies_in_range:
		enemies_in_range.erase(body)
		if current_target == body:
			current_target = null

func _find_new_target():
	if enemies_in_range.size() > 0:
		# Удаляем недействительные цели
		enemies_in_range = enemies_in_range.filter(func(enemy): return is_instance_valid(enemy))
		
		if enemies_in_range.size() > 0:
			current_target = enemies_in_range[0]

func _on_attack_timer_timeout():
	if current_target and is_instance_valid(current_target):
		_attack_target()

func _attack_target():
	if current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)
		print("Солдат атакует врага! Урон: ", attack_damage)

func take_damage(damage: int):
	health -= damage
	if health <= 0:
		queue_free()
	else:
		print("Солдат получил урон: ", damage, ". Здоровье: ", health) 