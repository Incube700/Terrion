extends Node2D

# Скрипт ядра - генерирует энергию
class_name Core

@onready var energy_label = $EnergyLabel

# Параметры энергии
var energy: int = 100
var max_energy: int = 200
var energy_generation_rate: float = 5.0  # энергии в секунду

# Параметры здоровья
var health: int = 500
var max_health: int = 500

func _ready():
	update_energy_display()
	# Добавляем в группу для поиска
	add_to_group("core")

func _process(delta):
	# Генерируем энергию со временем
	generate_energy(delta)

func generate_energy(delta):
	var energy_gain = energy_generation_rate * delta
	energy = min(energy + energy_gain, max_energy)
	update_energy_display()

func spend_energy(amount: int) -> bool:
	if energy >= amount:
		energy -= amount
		update_energy_display()
		return true
	return false

func update_energy_display():
	energy_label.text = "Energy: " + str(int(energy)) + "\nHealth: " + str(health)

func take_damage(damage: int):
	health -= damage
	update_energy_display()
	
	if health <= 0:
		print("Ядро уничтожено! Игра окончена!")
		get_tree().quit()
	else:
		print("Ядро получило урон: ", damage, ". Здоровье: ", health) 