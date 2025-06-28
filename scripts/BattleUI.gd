extends CanvasLayer

signal start_battle
signal spawn_unit(unit_type, pos)
signal build_structure(pos)

@onready var player_info = $UI/TopPanel/PlayerInfo
@onready var enemy_info = $UI/TopPanel/EnemyInfo
@onready var start_button = $UI/RightPanel/StartButton
@onready var soldier_button = $UI/BottomPanel/SoldierButton
@onready var tank_button = $UI/BottomPanel/TankButton
@onready var drone_button = $UI/BottomPanel/DroneButton
@onready var tower_button = $UI/BottomPanel/TowerButton
@onready var barracks_button = $UI/BottomPanel/BarracksButton

var drag_type = null
var drag_preview = null

func _ready():
	start_button.pressed.connect(_on_start_pressed)
	soldier_button.gui_input.connect(_on_soldier_button_input)
	tank_button.gui_input.connect(_on_tank_button_input)
	drone_button.gui_input.connect(_on_drone_button_input)
	tower_button.gui_input.connect(_on_tower_button_input)
	barracks_button.gui_input.connect(_on_barracks_button_input)

func _on_start_pressed():
	emit_signal("start_battle")
	start_button.hide()

func _on_soldier_button_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		drag_type = "soldier"
		create_drag_preview("soldier")
	elif event is InputEventMouseButton and not event.pressed and drag_type == "soldier":
		finish_drag()

func _on_tank_button_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		drag_type = "tank"
		create_drag_preview("tank")
	elif event is InputEventMouseButton and not event.pressed and drag_type == "tank":
		finish_drag()

func _on_drone_button_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		drag_type = "drone"
		create_drag_preview("drone")
	elif event is InputEventMouseButton and not event.pressed and drag_type == "drone":
		finish_drag()

func _on_tower_button_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		drag_type = "tower"
		create_drag_preview("tower")
	elif event is InputEventMouseButton and not event.pressed and drag_type == "tower":
		finish_drag()

func _on_barracks_button_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		drag_type = "barracks"
		create_drag_preview("barracks")
	elif event is InputEventMouseButton and not event.pressed and drag_type == "barracks":
		finish_drag()

func create_drag_preview(type):
	if drag_preview:
		drag_preview.queue_free()
	# Можно добавить визуализацию preview (например, ColorRect или иконку)
	drag_preview = ColorRect.new()
	if type == "soldier":
		drag_preview.color = Color(0.5, 1, 0.5, 0.5)
	elif type == "tank":
		drag_preview.color = Color(0.2, 0.7, 0.2, 0.5)
	elif type == "drone":
		drag_preview.color = Color(0.5, 0.8, 1, 0.5)
	elif type == "tower":
		drag_preview.color = Color(0.8, 0.8, 0.2, 0.5)
	elif type == "barracks":
		drag_preview.color = Color(0.5, 0.3, 0.1, 0.5)
	drag_preview.size = Vector2(64, 64)
	add_child(drag_preview)
	set_process(true)

func _process(delta):
	if drag_preview:
		drag_preview.position = get_viewport().get_mouse_position() - drag_preview.size / 2

func finish_drag():
	if drag_preview:
		var pos = get_viewport().get_mouse_position()
		if drag_type in ["soldier", "tank", "drone"]:
			emit_signal("spawn_unit", drag_type, pos)
		elif drag_type == "tower" or drag_type == "barracks":
			emit_signal("build_structure", pos)
		drag_preview.queue_free()
		drag_preview = null
		drag_type = null
	set_process(false)

func update_info(player_hp, player_energy, enemy_hp, enemy_energy):
	if player_info:
		player_info.text = "Player: %d HP | %d Energy" % [player_hp, player_energy]
	if enemy_info:
		enemy_info.text = "Enemy: %d HP | %d Energy" % [enemy_hp, enemy_energy] 
