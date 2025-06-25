extends StaticBody2D

# Скрипт барака - автоматически производит солдат
class_name Barracks

@onready var production_timer = $ProductionTimer

# Параметры барака
var health: int = 150
var max_health: int = 150
var production_cost: int = 10  # энергии на солдата

# Ссылка на основную сцену для доступа к Core
var main_scene: Main

func _ready():
	production_timer.timeout.connect(_on_production_timer_timeout)
	
	# Получаем ссылку на основную сцену
	main_scene = get_tree().get_first_node_in_group("main")
	if not main_scene:
		# Если не можем найти через группу, ищем через дерево
		var current = self
		while current and not current is Main:
			current = current.get_parent()
		main_scene = current

func _on_production_timer_timeout():
	_produce_soldier()

func _produce_soldier():
	if main_scene and main_scene.core.energy >= production_cost:
		main_scene.core.spend_energy(production_cost)
		
		# Создаем солдата рядом с бараком
		var soldier_scene = preload("res://scenes/soldier.tscn")
		var soldier = soldier_scene.instantiate()
		soldier.position = position + Vector2(60, 0)  # Справа от барака
		
		# Добавляем в контейнер юнитов
		var units_container = main_scene.get_node("UnitsContainer")
		if units_container:
			units_container.add_child(soldier)
			print("Барак произвел солдата!")
		else:
			soldier.queue_free()
	else:
		print("Недостаточно энергии для производства солдата")

func take_damage(damage: int):
	health -= damage
	if health <= 0:
		queue_free()
	else:
		print("Барак получил урон: ", damage, ". Здоровье: ", health) 