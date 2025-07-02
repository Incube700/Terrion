class_name BattleUI
extends CanvasLayer

# Интерфейс командира TERRION - управление фракцией в космических битвах
# Адаптирован для мобильных устройств с тач-управлением

signal start_battle
signal spawn_unit_drag(unit_type, screen_pos)
signal build_structure_drag(screen_pos)
signal use_ability(ability_name: String, position: Vector3)

var drag_type = ""
var is_dragging = false
var drag_start_pos = Vector2.ZERO
var ghost_preview = null

@onready var spawner_panel = $SpawnerPanel
@onready var main_menu = $MainMenu
@onready var game_panel = $Panel
@onready var ability_panel = $AbilityPanel

func _ready():
	print("🖥️ Инициализация пользовательского интерфейса...")
	
	# Подключение кнопок главного меню
	var start_game_button = get_node("MainMenu/MenuContainer/StartGameButton")
	var exit_button = get_node("MainMenu/MenuContainer/ExitButton")
	
	if start_game_button:
		start_game_button.pressed.connect(_on_start_game_pressed)
		print("✅ Кнопка 'Начать игру' подключена")
	
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
		print("✅ Кнопка 'Выход' подключена")

	# Подключение кнопок игрового интерфейса  
	var collector_button = get_node("Panel/MainButtonContainer/CollectorButton")
	var soldier_button = get_node("Panel/MainButtonContainer/SpawnSoldierButton")
	
	if collector_button:
		collector_button.pressed.connect(_on_spawn_collector_pressed)
		print("✅ Кнопка 'Коллектор' подключена")
	
	if soldier_button:
		soldier_button.pressed.connect(_on_deploy_unit_pressed)
		print("✅ Кнопка 'Солдат' подключена")
	
	# Подключение основных команд (скрыты до старта)
	$Panel/MainButtonContainer/BuildTowerButton.pressed.connect(_on_construct_facility_pressed)
	$Panel/MainButtonContainer/EliteSoldierButton.pressed.connect(_on_deploy_specialist_pressed)
	$Panel/MainButtonContainer/CrystalMageButton.pressed.connect(_on_deploy_technician_pressed)
	
	# Подключение технологических способностей
	if has_node("AbilityPanel/AbilityContainer"):
		if $AbilityPanel/AbilityContainer.has_node("FireballButton"):
			$AbilityPanel/AbilityContainer/FireballButton.pressed.connect(_on_plasma_strike_pressed)
		if $AbilityPanel/AbilityContainer.has_node("HealButton"):
			$AbilityPanel/AbilityContainer/HealButton.pressed.connect(_on_repair_wave_pressed)
		if $AbilityPanel/AbilityContainer.has_node("ShieldButton"):
			$AbilityPanel/AbilityContainer/ShieldButton.pressed.connect(_on_energy_barrier_pressed)
		if $AbilityPanel/AbilityContainer.has_node("LightningButton"):
			$AbilityPanel/AbilityContainer/LightningButton.pressed.connect(_on_ion_storm_pressed)
	
	# Создаем кнопку для расовых способностей
	create_race_ability_button()
	
	# Подключение drag&drop для ВСЕХ кнопок
	print("🔗 Подключаем drag&drop для всех кнопок...")
	$Panel/MainButtonContainer/SpawnSoldierButton.gui_input.connect(_on_unit_button_input)
	$Panel/MainButtonContainer/CollectorButton.gui_input.connect(_on_collector_button_input)
	$Panel/MainButtonContainer/BuildTowerButton.gui_input.connect(_on_structure_button_input)
	
	# Добавляем drag&drop для элитных юнитов (всегда)
	$Panel/MainButtonContainer/EliteSoldierButton.gui_input.connect(_on_elite_soldier_button_input)
	$Panel/MainButtonContainer/CrystalMageButton.gui_input.connect(_on_crystal_mage_button_input)
	
	# Добавляем новые здания в _ready после их создания
	call_deferred("connect_new_building_inputs")
	print("✅ Все drag&drop подключения готовы!")

	if spawner_panel:
		spawner_panel.spawner_drag_start.connect(_on_spawner_drag_start)
		spawner_panel.spawner_drag_end.connect(_on_spawner_drag_end)
	
	# Обновление текста кнопок под новый лор
	update_button_texts()
	
	# Подключаем новые здания после их создания
	call_deferred("connect_new_building_inputs")

	# Добавим инструкции управления
	add_control_instructions()

