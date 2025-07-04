# mobile_camera_controller.gd - Система управления камерой для мобильных устройств
# Обеспечивает удобное управление камерой на сенсорных экранах

class_name MobileCameraController
extends Node

signal camera_moved(new_position: Vector3)
signal zoom_changed(new_zoom: float)

# Ссылка на камеру
var camera: Camera3D
var battle_manager: Node

# Настройки сенсорного управления
var mobile_settings = {
	"zoom_sensitivity": 1.5,      # Чувствительность зума
	"pan_sensitivity": 1.2,       # Чувствительность панорамирования
	"edge_scrolling": false,      # Отключено для мобильных
	"auto_follow": true,          # Автоследование за действиями
	"smart_zoom": true,           # Умное приближение к важным событиям
	"gesture_controls": true,     # Жестовое управление
	"vibration_feedback": true    # Тактильная обратная связь
}

# Состояние касаний
var touch_points = {}
var last_pinch_distance = 0.0
var is_panning = false
var is_pinching = false
var pan_start_position = Vector2.ZERO
var camera_start_position = Vector3.ZERO

# Границы камеры (обновляются в зависимости от размера карты)
var camera_bounds = {
	"min_x": -35.0,
	"max_x": 35.0,
	"min_z": -45.0,
	"max_z": 45.0,
	"min_y": 25.0,
	"max_y": 120.0
}

# Автоматическое следование
var auto_follow_target: Node3D = null
var auto_follow_duration = 2.0
var auto_follow_timer = 0.0

func _ready():
	print("📱 Мобильная система управления камерой инициализирована")
	
	# Определяем платформу
	if OS.has_feature("mobile"):
		mobile_settings.gesture_controls = true
		print("📱 Обнаружена мобильная платформа - активированы жесты")
	else:
		mobile_settings.gesture_controls = false
		print("🖥️ Обнаружена десктопная платформа - жесты отключены")

func setup_camera(cam: Camera3D, manager: Node):
	camera = cam
	battle_manager = manager
	print("📷 Камера подключена к мобильному контроллеру")

func _input(event):
	if not camera or not mobile_settings.gesture_controls:
		return
	
	# Обработка сенсорных событий
	if event is InputEventScreenTouch:
		handle_touch_event(event)
	elif event is InputEventScreenDrag:
		handle_drag_event(event)

func handle_touch_event(event: InputEventScreenTouch):
	var touch_id = event.index
	
	if event.pressed:
		# Начало касания
		touch_points[touch_id] = {
			"position": event.position,
			"start_time": Time.get_ticks_msec() / 1000.0
		}
		
		# Проверяем количество касаний
		if touch_points.size() == 1:
			# Одно касание - начинаем панорамирование
			start_panning(event.position)
		elif touch_points.size() == 2:
			# Два касания - начинаем зум
			start_pinching()
		
		# Тактильная обратная связь
		if mobile_settings.vibration_feedback:
			Input.start_joypad_vibration(0, 0.1, 0.1, 0.1)
	
	else:
		# Конец касания
		if touch_points.has(touch_id):
			var touch_duration = Time.get_ticks_msec() / 1000.0 - touch_points[touch_id].start_time
			
			# Проверяем на быстрое двойное касание (быстрый зум)
			if touch_duration < 0.3 and touch_points.size() == 1:
				handle_double_tap(event.position)
			
			touch_points.erase(touch_id)
		
		# Останавливаем жесты если касаний не осталось
		if touch_points.size() == 0:
			stop_all_gestures()
		elif touch_points.size() == 1:
			# Возвращаемся к панорамированию если осталось одно касание
			var remaining_touch = touch_points.values()[0]
			start_panning(remaining_touch.position)

func handle_drag_event(event: InputEventScreenDrag):
	var touch_id = event.index
	
	if not touch_points.has(touch_id):
		return
	
	# Обновляем позицию касания
	touch_points[touch_id].position = event.position
	
	if touch_points.size() == 1 and is_panning:
		# Панорамирование одним пальцем
		handle_panning(event)
	elif touch_points.size() == 2 and is_pinching:
		# Зум двумя пальцами
		handle_pinch_zoom()

func start_panning(start_pos: Vector2):
	is_panning = true
	is_pinching = false
	pan_start_position = start_pos
	camera_start_position = camera.position
	auto_follow_target = null  # Останавливаем автоследование

func start_pinching():
	is_pinching = true
	is_panning = false
	
	# Вычисляем начальное расстояние между пальцами
	var touch_positions = touch_points.values()
	if touch_positions.size() >= 2:
		var pos1 = touch_positions[0].position
		var pos2 = touch_positions[1].position
		last_pinch_distance = pos1.distance_to(pos2)

func stop_all_gestures():
	is_panning = false
	is_pinching = false

func handle_panning(event: InputEventScreenDrag):
	var delta = event.position - pan_start_position
	var camera_delta = Vector3(
		-delta.x * mobile_settings.pan_sensitivity * 0.05,
		0,
		delta.y * mobile_settings.pan_sensitivity * 0.05
	)
	
	var new_position = camera_start_position + camera_delta
	
	# Применяем границы
	new_position.x = clamp(new_position.x, camera_bounds.min_x, camera_bounds.max_x)
	new_position.z = clamp(new_position.z, camera_bounds.min_z, camera_bounds.max_z)
	
	camera.position = new_position
	camera_moved.emit(new_position)

