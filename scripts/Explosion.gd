extends Node2D

@onready var circle = $Circle

func _ready():
	var tween = create_tween()
	tween.tween_property(circle, "scale", Vector2(2,2), 0.4)
	tween.parallel().tween_property(circle, "modulate:a", 0.0, 0.4)
	tween.finished.connect(queue_free) 