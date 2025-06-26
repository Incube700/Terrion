extends Node2D

var speed: float = 600.0
var damage: int = 10
var target: Node2D = null
var trail_points = []
const TRAIL_LENGTH = 10

@onready var body = $Body

func _ready():
	# Настраиваем внешний вид пули
	body.size = Vector2(12, 4)
	body.position = Vector2(-6, -2)  # Центрируем
	body.color = Color(1, 0.7, 0.2)  # Желто-оранжевый цвет

func _process(delta):
	if not target or not is_instance_valid(target):
		queue_free()
		return
	var dir = (target.global_position - global_position).normalized()
	global_position += dir * speed * delta
	
	# Поворачиваем пулю в направлении движения
	rotation = dir.angle()
	
	# Обновляем след
	trail_points.push_front(global_position)
	if trail_points.size() > TRAIL_LENGTH:
		trail_points.pop_back()
	
	queue_redraw()  # Перерисовываем след
	
	if global_position.distance_to(target.global_position) < 10.0:
		if target.has_method("take_damage"):
			target.take_damage(damage)
			# Создаем эффект попадания
			var hit_effect = preload("res://scenes/Flash.tscn").instantiate()
			hit_effect.position = global_position
			get_tree().current_scene.add_child(hit_effect)
		queue_free()

func _draw():
	# Рисуем след пули
	if trail_points.size() < 2:
		return
		
	var prev_point = to_local(trail_points[0])
	for i in range(1, trail_points.size()):
		var point = to_local(trail_points[i])
		var alpha = 1.0 - float(i) / trail_points.size()
		draw_line(prev_point, point, Color(1, 0.7, 0.2, alpha), 2)
		prev_point = point 