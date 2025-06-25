extends CanvasLayer

@onready var label = $Panel/Label
@onready var restart_button = $Panel/RestartButton

func _ready():
	restart_button.pressed.connect(_on_restart_pressed)

func set_message(msg: String):
	label.text = msg

func _on_restart_pressed():
	get_tree().reload_current_scene() 