class_name Drone
extends UnitBase

# Скрипт дрона - быстрый, летающий юнит

# Параметры дрона
@export var speed: float = 160.0
@export var damage: int = 10
@export var attack_range: float = 70.0
@export var attack_cooldown: float = 0.7

var last_attack_time: float = 0.0
var target = null

@onready var detection_area = $DetectionArea
@onready var attack_timer = $AttackTimer
@onready var navigation = get_tree().get_root().get_node_or_null("Main/Navigation2D")

var enemies_in_range: Array[Node2D] = []

func _ready():
	super()
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_to_group("player_units")

func _physics_process(_delta):
	if target and is_instance_valid(target):
		var direction = (target.global_position - global_position).normalized()
		var distance = global_position.distance_to(target.global_position)
		if navigation:
			var path = navigation.get_simple_path(global_position, target.global_position)
			if path.size() > 1:
				direction = (path[1] - global_position).normalized()
		if distance > attack_range:
			velocity = direction * speed
		else:
			velocity = Vector2.ZERO
			if Time.get_unix_time_from_system() - last_attack_time >= attack_cooldown:
				attack()
	else:
		velocity = Vector2.ZERO
		find_new_target()
	move_and_slide()

func _on_detection_area_body_entered(body):
	if not target and (body.is_in_group("enemy_buildings") or body.is_in_group("enemies")):
		target = body

func _on_detection_area_body_exited(body):
	if target == body:
		target = null

func find_new_target():
	var enemies = get_tree().get_nodes_in_group("enemy_buildings") + get_tree().get_nodes_in_group("enemies")
	var closest_distance = INF
	var closest_enemy = null
	for enemy in enemies:
		if is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	target = closest_enemy

func _on_attack_timer_timeout():
	if target and is_instance_valid(target):
		attack()

func attack():
	if target and target.has_method("take_damage"):
		target.take_damage(damage)
		last_attack_time = Time.get_unix_time_from_system()
		print("Дрон атакует врага! Урон: ", damage)

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
		print("Дрон получил урон: ", damage, ". Здоровье: ", health) 
