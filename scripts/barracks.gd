extends StaticBase

# Скрипт барака - автоматически производит солдат
class_name Barracks

@onready var production_timer = $ProductionTimer

# Параметры барака
@export var production_cost: int = 10  # энергии на солдата
@export var production_cooldown: float = 5.0  # время между производством солдат

var last_production_time: float = 0.0

# Ссылка на основную сцену для доступа к Core
var main_scene: Main

func _ready():
	super()
	# Получаем ссылку на основную сцену
	main_scene = get_tree().get_first_node_in_group("main")
	if not main_scene:
		# Если не можем найти через группу, ищем через дерево
		var current = self
		while current and not current is Main:
			current = current.get_parent()
		main_scene = current

func _process(_delta):
	if Time.get_unix_time_from_system() - last_production_time >= production_cooldown:
		_produce_soldier()

func _produce_soldier():
	if main_scene and main_scene.core.energy >= production_cost:
		main_scene.core.spend_energy(production_cost)
		last_production_time = Time.get_unix_time_from_system()
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