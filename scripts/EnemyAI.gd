extends Node

var battle_manager: Node = null
var ai_timer: Timer
var decision_timer: Timer

func _init(_battle_manager):
	battle_manager = _battle_manager
	ai_timer = Timer.new()
	ai_timer.wait_time = 5.0
	ai_timer.autostart = true
	ai_timer.timeout.connect(_on_ai_spawn)
	add_child(ai_timer)

	decision_timer = Timer.new()
	decision_timer.wait_time = 3.0
	decision_timer.autostart = true
	decision_timer.timeout.connect(_on_ai_decision)
	add_child(decision_timer)

func _on_ai_spawn():
	if battle_manager and battle_manager.enemy_energy >= 20:
		battle_manager.spawn_unit_at_pos("enemy", Vector3(4, 0, 12), "soldier")
		battle_manager.enemy_energy -= 20
		battle_manager.update_hud()

func _on_ai_decision():
	# Здесь можно добавить более сложную логику принятия решений
	pass 
