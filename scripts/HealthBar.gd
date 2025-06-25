extends Node2D

@onready var bar = $Bar
@onready var background = $Background

var value: float = 1.0 : set = set_value

func set_value(v: float):
	value = clamp(v, 0.0, 1.0)
	_update_bar()

func _update_bar():
	if bar and background:
		bar.anchor_right = value

func _ready():
	_update_bar() 