func update_button_texts():
	# Обновляем текст кнопок - теперь это ЗДАНИЯ-СПАВНЕРЫ
	$Panel/MainButtonContainer/SpawnSoldierButton.text = "🏰 КАЗАРМЫ\n💰 80 энергии"
	$Panel/MainButtonContainer/BuildTowerButton.text = "🗼 БАШНЯ\n💰 60 энергии" 
	$Panel/MainButtonContainer/EliteSoldierButton.text = "🎖️ ТРЕНИРОВОЧНЫЙ ЛАГЕРЬ\n💰 120⚡ + 20💎"
	$Panel/MainButtonContainer/CrystalMageButton.text = "🔮 МАГИЧЕСКАЯ АКАДЕМИЯ\n💰 100⚡ + 30💎"
	$Panel/MainButtonContainer/CollectorButton.text = "🏃 ЦЕНТР КОЛЛЕКТОРОВ\n💰 90 энергии + 15💎"
	
	# Добавляем новые здания
	add_new_building_buttons()
	
	# Улучшаем стиль кнопок
	improve_button_style($Panel/MainButtonContainer/SpawnSoldierButton, Color.CYAN)
	improve_button_style($Panel/MainButtonContainer/BuildTowerButton, Color.ORANGE)
	improve_button_style($Panel/MainButtonContainer/EliteSoldierButton, Color.GOLD)
	improve_button_style($Panel/MainButtonContainer/CrystalMageButton, Color.MAGENTA)
	improve_button_style($Panel/MainButtonContainer/CollectorButton, Color.GREEN)

func add_new_building_buttons():
	# Создаем новые кнопки для дополнительных зданий
	var button_container = $Panel/MainButtonContainer
	
	# Мех завод для боевых роботов
	var mech_factory_button = Button.new()
	mech_factory_button.name = "MechFactoryButton"
	mech_factory_button.text = "🤖 МЕХ ЗАВОД\n💰 150⚡ + 25💎\nПроизводит роботов"
	mech_factory_button.size = Vector2(120, 80)
	mech_factory_button.add_theme_font_size_override("font_size", 14)
	mech_factory_button.pressed.connect(_on_mech_factory_pressed)
	button_container.add_child(mech_factory_button)
	improve_button_style(mech_factory_button, Color.STEEL_BLUE)
	
	# Дрон фабрика для летающих дронов
	var drone_factory_button = Button.new()
	drone_factory_button.name = "DroneFactoryButton"
	drone_factory_button.text = "🛸 ДРОН ФАБРИКА\n💰 130⚡ + 20💎\nПроизводит дронов"
	drone_factory_button.size = Vector2(120, 80)
	drone_factory_button.add_theme_font_size_override("font_size", 14)
	drone_factory_button.pressed.connect(_on_drone_factory_pressed)
	button_container.add_child(drone_factory_button)
	improve_button_style(drone_factory_button, Color.LIGHT_BLUE)
	
	print("🏭 Добавлены новые здания: Мех завод и Дрон фабрика")

func _on_deploy_unit_pressed():
	print("🏰 ИНСТРУКЦИЯ: Зажмите и перетащите кнопку КАЗАРМЫ на карту для постройки!")

func _on_construct_facility_pressed():
	print("🗼 ИНСТРУКЦИЯ: Зажмите и перетащите кнопку БАШНЯ на карту для постройки!")

func _on_deploy_specialist_pressed():
	print("🎖️ ИНСТРУКЦИЯ: Зажмите и перетащите кнопку ТРЕНИРОВОЧНЫЙ ЛАГЕРЬ на карту для постройки!")

func _on_deploy_technician_pressed():
	print("🔮 ИНСТРУКЦИЯ: Зажмите и перетащите кнопку МАГИЧЕСКАЯ АКАДЕМИЯ на карту для постройки!")

func _on_spawn_collector_pressed():
	print("🏃 ИНСТРУКЦИЯ: Зажмите и перетащите кнопку ЦЕНТР КОЛЛЕКТОРОВ на карту для постройки!")

func _on_plasma_strike_pressed():
	print("🔥 Плазменный удар по вражеским позициям")
	use_ability.emit("fireball", Vector3(0, 0, 0))

