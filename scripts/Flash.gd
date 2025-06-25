extends Node2D

@onready var rect = $ColorRect

func _ready():
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, 0.2)
	tween.finished.connect(queue_free) 