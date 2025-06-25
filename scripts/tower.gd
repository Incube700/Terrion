extends StaticBody2D

# Скрипт башни - автоматически атакует врагов в радиусе
class_name Tower

@onready var detection_area = $DetectionArea
@onready var attack_timer = $AttackTimer
@onready var health_bar = $HealthBar

# Параметры башни
var attack_damage: int = 25
var attack_range: float = 200.0
var health: int = 200
var max_health: int = 200

# Текущая цель
var current_target: Node2D = null
var enemies_in_range: Array[Node2D] = []

var flash_scene = preload("res://scenes/Flash.tscn")
var explosion_scene = preload("res://scenes/Explosion.tscn")
var bullet_scene = preload("res://scenes/Bullet.tscn")

func _ready():
	# Подключаем сигналы области обнаружения
	detection_area.body_entered.connect(_on_enemy_entered)
	detection_area.body_exited.connect(_on_enemy_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	health_bar.value = float(health) / float(max_health)

func _process(delta):
	if not current_target or not is_instance_valid(current_target):
		_find_new_target()

func _on_enemy_entered(body):
	# Проверяем, что это враг (имеет скрипт Enemy)
	if body.has_method("take_damage") and body is Enemy and body not in enemies_in_range:
		enemies_in_range.append(body)
		if not current_target:
			current_target = body
			if attack_timer.is_stopped():
				attack_timer.start()

func _on_enemy_exited(body):
	if body in enemies_in_range:
		enemies_in_range.erase(body)
		if current_target == body:
			current_target = null
			attack_timer.stop()

func _find_new_target():
	if enemies_in_range.size() > 0:
		# Удаляем недействительные цели
		enemies_in_range = enemies_in_range.filter(func(enemy): return is_instance_valid(enemy))
		
		if enemies_in_range.size() > 0:
			current_target = enemies_in_range[0]
			if attack_timer.is_stopped():
				attack_timer.start()

func _on_attack_timer_timeout():
	if current_target and is_instance_valid(current_target):
		_attack_target()

func _attack_target():
	if current_target and is_instance_valid(current_target):
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position
		bullet.target = current_target
		bullet.damage = attack_damage
		get_tree().current_scene.add_child(bullet)
		print("Башня стреляет пулей!")

func take_damage(damage: int):
	health -= damage
	health_bar.value = float(health) / float(max_health)
	# Flash effect
	var flash = flash_scene.instantiate()
	add_child(flash)
	if health <= 0:
		# Explosion effect
		var explosion = explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position
		queue_free()
	else:
		print("Башня получила урон: ", damage, ". Здоровье: ", health) 