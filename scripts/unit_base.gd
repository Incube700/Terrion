extends CharacterBody2D
class_name UnitBase

# Общие параметры для всех юнитов
@export var max_health: int = 100
var health: int

# Сцены эффектов
@onready var flash_scene = preload("res://scenes/Flash.tscn")
@onready var explosion_scene = preload("res://scenes/Explosion.tscn")
@onready var health_bar = $HealthBar

func _ready():
	health = max_health
	if health_bar:
		health_bar.scale.x = 1.0

func take_damage(amount: int):
	health -= amount
	
	# Обновляем полоску здоровья
	if health_bar:
		health_bar.scale.x = float(health) / float(max_health)
	
	# Создаем эффект вспышки
	var flash = flash_scene.instantiate()
	add_child(flash)
	
	if health <= 0:
		# Создаем эффект взрыва
		var explosion = explosion_scene.instantiate()
		explosion.global_position = global_position
		get_tree().current_scene.add_child(explosion)
		
		# Удаляем юнит
		queue_free() 