func _on_repair_wave_pressed():
	print("💚 Волна ремонта восстанавливает союзников")
	use_ability.emit("heal_wave", Vector3(0, 0, 10))

func _on_energy_barrier_pressed():
	print("🛡️ Энергетический барьер защищает войска")
	use_ability.emit("shield_barrier", Vector3(0, 0, 10))

func _on_ion_storm_pressed():
	print("⚡ Ионная буря поражает врагов")
	use_ability.emit("lightning_storm", Vector3(0, 0, 0))

func update_ability_buttons(energy: int, crystals: int):
	# (documentation comment)
	if has_node("AbilityPanel/AbilityContainer"):
		update_button_state("AbilityPanel/AbilityContainer/FireballButton", energy >= 40, crystals >= 15)
		update_button_state("AbilityPanel/AbilityContainer/HealButton", energy >= 30, crystals >= 10)
		update_button_state("AbilityPanel/AbilityContainer/ShieldButton", energy >= 50, crystals >= 20)
		update_button_state("AbilityPanel/AbilityContainer/LightningButton", energy >= 60, crystals >= 25)

func update_unit_buttons(energy: int, crystals: int):
	# (documentation comment)
	update_button_state("Panel/MainButtonContainer/SpawnSoldierButton", energy >= 20, true)
	update_button_state("Panel/MainButtonContainer/EliteSoldierButton", energy >= 30, crystals >= 10)
	update_button_state("Panel/MainButtonContainer/CrystalMageButton", energy >= 25, crystals >= 15)
	update_button_state("Panel/MainButtonContainer/BuildTowerButton", energy >= 60, true)

func update_button_state(button_path: String, has_energy: bool, has_crystals: bool):
	# (documentation comment)
	if has_node(button_path):
		var button = get_node(button_path)
		var can_afford = has_energy and has_crystals
		
		# Изменяем прозрачность для мобильной читаемости
		if can_afford:
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Активная команда
		else:
			button.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Недоступная команда
		
		button.disabled = not can_afford

func _on_collector_button_input(event):
	# Коллекторы спавнятся автоматически, не требуют drag&drop
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var collector_button = get_node("Panel/MainButtonContainer/CollectorButton")
		
		print("🏃 Спавн коллектора - автоматическое размещение на игровой половине")
		
		# Эмитируем сигнал для создания коллектора (BattleManager обработает автоматически)
		spawn_unit_drag.emit("collector", Vector2.ZERO)  # Позиция не важна для коллекторов
		
		# Визуальная обратная связь
		collector_button.modulate = Color.GREEN
		await get_tree().create_timer(0.2).timeout
		collector_button.modulate = Color.WHITE

func _on_unit_button_input(event):
	# Drag&drop для казарм
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var soldier_button = get_node("Panel/MainButtonContainer/SpawnSoldierButton")
		if event.pressed:
			# Начало drag-операции - меняем цвет кнопки
			drag_type = "barracks"
			is_dragging = true
			drag_start_pos = event.position
			soldier_button.modulate = Color.YELLOW  # Визуальная обратная связь
			create_ghost_preview("barracks")
			print("🏰 Начало drag казарм - перетащите на карту")
		else:
			# Завершение drag - строительство казарм
			if is_dragging and drag_type == "barracks":
				print("🏰 Завершение drag казарм на позиции: ", event.position)
				build_structure_drag.emit(event.position)  # Строим здание
			is_dragging = false
			drag_type = ""
			destroy_ghost_preview()
			soldier_button.modulate = Color.WHITE  # Возвращаем обычный цвет

func _on_structure_button_input(event):
	# Drag&drop для строительства башни
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var tower_button = get_node("Panel/MainButtonContainer/BuildTowerButton")
		if event.pressed:
			# Начало drag-операции
			drag_type = "tower"
			is_dragging = true
			drag_start_pos = event.position
			tower_button.modulate = Color.YELLOW  # Визуальная обратная связь
			create_ghost_preview("tower")
			print("🏗️ Начало drag башни - перетащите на карту")
		else:
			# Завершение drag - строительство модуля
			if is_dragging and drag_type == "tower":
				print("🏗️ Завершение drag башни на позиции: ", event.position)
				build_structure_drag.emit(event.position)
			is_dragging = false
			drag_type = ""
			destroy_ghost_preview()
			tower_button.modulate = Color.WHITE  # Возвращаем обычный цвет

