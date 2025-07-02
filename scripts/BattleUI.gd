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
	
	# Подключение drag&drop для ВСЕХ кнопок
	print("🔗 Подключаем drag&drop для всех кнопок...")
	$Panel/MainButtonContainer/SpawnSoldierButton.gui_input.connect(_on_unit_button_input)
	$Panel/MainButtonContainer/CollectorButton.gui_input.connect(_on_collector_button_input)
	$Panel/MainButtonContainer/BuildTowerButton.gui_input.connect(_on_structure_button_input)
	
	# Добавляем drag&drop для элитных юнитов (всегда)
	$Panel/MainButtonContainer/EliteSoldierButton.gui_input.connect(_on_elite_soldier_button_input)
	$Panel/MainButtonContainer/CrystalMageButton.gui_input.connect(_on_crystal_mage_button_input)
	print("✅ Все drag&drop подключения готовы!")

	if spawner_panel:
		spawner_panel.spawner_drag_start.connect(_on_spawner_drag_start)
		spawner_panel.spawner_drag_end.connect(_on_spawner_drag_end)
	
	# Обновление текста кнопок под новый лор
	update_button_texts()

	# Добавим инструкции управления
	add_control_instructions()

func update_button_texts():
	# Обновляем текст кнопок на более понятный
	$Panel/MainButtonContainer/SpawnSoldierButton.text = "⚔️ СОЛДАТ\n(20 энергии)"
	$Panel/MainButtonContainer/BuildTowerButton.text = "🗼 БАШНЯ\n(60 энергии)" 
	$Panel/MainButtonContainer/EliteSoldierButton.text = "🎖️ ЭЛИТНЫЙ\n(30⚡ + 10💎)"
	$Panel/MainButtonContainer/CrystalMageButton.text = "🔮 МАГ\n(25⚡ + 15💎)"
	$Panel/MainButtonContainer/CollectorButton.text = "🏃 КОЛЛЕКТОР\n(15 энергии)"
	
	if has_node("AbilityPanel/AbilityContainer"):
		if $AbilityPanel/AbilityContainer.has_node("FireballButton"):
			$AbilityPanel/AbilityContainer/FireballButton.text = "🔥 ФАЕРБОЛЛ"
		if $AbilityPanel/AbilityContainer.has_node("HealButton"):
			$AbilityPanel/AbilityContainer/HealButton.text = "💚 ЛЕЧЕНИЕ"
		if $AbilityPanel/AbilityContainer.has_node("ShieldButton"):
			$AbilityPanel/AbilityContainer/ShieldButton.text = "🛡️ ЩИТ"
		if $AbilityPanel/AbilityContainer.has_node("LightningButton"):
			$AbilityPanel/AbilityContainer/LightningButton.text = "⚡ МОЛНИЯ"

func _on_deploy_unit_pressed():
	print("⚔️ ИНСТРУКЦИЯ: Зажмите и перетащите кнопку СОЛДАТ на карту для спавна!")

func _on_construct_facility_pressed():
	print("🏗️ ИНСТРУКЦИЯ: Зажмите и перетащите кнопку БАШНЯ на карту для постройки!")

func _on_deploy_specialist_pressed():
	print("🎖️ ИНСТРУКЦИЯ: Зажмите и перетащите кнопку ЭЛИТНЫЙ на карту для спавна!")

func _on_deploy_technician_pressed():
	print("🔧 ИНСТРУКЦИЯ: Зажмите и перетащите кнопку МАГ на карту для спавна!")

func _on_spawn_collector_pressed():
	print("🏃 ИНСТРУКЦИЯ: Зажмите и перетащите кнопку КОЛЛЕКТОР на карту для спавна!")

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
	# Drag&drop для коллектора
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var collector_button = get_node("Panel/MainButtonContainer/CollectorButton")
		if event.pressed:
			# Начало drag-операции - меняем цвет кнопки
			drag_type = "collector"
			is_dragging = true
			drag_start_pos = event.position
			collector_button.modulate = Color.YELLOW  # Визуальная обратная связь
			print("🏃 Начало drag коллектора - перетащите на карту")
		else:
			# Завершение drag - спавн коллектора
			if is_dragging and drag_type == "collector":
				print("🏃 Завершение drag коллектора на позиции: ", event.position)
				spawn_unit_drag.emit("collector", event.position)
			is_dragging = false
			drag_type = ""
			collector_button.modulate = Color.WHITE  # Возвращаем обычный цвет

func _on_unit_button_input(event):
	# Drag&drop для солдата
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var soldier_button = get_node("Panel/MainButtonContainer/SpawnSoldierButton")
		if event.pressed:
			# Начало drag-операции - меняем цвет кнопки
			drag_type = "soldier"
			is_dragging = true
			drag_start_pos = event.position
			soldier_button.modulate = Color.YELLOW  # Визуальная обратная связь
			print("⚔️ Начало drag солдата - перетащите на карту")
		else:
			# Завершение drag - развертывание войск
			if is_dragging and drag_type == "soldier":
				print("⚔️ Завершение drag солдата на позиции: ", event.position)
				spawn_unit_drag.emit("soldier", event.position)
			is_dragging = false
			drag_type = ""
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
			print("🏗️ Начало drag башни - перетащите на карту")
		else:
			# Завершение drag - строительство модуля
			if is_dragging and drag_type == "tower":
				print("🏗️ Завершение drag башни на позиции: ", event.position)
				build_structure_drag.emit(event.position)
			is_dragging = false
			drag_type = ""
			tower_button.modulate = Color.WHITE  # Возвращаем обычный цвет

func _on_elite_soldier_button_input(event):
	# Drag&drop для элитного солдата
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var elite_button = get_node("Panel/MainButtonContainer/EliteSoldierButton")
		if event.pressed:
			drag_type = "elite_soldier"
			is_dragging = true
			drag_start_pos = event.position
			elite_button.modulate = Color.YELLOW
			print("🎖️ Начало drag элитного солдата - перетащите на карту")
		else:
			if is_dragging and drag_type == "elite_soldier":
				print("🎖️ Завершение drag элитного солдата на позиции: ", event.position)
				spawn_unit_drag.emit("elite_soldier", event.position)
			is_dragging = false
			drag_type = ""
			elite_button.modulate = Color.WHITE

func _on_crystal_mage_button_input(event):
	# Drag&drop для кристального мага
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mage_button = get_node("Panel/MainButtonContainer/CrystalMageButton")
		if event.pressed:
			drag_type = "crystal_mage"
			is_dragging = true
			drag_start_pos = event.position
			mage_button.modulate = Color.YELLOW
			print("🔧 Начало drag техно-специалиста - перетащите на карту")
		else:
			if is_dragging and drag_type == "crystal_mage":
				print("🔧 Завершение drag техно-специалиста на позиции: ", event.position)
				spawn_unit_drag.emit("crystal_mage", event.position)
			is_dragging = false
			drag_type = ""
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
	# (documentation comment)
	if is_dragging:
		if event is InputEventMouseMotion:
			# Можно добавить визуальную обратную связь при drag
			pass 

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
 
 
 
