extends Control

signal spawner_drag_start(spawner_type)
signal spawner_drag_end(spawner_type, global_pos)

var dragging_type = null

func _ready():
	$HBoxContainer/OrbitalDropButton.gui_input.connect(_on_orbital_drop_input)
	$HBoxContainer/EnergyGenButton.gui_input.connect(_on_energy_gen_input)
	$HBoxContainer/ShieldGenButton.gui_input.connect(_on_shield_gen_input)
	$HBoxContainer/TechLabButton.gui_input.connect(_on_tech_lab_input)
	$HBoxContainer/CollectorFacilityButton.gui_input.connect(_on_collector_facility_input)

func _on_orbital_drop_input(event):
	_handle_drag(event, "orbital_drop")

func _on_energy_gen_input(event):
	_handle_drag(event, "energy_generator")

func _on_shield_gen_input(event):
	_handle_drag(event, "shield_generator")

func _on_tech_lab_input(event):
	_handle_drag(event, "tech_lab")

func _on_collector_facility_input(event):
	_handle_drag(event, "collector_facility")

func _handle_drag(event, spawner_type):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging_type = spawner_type
			spawner_drag_start.emit(spawner_type)
		else:
			if dragging_type == spawner_type:
				spawner_drag_end.emit(spawner_type, get_global_mouse_position())
			dragging_type = null