func _on_elite_soldier_button_input(event):
	# Drag&drop для тренировочного лагеря
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var elite_button = get_node("Panel/MainButtonContainer/EliteSoldierButton")
		if event.pressed:
			drag_type = "training_camp"
			is_dragging = true
			drag_start_pos = event.position
			elite_button.modulate = Color.YELLOW
			create_ghost_preview("training_camp")
			print("🎖️ Начало drag тренировочного лагеря - перетащите на карту")
		else:
			if is_dragging and drag_type == "training_camp":
				print("🎖️ Завершение drag тренировочного лагеря на позиции: ", event.position)
				build_structure_drag.emit(event.position)  # Строим здание
			is_dragging = false
			drag_type = ""
			destroy_ghost_preview()
			elite_button.modulate = Color.WHITE

func _on_crystal_mage_button_input(event):
	# Drag&drop для магической академии
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mage_button = get_node("Panel/MainButtonContainer/CrystalMageButton")
		if event.pressed:
			drag_type = "magic_academy"
			is_dragging = true
			drag_start_pos = event.position
			mage_button.modulate = Color.YELLOW
			create_ghost_preview("magic_academy")
			print("🔮 Начало drag магической академии - перетащите на карту")
		else:
			if is_dragging and drag_type == "magic_academy":
				print("🔮 Завершение drag магической академии на позиции: ", event.position)
				build_structure_drag.emit(event.position)  # Строим здание
			is_dragging = false
			drag_type = ""
			destroy_ghost_preview()
			mage_button.modulate = Color.WHITE

func update_info(player_hp, player_energy, enemy_hp, enemy_energy, player_crystals = 0, enemy_crystals = 0):
	# (documentation comment)
	# Создаем красивый интерфейс с эмодзи и цветами
	$PlayerHUD.text = "🟦 КОМАНДИР | ⚡%d | 💎%d | ❤️%d" % [player_energy, player_crystals, player_hp]
	$EnemyHUD.text = "🟥 ПРОТИВНИК | ⚡%d | 💎%d | ❤️%d" % [enemy_energy, enemy_crystals, enemy_hp]
	
	# Цветовая индикация состояния
	$PlayerHUD.modulate = Color(0.7, 0.9, 1.0)  # Синеватый для игрока
	$EnemyHUD.modulate = Color(1.0, 0.7, 0.7)   # Красноватый для врага
	
	# Обновляем состояние всех команд
	update_ability_buttons(player_energy, player_crystals)
	update_unit_buttons(player_energy, player_crystals)

func get_hp_color(hp: int, max_hp: int) -> Color:
	# (documentation comment)
	var hp_percent = float(hp) / float(max_hp)
	if hp_percent > 0.7:
		return Color.GREEN
	elif hp_percent > 0.3:
		return Color.YELLOW
	else:
		return Color.RED

func _input(event):
	# Обновляем позицию призрачного предпросмотра
	if is_dragging and ghost_preview:
		if event is InputEventMouseMotion:
			var mouse_pos = get_global_mouse_position()
			ghost_preview.position = mouse_pos - ghost_preview.size / 2
			
			# Меняем цвет в зависимости от валидности позиции
			var can_build = can_build_at_position(mouse_pos)
			if can_build:
				ghost_preview.color = get_building_color(drag_type)
				ghost_preview.color.a = 0.7
			else:
				ghost_preview.color = Color.RED
				ghost_preview.color.a = 0.5

func _on_spawner_drag_start(spawner_type):
	# (documentation comment)
	print("[Интерфейс] Начато размещение модуля: ", spawner_type)

func _on_spawner_drag_end(spawner_type, global_pos):
	# (documentation comment)
	print("[Интерфейс] Модуль размещен: ", spawner_type, " в точке ", global_pos)
	# Передача команды в центральную систему управления
	if get_parent().has_method("on_spawner_drop"):
		get_parent().on_spawner_drop(spawner_type, global_pos)

func _on_start_game_pressed():
	print("🚀 === НАЧАЛО НОВОЙ ИГРЫ ===")
	print("1. Скрываем главное меню...")
	main_menu.visible = false
	print("2. Показываем игровой интерфейс...")
	game_panel.visible = true
	ability_panel.visible = true
	spawner_panel.visible = true
	$PlayerHUD.visible = true
	$EnemyHUD.visible = true
	
	# Показываем инструкции управления
	var instructions = get_node_or_null("ControlInstructions")
	if instructions:
		instructions.visible = true
		print("📋 Инструкции управления показаны")
	
	print("3. Отправляем сигнал start_battle...")
	start_battle.emit()
	print("4. Игра запущена успешно!")

