extends CanvasLayer

# Скрипт HUD - управление интерфейсом
class_name HUD

# Сигналы для кнопок
signal summon_soldier_requested
signal summon_tank_requested
signal summon_drone_requested
signal build_tower_requested
signal build_barracks_requested

@onready var summon_soldier_btn = $BottomPanel/HBoxContainer/SummonSoldierBtn
@onready var summon_tank_btn = $BottomPanel/HBoxContainer/SummonTankBtn
@onready var summon_drone_btn = $BottomPanel/HBoxContainer/SummonDroneBtn
@onready var build_tower_btn = $BottomPanel/HBoxContainer/BuildTowerBtn
@onready var build_barracks_btn = $BottomPanel/HBoxContainer/BuildBarracksBtn
@onready var wave_label = $TopPanel/WaveLabel

func _ready():
	# Подключаем сигналы кнопок
	summon_soldier_btn.pressed.connect(_on_summon_soldier_pressed)
	summon_tank_btn.pressed.connect(_on_summon_tank_pressed)
	summon_drone_btn.pressed.connect(_on_summon_drone_pressed)
	build_tower_btn.pressed.connect(_on_build_tower_pressed)
	build_barracks_btn.pressed.connect(_on_build_barracks_pressed)
	
	# Обновляем индикатор волны каждую секунду
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_wave_display)
	add_child(timer)
	timer.start()

func _on_summon_soldier_pressed():
	summon_soldier_requested.emit()

func _on_summon_tank_pressed():
	summon_tank_requested.emit()

func _on_summon_drone_pressed():
	summon_drone_requested.emit()

func _on_build_tower_pressed():
	build_tower_requested.emit()

func _on_build_barracks_pressed():
	build_barracks_requested.emit()

func _update_wave_display():
	# Получаем информацию о текущей волне
	var spawner = get_tree().get_first_node_in_group("enemy_spawner")
	if spawner and spawner.has_method("get_current_wave"):
		var current_wave = spawner.get_current_wave()
		var wave_in_progress = spawner.is_wave_in_progress()
		
		var status = "Волна " + str(current_wave)
		if wave_in_progress:
			status += " (в процессе)"
		else:
			status += " (ожидание)"
		
		wave_label.text = status 