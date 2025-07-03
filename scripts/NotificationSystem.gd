class_name NotificationSystem
extends Node

# NotificationSystem — система уведомлений для TERRION
# Показывает важные игровые события и достижения

var battle_manager = null

# Активные уведомления
var active_notifications = []
var max_notifications = 5
var notification_lifetime = 3.0

func _ready():
	print("📢 Система уведомлений инициализирована")

# Показать уведомление
func show_notification(text: String, type: String = "info", duration: float = 3.0):
	# Создаем простое уведомление
	var ui_notification = create_simple_notification(text, type)
	
	# Позиционируем уведомление
	position_notification(ui_notification)
	
	# Добавляем в список активных
	active_notifications.append(ui_notification)
	
	# Добавляем на сцену
	if battle_manager:
		battle_manager.add_child(ui_notification)
	else:
		get_parent().add_child(ui_notification)
	
	# Анимация появления
	animate_notification_in(ui_notification)
	
	# Автоудаление
	ui_notification.get_tree().create_timer(duration).timeout.connect(func(): remove_notification(ui_notification))
	
	# Ограничиваем количество уведомлений
	cleanup_old_notifications()
	
	print("📢 Уведомление: ", text)

# Создание простого уведомления
func create_simple_notification(text: String, type: String) -> Control:
	var ui_notification = Control.new()
	ui_notification.size = Vector2(300, 60)
	
	# Фон уведомления
	var bg = ColorRect.new()
	bg.size = ui_notification.size
	bg.color = get_notification_color(type)
	ui_notification.add_child(bg)
	
	# Текст уведомления
	var label = Label.new()
	label.text = text
	label.size = ui_notification.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_notification.add_child(label)
	
	# Рамка
	var border = Control.new()
	border.size = ui_notification.size
	var style = StyleBoxFlat.new()
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color.WHITE
	border.add_theme_stylebox_override("panel", style)
	ui_notification.add_child(border)
	
	return ui_notification

# Получение цвета уведомления по типу
func get_notification_color(type: String) -> Color:
	match type:
		"success":
			return Color(0.2, 0.8, 0.2, 0.9)  # Зеленый
		"warning":
			return Color(0.9, 0.7, 0.2, 0.9)  # Желтый
		"error":
			return Color(0.8, 0.2, 0.2, 0.9)  # Красный
		"info":
			return Color(0.2, 0.6, 0.9, 0.9)  # Синий
		"achievement":
			return Color(0.7, 0.2, 0.9, 0.9)  # Фиолетовый
		_:
			return Color(0.4, 0.4, 0.4, 0.9)  # Серый

# Позиционирование уведомления
func position_notification(ui_notification: Control):
	# Позиция в правом верхнем углу экрана
	var screen_size = get_viewport().get_visible_rect().size
	var y_offset = active_notifications.size() * 70  # Смещение для каждого уведомления
	
	ui_notification.position = Vector2(screen_size.x - 320, 20 + y_offset)

# Анимация появления
func animate_notification_in(ui_notification: Control):
	ui_notification.modulate.a = 0.0
	ui_notification.scale = Vector2(0.8, 0.8)
	
	var tween = get_tree().create_tween()
	tween.parallel().tween_property(ui_notification, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(ui_notification, "scale", Vector2(1.0, 1.0), 0.3)

# Анимация исчезновения
func animate_notification_out(ui_notification: Control, callback: Callable):
	var tween = get_tree().create_tween()
	tween.parallel().tween_property(ui_notification, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(ui_notification, "scale", Vector2(0.8, 0.8), 0.3)
	tween.tween_callback(callback)

# Удаление уведомления
func remove_notification(ui_notification: Control):
	if ui_notification in active_notifications:
		active_notifications.erase(ui_notification)
		animate_notification_out(ui_notification, func(): ui_notification.queue_free())
		reposition_notifications()

# Перепозиционирование уведомлений
func reposition_notifications():
	for i in range(active_notifications.size()):
		var ui_notification = active_notifications[i]
		var screen_size = get_viewport().get_visible_rect().size
		var target_pos = Vector2(screen_size.x - 320, 20 + i * 70)
		
		var tween = get_tree().create_tween()
		tween.tween_property(ui_notification, "position", target_pos, 0.3)

# Очистка старых уведомлений
func cleanup_old_notifications():
	while active_notifications.size() > max_notifications:
		var oldest = active_notifications[0]
		remove_notification(oldest)

# Удобные функции для частых уведомлений
func show_unit_spawned(unit_type: String, team: String):
	var team_emoji = "🟦" if team == "player" else "🟥"
	var unit_emoji = get_unit_emoji(unit_type)
	show_notification(team_emoji + " " + unit_emoji + " " + unit_type.capitalize() + " развернут!", "info")

func show_building_constructed(building_type: String, team: String):
	var team_emoji = "🟦" if team == "player" else "🟥"
	show_notification(team_emoji + " 🏗️ " + building_type.capitalize() + " построен!", "success")

func show_unit_killed(unit_type: String, team: String):
	var team_emoji = "🟦" if team == "player" else "🟥"
	var unit_emoji = get_unit_emoji(unit_type)
	show_notification(team_emoji + " " + unit_emoji + " " + unit_type.capitalize() + " уничтожен!", "warning")

func show_ability_used(ability_name: String, team: String):
	var team_emoji = "🟦" if team == "player" else "🟥"
	show_notification(team_emoji + " ✨ " + ability_name.capitalize() + " активирована!", "info")

func show_territory_captured(territory_name: String, team: String):
	var team_emoji = "🟦" if team == "player" else "🟥"
	show_notification(team_emoji + " 🏰 Территория " + territory_name + " захвачена!", "achievement")

func show_resource_gained(resource_type: String, amount: int):
	var resource_emoji = "⚡" if resource_type == "energy" else "💎"
	show_notification(resource_emoji + " +" + str(amount) + " " + resource_type + "!", "success")

func show_victory(winner: String):
	var message = "🏆 ПОБЕДА!" if winner == "player" else "💀 ПОРАЖЕНИЕ!"
	var type = "achievement" if winner == "player" else "error"
	show_notification(message, type, 5.0)

func show_hero_summoned(team: String):
	var team_emoji = "🟦" if team == "player" else "🟥"
	show_notification(team_emoji + " 🦸 ГЕРОЙ ПРИЗВАН! Ультимативная сила!", "achievement", 4.0)

func show_battle_start():
	show_notification("⚔️ БИТВА НАЧАЛАСЬ!", "achievement", 2.0)

func get_unit_emoji(unit_type: String) -> String:
	match unit_type:
		"soldier":
			return "🪖"
		"tank":
			return "🚗"
		"drone":
			return "🛸"
		"collector":
			return "🏃"
		"elite_soldier":
			return "🎖️"
		"crystal_mage":
			return "🔮"
		"turret":
			return "🗼"
		_:
			return "⚔️" 
 
