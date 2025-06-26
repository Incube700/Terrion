extends Node2D

@onready var color_rect = $ColorRect

func _ready():
	# Начальный размер
	color_rect.size = Vector2(64, 64)
	color_rect.position = Vector2(-32, -32)  # Центрируем
	color_rect.color = Color(1, 1, 1, 0.8)  # Яркая вспышка
	
	# Создаем анимацию
	var tween = create_tween()
	# Увеличиваем размер и уменьшаем прозрачность
	tween.tween_property(color_rect, "scale", Vector2(2, 2), 0.3)
	tween.parallel().tween_property(color_rect, "modulate:a", 0.0, 0.3)
	# Удаляем эффект после завершения
	tween.finished.connect(queue_free) 