func _on_exit_pressed():
	print("🚪 Выход из игры")
	get_tree().quit()

func show_main_menu():
	# Показываем главное меню (например, при поражении/победе)
	main_menu.visible = true
	game_panel.visible = false
	ability_panel.visible = false
	spawner_panel.visible = false
	$PlayerHUD.visible = false
	$EnemyHUD.visible = false

func improve_button_style(button: Button, color: Color):
	# Улучшаем визуальный стиль кнопок
	if not button:
		return
		
	# Устанавливаем цвет модуляции
	button.modulate = color
	
	# Добавляем тему для размера шрифта
	button.add_theme_font_size_override("font_size", 18)
	
	# Создаем отдельные функции для событий мыши (избегаем lambda capture)
	var original_color = color
	var hover_color = color.lightened(0.3)
	
	# Подключаем события без lambda
	if not button.mouse_entered.is_connected(_on_button_hover):
		button.mouse_entered.connect(_on_button_hover.bind(button, hover_color))
	if not button.mouse_exited.is_connected(_on_button_unhover):
		button.mouse_exited.connect(_on_button_unhover.bind(button, original_color))

func _on_button_hover(button: Button, hover_color: Color):
	button.modulate = hover_color

func _on_button_unhover(button: Button, original_color: Color):
	button.modulate = original_color

func add_control_instructions():
	# Создаем панель с инструкциями управления
	var instructions = Label.new()
	instructions.name = "ControlInstructions"
	instructions.text = """🎮 УПРАВЛЕНИЕ:
🖱️ ПКМ + драг = камера
🎮 Скролл = зум
🏃 DRAG & DROP = спавн!
1️⃣ Зажми кнопку
2️⃣ Перетащи на карту
3️⃣ Отпусти = спавн!

🔥 Способности = клик кнопки"""
	
	instructions.anchors_preset = Control.PRESET_TOP_RIGHT
	instructions.position = Vector2(-350, 10)
	instructions.size = Vector2(340, 220)
	instructions.add_theme_font_size_override("font_size", 20)  # Увеличил размер
	instructions.add_theme_color_override("font_color", Color.YELLOW)  # Ярче
	instructions.add_theme_color_override("font_shadow_color", Color.BLACK)
	instructions.add_theme_constant_override("shadow_offset_x", 3)
	instructions.add_theme_constant_override("shadow_offset_y", 3)
	instructions.visible = false  # Скрываем до начала игры
	
	add_child(instructions)

func show_game_interface():
	# Скрываем главное меню и показываем игровой интерфейс
	$MainMenu.visible = false
	$Panel.visible = true
	$AbilityPanel.visible = true
	$PlayerHUD.visible = true
	$EnemyHUD.visible = true
	$SpawnerPanel.visible = true
	
	# Показываем инструкции управления
	var instructions = get_node_or_null("ControlInstructions")
	if instructions:
		instructions.visible = true
	
	print("🎮 Игровой интерфейс активирован")

func create_race_ability_button():
	# Создаем кнопку для расовых способностей
	if not has_node("AbilityPanel/AbilityContainer"):
		return
	
	var ability_container = $AbilityPanel/AbilityContainer
	
	# Создаем кнопку ЭМИ-импульса
	var emp_button = Button.new()
	emp_button.name = "EMPButton"
	emp_button.text = "⚡ ЭМИ-ИМПУЛЬС\n💥 Отключает здания"
	emp_button.size = Vector2(140, 60)
	emp_button.add_theme_font_size_override("font_size", 16)
	
	# Подключаем обработчик
	emp_button.pressed.connect(_on_emp_pulse_pressed)
	
	# Добавляем в контейнер
	ability_container.add_child(emp_button)
	
	# Стилизуем кнопку
	improve_button_style(emp_button, Color.PURPLE)
	
	print("⚡ Кнопка ЭМИ-импульса создана")

func _on_emp_pulse_pressed():
	print("⚡ Активация ЭМИ-импульса!")
	# Используем способность через правый клик или автоматически
	use_ability.emit("emp_pulse", Vector3(0, 0, -10))  # Атакуем вражескую зону

