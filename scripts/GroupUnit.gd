extends Node3D
class_name GroupUnit

signal group_died
signal target_found(target)
signal target_lost

@export var team: String = "player"
@export var group_type: String = "group_unit"

var config = GROUP_UNIT_CONFIG.get(group_type, {})
var spawner: SpawnerBuilding = null

var hp: int = 100
var max_hp: int = 100
var current_target = null
var is_moving: bool = false
var is_attacking: bool = false

enum AIState {SEARCHING, MOVING, ATTACKING}
var current_ai_state: AIState = AIState.SEARCHING

func _ready():
	hp = config.get("hp", 100)
	max_hp = hp
	add_to_group("units")
	add_to_group("group_units")
	print("⚔️ Группа юнитов создана для команды ", team)

func search_for_target():
	var search_radius = 15.0
	var target = find_nearest_target(search_radius)
	if target:
		set_target(target)
		change_ai_state(AIState.MOVING)

func find_nearest_target(radius: float):
	var targets = []
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if unit.team != team and unit.global_position.distance_to(global_position) <= radius:
			targets.append(unit)
	
	if targets.size() > 0:
		var nearest_target = targets[0]
		var nearest_distance = global_position.distance_to(nearest_target.global_position)
		for target in targets:
			var distance = global_position.distance_to(target.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_target = target
		return nearest_target
	return null

func set_target(target):
	current_target = target
	target_found.emit(target)

func change_ai_state(new_state: AIState):
	current_ai_state = new_state

func take_damage(damage: int):
	hp -= damage
	if hp <= 0:
		die()

func die():
	print("💀 Группа юнитов ", team, " погибла")
	if spawner:
		group_died.emit(self)
	queue_free()

func destroy_group():
	die()
