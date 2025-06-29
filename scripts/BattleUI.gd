extends CanvasLayer

signal start_battle
signal spawn_soldier
signal build_tower

func _ready():
	$Panel/StartButton.pressed.connect(_on_start_button_pressed)
	$Panel/SpawnSoldierButton.pressed.connect(_on_spawn_soldier_button_pressed)
	$Panel/BuildTowerButton.pressed.connect(_on_build_tower_button_pressed)

func _on_start_button_pressed():
	emit_signal("start_battle")

func _on_spawn_soldier_button_pressed():
	emit_signal("spawn_soldier")

func _on_build_tower_button_pressed():
	emit_signal("build_tower") 
 