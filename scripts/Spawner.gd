extends Node3D

@export var team: String = "player"
@export var lane_idx: int = 0
@export var unit_type: String = "soldier"
@export var spawner_type: String = "spawner" # 'spawner', 'tower', 'barracks'

@onready var spawn_timer: Timer = $SpawnTimer
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var mesh_barrack1: MeshInstance3D = $MeshBarrack1
@onready var mesh_barrack2: MeshInstance3D = $MeshBarrack2
@onready var mesh_barrack3: MeshInstance3D = $MeshBarrack3
@onready var mesh_barrack4: MeshInstance3D = $MeshBarrack4

func _ready():
	if spawner_type == "tower":
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.7
		cyl.bottom_radius = 0.7
		cyl.height = 2.0
		mesh_instance.mesh = cyl
		mesh_instance.scale = Vector3(1, 1.5, 1)
		mesh_instance.material_override = StandardMaterial3D.new()
		mesh_instance.material_override.albedo_color = Color(0.8, 0.8, 0.2, 1)
		mesh_barrack1.visible = false
		mesh_barrack2.visible = false
		mesh_barrack3.visible = false
		mesh_barrack4.visible = false
	elif spawner_type == "barracks":
		mesh_instance.visible = false
		mesh_barrack1.visible = true
		mesh_barrack2.visible = true
		mesh_barrack3.visible = true
		mesh_barrack4.visible = true
		for m in [mesh_barrack1, mesh_barrack2, mesh_barrack3, mesh_barrack4]:
			m.material_override = StandardMaterial3D.new()
			m.material_override.albedo_color = Color(0.5, 0.3, 0.1, 1)
		spawn_timer.wait_time = 5.0
	else:
		var box = BoxMesh.new()
		box.size = Vector3(1, 1, 1)
		mesh_instance.mesh = box
		mesh_instance.material_override = StandardMaterial3D.new()
		mesh_instance.material_override.albedo_color = Color(0.2, 0.8, 0.8, 1)
		mesh_barrack1.visible = false
		mesh_barrack2.visible = false
		mesh_barrack3.visible = false
		mesh_barrack4.visible = false

	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

func _on_spawn_timer_timeout():
	if spawner_type == "barracks":
		# Спавним солдата рядом с бараком
		var battle_manager = get_tree().get_root().get_node("Battle")
		if battle_manager:
			battle_manager.spawn_unit_at_pos(team, global_position + Vector3(0, 0, 1), "soldier")
	# TODO: добавить выбор типа юнита и расширение логики 
