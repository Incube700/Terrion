extends CanvasLayer

# Скрипт HUD - управление интерфейсом
class_name HUD

# Сигналы для кнопок
signal summon_soldier_requested
signal build_tower_requested
signal build_barracks_requested

@onready var summon_soldier_btn = $BottomPanel/HBoxContainer/SummonSoldierBtn
@onready var build_tower_btn = $BottomPanel/HBoxContainer/BuildTowerBtn
@onready var build_barracks_btn = $BottomPanel/HBoxContainer/BuildBarracksBtn

func _ready():
	# Подключаем сигналы кнопок
	summon_soldier_btn.pressed.connect(_on_summon_soldier_pressed)
	build_tower_btn.pressed.connect(_on_build_tower_pressed)
	build_barracks_btn.pressed.connect(_on_build_barracks_pressed)

func _on_summon_soldier_pressed():
	summon_soldier_requested.emit()

func _on_build_tower_pressed():
	build_tower_requested.emit()

func _on_build_barracks_pressed():
	build_barracks_requested.emit() 