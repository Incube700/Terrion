extends CharacterBody2D

# Скрипт врага - движется к ядру и атакует его
class_name Enemy

@onready var health_label = $HealthLabel

# Параметры врага
var speed: float = 80.0
var attack_damage: int = 10
var attack_range: float = 60.0
var health: int = 50
var max_health: int = 50

# Цель - ядро
var target: Node2D = null

func _ready():
	update_health_display()
	_find_target()

func _physics_process(delta):
	if target and is_instance_valid(target):
		# Двигаемся к цели
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		
		# Проверяем расстояние до цели
		var distance = global_position.distance_to(target.global_position)
		if distance <= attack_range:
			velocity = Vector2.ZERO
			_attack_target()
	else:
		_find_target()

func _find_target():
	# Ищем ядро через группу
	var core = get_tree().get_first_node_in_group("core")
	if core:
		target = core

func _attack_target():
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
		print("Враг атакует ядро! Урон: ", attack_damage)

func take_damage(damage: int):
	health -= damage
	update_health_display()
	
	if health <= 0:
		print("Враг уничтожен!")
		queue_free()
	else:
		print("Враг получил урон: ", damage, ". Здоровье: ", health)

func update_health_display():
	health_label.text = "HP: " + str(health) 