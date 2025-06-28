extends CharacterBody3D

@export var team: String = "player"
@export var speed: float = 100.0
@export var health: int = 100
@export var damage: int = 20
@export var target_pos: Vector3
var battle_manager = null

var attack_range: float = 3.0
var attack_cooldown: float = 1.0
var attack_timer: float = 0.0
var target: Node = null

@onready var attack_area: Area3D = $AttackArea

func _ready():
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)
	update_health_display()
	# Цвет юнита по команде
	var mesh = $MeshInstance3D
	if team == "player":
		mesh.material_override = StandardMaterial3D.new()
		mesh.material_override.albedo_color = Color(0.2, 0.6, 1, 1)
	else:
		mesh.material_override = StandardMaterial3D.new()
		mesh.material_override.albedo_color = Color(1, 0.2, 0.2, 1)

func _physics_process(delta):
	if health <= 0:
		queue_free()
		return
	if target_pos and global_position.distance_to(target_pos) < 1.5:
		if battle_manager:
			battle_manager.unit_reached_base(self)
		queue_free()
		return
	attack_timer += delta
	if target and is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist > attack_range:
			move_towards_target(delta)
		else:
			if attack_timer > attack_cooldown:
				attack()
				attack_timer = 0.0
	else:
		move_towards_target(delta)
		find_new_target()
	# TODO: если дошёл до конца линии — нанести урон базе противника

func move_towards_target(delta):
	if target_pos:
		var dir = (target_pos - global_position).normalized()
		velocity = dir * speed
		move_and_slide()

func _on_attack_area_body_entered(body):
	if body != self and body.has_method("take_damage") and body.team != team:
		target = body

func _on_attack_area_body_exited(body):
	if target == body:
		target = null

func find_new_target():
	# TODO: искать ближайшего врага в зоне
	pass

func attack():
	if target and target.has_method("take_damage"):
		target.take_damage(damage)

func take_damage(amount: int):
	health -= amount
	if health <= 0:
		queue_free() 
