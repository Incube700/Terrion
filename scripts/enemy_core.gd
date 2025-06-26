extends Node2D

# Скрипт ядра врага — генерирует энергию
class_name EnemyCore

@onready var health_bar = $HealthBar/Bar
@onready var ai = $EnemyAI

# Параметры энергии
var energy: float = 0.0
var max_energy: float = 200.0
var energy_generation: float = 5.0

# Параметры здоровья
var health: int = 500
var max_health: int = 500

var flash_scene = preload("res://scenes/Flash.tscn")
var explosion_scene = preload("res://scenes/Explosion.tscn")

func _ready():
	print("[EnemyCore] _ready called")
	update_energy_display()
	add_to_group("enemy_buildings")
	update_health_bar()

func _process(delta):
	generate_energy(delta)

func generate_energy(delta):
	var energy_gain = energy_generation * delta
	energy = min(energy + energy_gain, max_energy)
	update_energy_display()

func spend_energy(amount: float) -> bool:
	if energy >= amount:
		energy -= amount
		update_energy_display()
		return true
	return false

func update_energy_display():
	# У врага нет energy_label, только health_bar
	pass

func update_health_bar():
	if health_bar:
		var health_percent = float(health) / float(max_health)
		health_bar.scale.x = health_percent

func take_damage(damage: int):
	health -= damage
	update_health_bar()
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
		# Game over - player wins
		var game_over = preload("res://scenes/GameOver.tscn").instantiate()
		get_tree().current_scene.add_child(game_over)
		queue_free()
	else:
		print("EnemyCore получило урон: ", damage, ". Здоровье: ", health) 
