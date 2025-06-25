extends CharacterBody2D

# Скрипт врага - движется к ядру и атакует его
class_name Enemy

@onready var health_bar = $HealthBar

# Параметры врага
var speed: float = 80.0
var attack_damage: int = 10
var attack_range: float = 60.0
var health: int = 50
var max_health: int = 50

# Цель - ядро
var target: Node2D = null

var flash_scene = preload("res://scenes/Flash.tscn")
var explosion_scene = preload("res://scenes/Explosion.tscn")

func _ready():
	update_health_display()
	_find_target()
	health_bar.value = float(health) / float(max_health)

func _physics_process(delta):
	if not target or not is_instance_valid(target):
		_find_target()
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
		velocity = Vector2.ZERO

func _find_target():
	# Ищем ядро через группу
	var core = get_tree().get_first_node_in_group("core")
	if core:
		target = core
		print("Враг нашёл ядро!", core)
	else:
		print("Враг не нашёл ядро! Будет искать снова...")

func _attack_target():
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
		print("Враг атакует ядро! Урон: ", attack_damage)

func take_damage(damage: int):
	health -= damage
	health_bar.value = float(health) / float(max_health)
	# Flash effect
	var flash = flash_scene.instantiate()
	add_child(flash)
	update_health_display()
	if health <= 0:
		# Explosion effect
		var explosion = explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position
		print("Враг уничтожен!")
		queue_free()
	else:
		print("Враг получил урон: ", damage, ". Здоровье: ", health)

func update_health_display():
	pass # HealthBar теперь отображает HP

# Новый метод для установки улучшенных характеристик
func set_enhanced_stats(health_boost: int, damage_boost: int):
	health += health_boost
	max_health += health_boost
	attack_damage += damage_boost
	update_health_display()
	
	# Изменяем цвет в зависимости от силы врага
	var sprite = get_node("EnemySprite")
	if sprite:
		var intensity = 0.5 + (health_boost / 100.0) * 0.5  # От 0.5 до 1.0
		sprite.color = Color(0.8 * intensity, 0.2, 0.2, 1) 