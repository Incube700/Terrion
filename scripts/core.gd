extends Node2D

# Скрипт ядра - генерирует энергию
class_name Core

@onready var energy_label = $EnergyLabel
@onready var health_bar = $HealthBar/Bar

# Параметры энергии
var energy: float = 100.0
var max_energy: float = 200.0
var energy_generation_rate: float = 5.0  # энергии в секунду

# Параметры здоровья
var health: int = 500
var max_health: int = 500

var flash_scene = preload("res://scenes/Flash.tscn")
var explosion_scene = preload("res://scenes/Explosion.tscn")

func _ready():
	print("[Core] _ready called")
	update_energy_display()
	# Добавляем в группу для поиска
	add_to_group("core")
	update_health_bar()

func _process(delta):
	# Генерируем энергию со временем
	generate_energy(delta)

func generate_energy(delta):
	var energy_gain = energy_generation_rate * delta
	energy = min(energy + energy_gain, max_energy)
	update_energy_display()
	print("[Core] Генерация энергии: ", energy, " (+", energy_gain, ")")

func spend_energy(amount: int) -> bool:
	if energy >= amount:
		energy -= amount
		update_energy_display()
		return true
	return false

func update_energy_display():
	energy_label.text = "Energy: %.1f" % energy + "\nHealth: " + str(health)

func update_health_bar():
	if health_bar:
		var health_percent = float(health) / float(max_health)
		health_bar.scale.x = health_percent

func take_damage(damage: int):
	health -= damage
	update_energy_display()
	update_health_bar()
	# Flash effect
	var flash = flash_scene.instantiate()
	add_child(flash)
	if health <= 0:
		# Explosion effect
		var explosion = explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.show_game_over("Поражение!")
	else:
		print("Ядро получило урон: ", damage, ". Здоровье: ", health) 
