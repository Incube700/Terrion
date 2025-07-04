extends CanvasLayer

# Интерфейс командира TERRION - компактный UI с иконками
# Все кнопки расположены в сетке без наложений

signal start_battle
signal build_structure_drag(screen_pos)
signal use_ability(ability_name: String, position: Vector3)
signal summon_hero()
signal rally_units()
signal retreat_units()
signal upgrade_units()
signal use_nuke()

var drag_type = ""
var is_dragging = false
var drag_start_pos = Vector2.ZERO
var ghost_preview = null

@onready var main_menu = $MainMenu
@onready var game_ui = $GameUI

func _ready():
	print("🖥️ Компактный интерфейс командира загружается...")
	
	# Подключение кнопок главного меню
	var start_game_button = get_node("MainMenu/MenuContainer/StartGameButton")
	var exit_button = get_node("MainMenu/MenuContainer/ExitButton")
	
	if start_game_button:
		start_game_button.pressed.connect(_on_start_game_pressed)
		print("✅ Кнопка 'Начать игру' подключена")
	
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
		print("✅ Кнопка 'Выход' подключена")

	# Настраиваем все кнопки
	setup_building_buttons()
	setup_ability_buttons()
	setup_special_buttons()
	
	print("✅ Все кнопки настроены")

func setup_building_buttons():
	# Кнопки зданий с drag&drop
	var barracks_button = get_node("GameUI/BottomPanel/BottomContainer/BuildingRow/BarracksButton")
	var collector_button = get_node("GameUI/BottomPanel/BottomContainer/BuildingRow/CollectorButton")
	var tower_button = get_node("GameUI/BottomPanel/BottomContainer/BuildingRow/TowerButton")
	var training_button = get_node("GameUI/BottomPanel/BottomContainer/BuildingRow/TrainingButton")
	var academy_button = get_node("GameUI/BottomPanel/BottomContainer/BuildingRow/AcademyButton")
	
	if barracks_button:
		barracks_button.gui_input.connect(_on_barracks_button_input)
	if collector_button:
		collector_button.gui_input.connect(_on_collector_button_input)
	if tower_button:
		tower_button.gui_input.connect(_on_tower_button_input)
	if training_button:
		training_button.gui_input.connect(_on_training_button_input)
	if academy_button:
		academy_button.gui_input.connect(_on_academy_button_input)
	
	print("✅ Кнопки зданий настроены")

func setup_ability_buttons():
	# Кнопки способностей
	var fireball_button = get_node("GameUI/BottomPanel/BottomContainer/AbilityRow/FireballButton")
	var heal_button = get_node("GameUI/BottomPanel/BottomContainer/AbilityRow/HealButton")
	var shield_button = get_node("GameUI/BottomPanel/BottomContainer/AbilityRow/ShieldButton")
	var lightning_button = get_node("GameUI/BottomPanel/BottomContainer/AbilityRow/LightningButton")
	var hero_button = get_node("GameUI/BottomPanel/BottomContainer/AbilityRow/HeroButton")
	
	if fireball_button:
		fireball_button.pressed.connect(_on_fireball_ability)
	if heal_button:
		heal_button.pressed.connect(_on_heal_ability)
	if shield_button:
		shield_button.pressed.connect(_on_shield_ability)
	if lightning_button:
		lightning_button.pressed.connect(_on_lightning_ability)
	if hero_button:
		hero_button.pressed.connect(_on_hero_summon_pressed)
	
	print("✅ Кнопки способностей настроены")

