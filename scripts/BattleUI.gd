extends CanvasLayer

signal start_battle
signal spawn_soldier
signal build_tower
signal spawn_unit_drag(unit_type, screen_pos)
signal build_structure_drag(screen_pos)

var drag_type = ""
var is_dragging = false
var drag_start_pos = Vector2.ZERO

@onready var spawner_panel = $SpawnerPanel

func _ready():
	$Panel/StartButton.pressed.connect(_on_start_button_pressed)
	$Panel/SpawnSoldierButton.pressed.connect(_on_spawn_soldier_button_pressed)
	$Panel/BuildTowerButton.pressed.connect(_on_build_tower_button_pressed)
	
	# Подключаем drag&drop для кнопок
	$Panel/SpawnSoldierButton.gui_input.connect(_on_spawn_button_input)
	$Panel/BuildTowerButton.gui_input.connect(_on_build_button_input)

	if spawner_panel:
		spawner_panel.spawner_drag_start.connect(_on_spawner_drag_start)
		spawner_panel.spawner_drag_end.connect(_on_spawner_drag_end)

func _on_start_button_pressed():
	start_battle.emit()

func _on_spawn_soldier_button_pressed():
	# Обычный клик - спавн в случайном месте
	spawn_soldier.emit()

func _on_build_tower_button_pressed():
	# Обычный клик - строительство в случайном месте
	build_tower.emit()

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
				spawn_unit_drag.emit("soldier", event.position)
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
				build_structure_drag.emit(event.position)
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

func _on_spawner_drag_start(spawner_type):
	# Можно добавить визуализацию призрака спавнера
	print("[UI] Начат drag спавнера: ", spawner_type)

func _on_spawner_drag_end(spawner_type, global_pos):
	print("[UI] Завершен drag спавнера: ", spawner_type, " в точке ", global_pos)
	# Пробрасываем в BattleManager (например, через сигнал или напрямую)
	if get_parent().has_method("on_spawner_drop"):
		get_parent().on_spawner_drop(spawner_type, global_pos)
 
 
