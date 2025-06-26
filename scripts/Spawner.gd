extends Node3D

@export var team: String = "player"
@export var lane_idx: int = 0
@export var unit_type: String = "soldier"

@onready var spawn_timer: Timer = $SpawnTimer

func _ready():
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

func _on_spawn_timer_timeout():
	var battle_manager = get_tree().get_root().get_node("Battle")
	if battle_manager:
		battle_manager.spawn_unit(team, lane_idx)
	# TODO: добавить выбор типа юнита и расширение логики 
