extends Node2D

# Скрипт ядра врага — генерирует энергию
class_name EnemyCore

@onready var energy_label = $EnergyLabel
@onready var health_bar = $HealthBar

# Параметры энергии
var energy: float = 100.0
var max_energy: float = 200.0
var energy_generation_rate: float = 5.0

# Параметры здоровья
var health: int = 500
var max_health: int = 500

var flash_scene = preload("res://scenes/Flash.tscn")
var explosion_scene = preload("res://scenes/Explosion.tscn")

func _ready():
	update_energy_display()
	add_to_group("enemy_core")
	health_bar.value = float(health) / float(max_health)

func _process(delta):
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
	energy_label.text = "Energy: " + str(round(energy * 10) / 10.0) + "\nHealth: " + str(health)

func take_damage(damage: int):
	health -= damage
	update_energy_display()
	health_bar.value = float(health) / float(max_health)
	# Flash effect
	var flash = flash_scene.instantiate()
	add_child(flash)
	if health <= 0:
		# Explosion effect
		var explosion = explosion_scene.instantiate()
		get_parent().add_child(explosion)
		explosion.global_position = global_position
		print("EnemyCore уничтожено! Победа игрока!")
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.show_game_over("Победа!")
	else:
		print("EnemyCore получило урон: ", damage, ". Здоровье: ", health) 