extends CanvasLayer

signal start_battle
signal spawn_soldier
signal build_tower
signal spawn_unit_drag(unit_type, screen_pos)
signal build_structure_drag(screen_pos)

var drag_type = ""
var is_dragging = false
var drag_start_pos = Vector2.ZERO

func _ready():
	$Panel/StartButton.pressed.connect(_on_start_button_pressed)
	$Panel/SpawnSoldierButton.pressed.connect(_on_spawn_soldier_button_pressed)
	$Panel/BuildTowerButton.pressed.connect(_on_build_tower_button_pressed)
	
	# Подключаем drag&drop для кнопок
	$Panel/SpawnSoldierButton.gui_input.connect(_on_spawn_button_input)
	$Panel/BuildTowerButton.gui_input.connect(_on_build_button_input)

func _on_start_button_pressed():
	emit_signal("start_battle")

func _on_spawn_soldier_button_pressed():
	# Обычный клик - спавн в случайном месте
	emit_signal("spawn_soldier")

func _on_build_tower_button_pressed():
	# Обычный клик - строительство в случайном месте
	emit_signal("build_tower")

func _on_spawn_button_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Начало drag
			drag_type = "soldier"
			is_dragging = true
			drag_start_pos = event.position
		else:
			# Конец drag
			if is_dragging and drag_type == "soldier":
				emit_signal("spawn_unit_drag", "soldier", event.position)
			is_dragging = false
			drag_type = ""

func _on_build_button_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Начало drag
			drag_type = "tower"
			is_dragging = true
			drag_start_pos = event.position
		else:
			# Конец drag
			if is_dragging and drag_type == "tower":
				emit_signal("build_structure_drag", event.position)
			is_dragging = false
			drag_type = ""

func update_info(player_hp, player_energy, enemy_hp, enemy_energy):
	$PlayerHUD.text = "Player HP: %d | Energy: %d" % [player_hp, player_energy]
	$EnemyHUD.text = "Enemy HP: %d | Energy: %d" % [enemy_hp, enemy_energy]

func _input(event):
	if is_dragging:
		if event is InputEventMouseMotion:
			# Можно добавить визуальную обратную связь при drag
			pass 
 
