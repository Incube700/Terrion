extends StaticBase

# Tower script - automatically attacks enemies in range
class_name Tower

# Параметры башни
@export var damage: int = 25
@export var attack_range: float = 200.0
@export var attack_cooldown: float = 2.0

var last_attack_time: float = 0.0
var target = null

@onready var detection_area = $DetectionArea
@onready var attack_timer = $AttackTimer

var enemies_in_range: Array[Node2D] = []
var bullet_scene = preload("res://scenes/Bullet.tscn")

func _ready():
	super()
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	# Add to player buildings group
	add_to_group("player_buildings")

func _process(_delta):
	if target and is_instance_valid(target):
		var distance = global_position.distance_to(target.global_position)
		if distance <= attack_range:
			if Time.get_unix_time_from_system() - last_attack_time >= attack_cooldown:
				attack()
	else:
		find_new_target()

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
		# Create bullet effect
		var bullet = preload("res://scenes/Bullet.tscn").instantiate()
		bullet.global_position = global_position
		bullet.target = target
		bullet.damage = damage
		get_tree().current_scene.add_child(bullet)
		print("Tower attacks! Damage: ", damage) 