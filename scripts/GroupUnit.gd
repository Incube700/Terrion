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

enum AIState {IDLE, SEARCHING, MOVING, ATTACKING, RETREATING}
var current_ai_state: AIState = AIState.IDLE

func _ready():
	hp = config.get("hp", 100)
	max_hp = hp
	add_to_group("units")
	add_to_group("group_units")
	print("⚔️ Группа юнитов создана для команды ", team)

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