func create_ghost_preview(building_type: String):
	# Создаем призрачный предпросмотр здания
	ghost_preview = ColorRect.new()
	ghost_preview.size = Vector2(60, 60)
	ghost_preview.color = get_building_color(building_type)
	ghost_preview.color.a = 0.5  # Полупрозрачность
	ghost_preview.z_index = 100  # Поверх всего
	
	# Добавляем текст с типом здания
	var label = Label.new()
	label.text = get_building_emoji(building_type)
	label.add_theme_font_size_override("font_size", 32)
	label.anchors_preset = Control.PRESET_CENTER
	ghost_preview.add_child(label)
	
	add_child(ghost_preview)
	print("👻 Создан призрачный предпросмотр для ", building_type)

func destroy_ghost_preview():
	if ghost_preview:
		ghost_preview.queue_free()
		ghost_preview = null
		print("👻 Призрачный предпросмотр удален")

func get_building_color(building_type: String) -> Color:
	match building_type:
		"barracks": return Color.CYAN
		"tower": return Color.ORANGE
		"training_camp": return Color.GOLD
		"magic_academy": return Color.MAGENTA
		"mech_factory": return Color.STEEL_BLUE
		"drone_factory": return Color.LIGHT_BLUE
		_: return Color.WHITE

func get_building_emoji(building_type: String) -> String:
	match building_type:
		"barracks": return "🏰"
		"tower": return "🗼"
		"training_camp": return "🎖️"
		"magic_academy": return "🔮"
		"mech_factory": return "🤖"
		"drone_factory": return "🛸"
		_: return "🏗️"

func can_build_at_position(screen_pos: Vector2) -> bool:
	# Простая проверка - можно строить только в нижней половине экрана (игрок)
	var screen_size = get_viewport().get_visible_rect().size
	return screen_pos.y > screen_size.y * 0.5

func _on_mech_factory_pressed():
	print("🤖 ИНСТРУКЦИЯ: Зажмите и перетащите кнопку МЕХ ЗАВОД на карту для постройки!")

func _on_drone_factory_pressed():
	print("🛸 ИНСТРУКЦИЯ: Зажмите и перетащите кнопку ДРОН ФАБРИКА на карту для постройки!")

func _on_mech_factory_button_input(event):
	# Drag&drop для мех завода
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mech_button = get_node("Panel/MainButtonContainer/MechFactoryButton")
		if event.pressed:
			drag_type = "mech_factory"
			is_dragging = true
			drag_start_pos = event.position
			mech_button.modulate = Color.YELLOW
			create_ghost_preview("mech_factory")
			print("🤖 Начало drag мех завода - перетащите на карту")
		else:
			if is_dragging and drag_type == "mech_factory":
				print("🤖 Завершение drag мех завода на позиции: ", event.position)
				build_structure_drag.emit(event.position)
			is_dragging = false
			drag_type = ""
			destroy_ghost_preview()
			mech_button.modulate = Color.STEEL_BLUE

func _on_drone_factory_button_input(event):
	# Drag&drop для дрон фабрики
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var drone_button = get_node("Panel/MainButtonContainer/DroneFactoryButton")
		if event.pressed:
			drag_type = "drone_factory"
			is_dragging = true
			drag_start_pos = event.position
			drone_button.modulate = Color.YELLOW
			create_ghost_preview("drone_factory")
			print("🛸 Начало drag дрон фабрики - перетащите на карту")
		else:
			if is_dragging and drag_type == "drone_factory":
				print("🛸 Завершение drag дрон фабрики на позиции: ", event.position)
				build_structure_drag.emit(event.position)
			is_dragging = false
			drag_type = ""
			destroy_ghost_preview()
			drone_button.modulate = Color.LIGHT_BLUE

func connect_new_building_inputs():
	# Подключаем drag&drop для новых зданий после их создания
	var mech_button = get_node_or_null("Panel/MainButtonContainer/MechFactoryButton")
	var drone_button = get_node_or_null("Panel/MainButtonContainer/DroneFactoryButton")
	
	if mech_button:
		mech_button.gui_input.connect(_on_mech_factory_button_input)
		print("🤖 Мех завод подключен к drag&drop")
	
	if drone_button:
		drone_button.gui_input.connect(_on_drone_factory_button_input)
		print("🛸 Дрон фабрика подключена к drag&drop")