func setup_special_buttons():
	# Специальные кнопки
	var rally_button = get_node("GameUI/BottomPanel/BottomContainer/SpecialRow/RallyButton")
	var retreat_button = get_node("GameUI/BottomPanel/BottomContainer/SpecialRow/RetreatButton")
	var upgrade_button = get_node("GameUI/BottomPanel/BottomContainer/SpecialRow/UpgradeButton")
	var nuke_button = get_node("GameUI/BottomPanel/BottomContainer/SpecialRow/NukeButton")
	var menu_button = get_node("GameUI/BottomPanel/BottomContainer/SpecialRow/MenuButton")
	
	if rally_button:
		rally_button.pressed.connect(_on_rally_pressed)
	if retreat_button:
		retreat_button.pressed.connect(_on_retreat_pressed)
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_pressed)
	if nuke_button:
		nuke_button.pressed.connect(_on_nuke_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	
	print("✅ Специальные кнопки настроены")

# Drag&drop обработчики для зданий
func _on_barracks_button_input(event):
	_handle_building_drag(event, "barracks", get_node("GameUI/BottomPanel/BottomContainer/BuildingRow/BarracksButton"))

func _on_collector_button_input(event):
	_handle_building_drag(event, "collector_facility", get_node("GameUI/BottomPanel/BottomContainer/BuildingRow/CollectorButton"))

func _on_tower_button_input(event):
	_handle_building_drag(event, "tower", get_node("GameUI/BottomPanel/BottomContainer/BuildingRow/TowerButton"))

func _on_training_button_input(event):
	_handle_building_drag(event, "training_camp", get_node("GameUI/BottomPanel/BottomContainer/BuildingRow/TrainingButton"))

func _on_academy_button_input(event):
	_handle_building_drag(event, "magic_academy", get_node("GameUI/BottomPanel/BottomContainer/BuildingRow/AcademyButton"))

func _handle_building_drag(event, building_type: String, button: Button):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Начало drag-операции
			drag_type = building_type
			is_dragging = true
			drag_start_pos = event.position
			button.modulate = Color.YELLOW  # Визуальная обратная связь
			create_ghost_preview(building_type)
			print("🏗️ Начало drag ", building_type, " - перетащите на карту")
		else:
			# Завершение drag - строительство здания
			if is_dragging and drag_type == building_type:
				print("🏗️ Завершение drag ", building_type, " на позиции: ", event.position)
				build_structure_drag.emit(event.position)
			is_dragging = false
			drag_type = ""
			destroy_ghost_preview()
			button.modulate = Color.WHITE  # Возвращаем обычный цвет

# Обработчики способностей
func _on_fireball_ability():
	print("🔥 Огненный шар!")
	use_ability.emit("fireball", Vector3(0, 0, -10))

func _on_heal_ability():
	print("💚 Лечение союзников!")
	use_ability.emit("heal_wave", Vector3(0, 0, 10))

func _on_shield_ability():
	print("🛡️ Энергетический щит!")
	use_ability.emit("shield_barrier", Vector3(0, 0, 10))

func _on_lightning_ability():
	print("⚡ Ионная буря!")
	use_ability.emit("lightning_storm", Vector3(0, 0, -10))

func _on_hero_summon_pressed():
	print("🦸 Призыв героя!")
	summon_hero.emit()

# Обработчики специальных кнопок
func _on_rally_pressed():
	print("🎯 Сбор войск!")
	rally_units.emit()

func _on_retreat_pressed():
	print("🏃 Отступление!")
	retreat_units.emit()

func _on_upgrade_pressed():
	print("⬆️ Улучшение юнитов!")
	upgrade_units.emit()

func _on_nuke_pressed():
	print("☢️ Ядерный удар!")
	use_nuke.emit()

func _on_menu_pressed():
	print("⚙️ Открытие меню!")
	show_main_menu()

func update_info(player_hp, player_energy, enemy_hp, enemy_energy, player_crystals = 0, enemy_crystals = 0):
	# Обновляем информацию в верхней панели
	var player_info = get_node("GameUI/TopPanel/TopContainer/PlayerInfo")
	var enemy_info = get_node("GameUI/TopPanel/TopContainer/EnemyInfo")
	
	if player_info:
		player_info.text = "🟦 ИГРОК | ⚡%d | 💎%d | ❤️%d" % [player_energy, player_crystals, player_hp]
		player_info.modulate = Color(0.7, 0.9, 1.0)
	
	if enemy_info:
		enemy_info.text = "🟥 ВРАГ | ⚡%d | 💎%d | ❤️%d" % [enemy_energy, enemy_crystals, enemy_hp]
		enemy_info.modulate = Color(1.0, 0.7, 0.7)
	
	# Обновляем доступность кнопок
	update_button_availability(player_energy, player_crystals)

func update_button_availability(energy: int, crystals: int):
	# Здания
	update_single_button("GameUI/BottomPanel/BottomContainer/BuildingRow/BarracksButton", energy >= 80)
	update_single_button("GameUI/BottomPanel/BottomContainer/BuildingRow/CollectorButton", energy >= 90 and crystals >= 15)
	update_single_button("GameUI/BottomPanel/BottomContainer/BuildingRow/TowerButton", energy >= 60)
	update_single_button("GameUI/BottomPanel/BottomContainer/BuildingRow/TrainingButton", energy >= 120 and crystals >= 20)
	update_single_button("GameUI/BottomPanel/BottomContainer/BuildingRow/AcademyButton", energy >= 100 and crystals >= 30)
	
	# Способности
	update_single_button("GameUI/BottomPanel/BottomContainer/AbilityRow/FireballButton", energy >= 40 and crystals >= 15)
	update_single_button("GameUI/BottomPanel/BottomContainer/AbilityRow/HealButton", energy >= 30 and crystals >= 10)
	update_single_button("GameUI/BottomPanel/BottomContainer/AbilityRow/ShieldButton", energy >= 50 and crystals >= 20)
	update_single_button("GameUI/BottomPanel/BottomContainer/AbilityRow/LightningButton", energy >= 60 and crystals >= 25)
	
	# Специальные кнопки
	update_single_button("GameUI/BottomPanel/BottomContainer/SpecialRow/UpgradeButton", energy >= 150 and crystals >= 50)
	update_single_button("GameUI/BottomPanel/BottomContainer/SpecialRow/NukeButton", energy >= 200 and crystals >= 100)

func update_single_button(button_path: String, can_afford: bool):
	if has_node(button_path):
		var button = get_node(button_path)
		if can_afford:
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			button.modulate = Color(0.5, 0.5, 0.5, 0.7)
		button.disabled = not can_afford

func enable_hero_summon():
	# Активируем кнопку призыва героя
	var hero_button = get_node("GameUI/BottomPanel/BottomContainer/AbilityRow/HeroButton")
	if hero_button:
		hero_button.disabled = false
		hero_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		hero_button.text = "🦸\nГЕРОЙ\n⏰ Готов!"
		print("🦸 Кнопка призыва героя активирована!")

func _input(event):
	# Обновляем позицию призрачного предпросмотра
	if is_dragging and ghost_preview:
		if event is InputEventMouseMotion:
			var mouse_pos = get_viewport().get_mouse_position()
			ghost_preview.position = mouse_pos - ghost_preview.size / 2
			
			# Меняем цвет в зависимости от валидности позиции
			var can_build = can_build_at_position(mouse_pos)
			if can_build:
				ghost_preview.color = get_building_color(drag_type)
				ghost_preview.color.a = 0.7
			else:
				ghost_preview.color = Color.RED
				ghost_preview.color.a = 0.5

func create_ghost_preview(building_type: String):
	# Создаем призрачный предпросмотр здания
	ghost_preview = ColorRect.new()
	ghost_preview.size = Vector2(60, 60)
	ghost_preview.color = get_building_color(building_type)
	ghost_preview.color.a = 0.5
	ghost_preview.z_index = 100
	
	# Добавляем иконку здания
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

func get_building_color(building_type: String) -> Color:
	match building_type:
		"barracks": return Color.CYAN
		"tower": return Color.ORANGE
		"training_camp": return Color.GOLD
		"magic_academy": return Color.MAGENTA
		"collector_facility": return Color.GREEN
		_: return Color.WHITE

func get_building_emoji(building_type: String) -> String:
	match building_type:
		"barracks": return "🏰"
		"tower": return "🗼"
		"training_camp": return "🎖️"
		"magic_academy": return "🔮"
		"collector_facility": return "🏃"
		_: return "🏗️"

func can_build_at_position(screen_pos: Vector2) -> bool:
	# Можно строить только в нижней половине экрана (игрок)
	var screen_size = get_viewport().get_visible_rect().size
	return screen_pos.y > screen_size.y * 0.5

func _on_start_game_pressed():
	print("🚀 === НАЧАЛО ИГРЫ С КОМПАКТНЫМ UI ===")
	main_menu.visible = false
	game_ui.visible = true
	
	# Показываем инструкции
	var instructions = get_node("GameUI/Instructions")
	if instructions:
		instructions.visible = true
	
	start_battle.emit()
	print("🎮 Игра с компактным UI запущена!")

func _on_exit_pressed():
	print("🚪 Выход из игры")
	get_tree().quit()

func show_main_menu():
	# Возврат в главное меню
	main_menu.visible = true
	game_ui.visible = false