func handle_pinch_zoom():
	var touch_positions = touch_points.values()
	if touch_positions.size() < 2:
		return
	
	var pos1 = touch_positions[0].position
	var pos2 = touch_positions[1].position
	var current_distance = pos1.distance_to(pos2)
	
	if last_pinch_distance > 0:
		var zoom_factor = current_distance / last_pinch_distance
		var zoom_delta = (zoom_factor - 1.0) * mobile_settings.zoom_sensitivity
		
		# Применяем зум
		var new_y = camera.position.y - zoom_delta * 10
		var new_z = camera.position.z - zoom_delta * 8
		
		# Применяем границы
		new_y = clamp(new_y, camera_bounds.min_y, camera_bounds.max_y)
		new_z = clamp(new_z, camera_bounds.min_z, camera_bounds.max_z)
		
		camera.position.y = new_y
		camera.position.z = new_z
		
		zoom_changed.emit(new_y)
	
	last_pinch_distance = current_distance

func handle_double_tap(position: Vector2):
	print("📱 Двойное касание - быстрый зум")
	
	# Быстрое приближение к точке касания
	var world_pos = screen_to_world_position(position)
	if world_pos != Vector3.ZERO:
		smart_zoom_to_position(world_pos, 40.0)  # Приближаемся к высоте 40

func screen_to_world_position(screen_pos: Vector2) -> Vector3:
	if not camera:
		return Vector3.ZERO
	
	var from = camera.project_ray_origin(screen_pos)
	var direction = camera.project_ray_normal(screen_pos)
	var plane_y = 0.0
	
	if direction.y == 0:
		return Vector3.ZERO
	
	var t = (plane_y - from.y) / direction.y
	if t < 0:
		return Vector3.ZERO
	
	return from + direction * t

func smart_zoom_to_position(world_pos: Vector3, target_height: float):
	if not mobile_settings.smart_zoom:
		return
	
	# Создаём плавное движение к позиции
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Движение к позиции
	var target_pos = Vector3(world_pos.x, target_height, world_pos.z + target_height * 0.8)
	target_pos.x = clamp(target_pos.x, camera_bounds.min_x, camera_bounds.max_x)
	target_pos.z = clamp(target_pos.z, camera_bounds.min_z, camera_bounds.max_z)
	
	tween.tween_property(camera, "position", target_pos, 0.5)
	tween.tween_callback(func(): zoom_changed.emit(target_height))

func set_auto_follow_target(target: Node3D, duration: float = 2.0):
	if not mobile_settings.auto_follow:
		return
	
	auto_follow_target = target
	auto_follow_duration = duration
	auto_follow_timer = 0.0
	print("📱 Автоследование активировано за целью: ", target.name)

func _process(delta):
	# Обработка автоследования
	if auto_follow_target and is_instance_valid(auto_follow_target):
		auto_follow_timer += delta
		
		if auto_follow_timer < auto_follow_duration:
			# Плавно следуем за целью
			var target_pos = auto_follow_target.global_position
			var camera_offset = Vector3(0, camera.position.y, camera.position.y * 0.8)
			var desired_pos = target_pos + camera_offset
			
			# Применяем границы
			desired_pos.x = clamp(desired_pos.x, camera_bounds.min_x, camera_bounds.max_x)
			desired_pos.z = clamp(desired_pos.z, camera_bounds.min_z, camera_bounds.max_z)
			
			# Плавное движение
			camera.position = camera.position.lerp(desired_pos, delta * 2.0)
		else:
			# Прекращаем следование
			auto_follow_target = null

func update_camera_bounds(map_width: float, map_height: float):
	"""Обновляет границы камеры в зависимости от размера карты"""
	camera_bounds.min_x = -map_width / 2 - 5
	camera_bounds.max_x = map_width / 2 + 5
	camera_bounds.min_z = -map_height / 2 - 5
	camera_bounds.max_z = map_height / 2 + 5
	print("📱 Границы камеры обновлены: ", camera_bounds)

func set_mobile_setting(setting_name: String, value):
	"""Изменяет настройку мобильного управления"""
	if mobile_settings.has(setting_name):
		mobile_settings[setting_name] = value
		print("📱 Настройка изменена: ", setting_name, " = ", value)

func get_mobile_settings() -> Dictionary:
	"""Возвращает текущие настройки мобильного управления"""
	return mobile_settings.duplicate()

# Специальные функции для важных игровых событий
func focus_on_battle(battle_position: Vector3):
	"""Фокусируется на важном сражении"""
	if mobile_settings.smart_zoom:
		smart_zoom_to_position(battle_position, 35.0)
		
		# Тактильная обратная связь
		if mobile_settings.vibration_feedback:
			Input.start_joypad_vibration(0, 0.3, 0.3, 0.2)

func focus_on_territory_capture(territory_position: Vector3):
	"""Фокусируется на захвате территории"""
	if mobile_settings.smart_zoom:
		smart_zoom_to_position(territory_position, 30.0)

func reset_camera_to_base():
	"""Возвращает камеру к базе игрока"""
	if battle_manager:
		var player_base_pos = Vector3(0, 0, 35)  # Позиция базы игрока
		smart_zoom_to_position(player_base_pos, 50.0) 