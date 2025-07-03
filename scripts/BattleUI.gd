class_name BattleUI
extends CanvasLayer

# Интерфейс командира TERRION - drag&drop строительство зданий
# Солдаты спавнятся из казарм, а не напрямую

signal start_battle
signal build_structure_drag(screen_pos)
signal use_ability(ability_name: String, position: Vector3)
signal summon_hero()
signal use_race_ability(ability_name, position)

var drag_type = ""
var is_dragging = false
var drag_start_pos = Vector2.ZERO
var ghost_preview = null

@onready var main_menu = $MainMenu
@onready var game_panel = $Panel
@onready var ability_panel = $AbilityPanel

func _ready():
	print("🖥️ Интерфейс командира с drag&drop загружается...")
	
	# Подключение кнопок главного меню
	var start_game_button = get_node("MainMenu/MenuContainer/StartGameButton")
	var exit_button = get_node("MainMenu/MenuContainer/ExitButton")
	
	if start_game_button:
		start_game_button.pressed.connect(_on_start_game_pressed)
		print("✅ Кнопка 'Начать игру' подключена")
	
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
		print("✅ Кнопка 'Выход' подключена")

	# Настраиваем кнопки зданий с drag&drop
	setup_building_buttons()
	setup_ability_buttons()
	
	# Добавляем инструкции
	add_drag_drop_instructions()

func setup_building_buttons():
	# Кнопки зданий для drag&drop
	$Panel/MainButtonContainer/SpawnSoldierButton.text = "🏰 КАЗАРМЫ\n💰 80 энергии\nПроизводят солдат"
	$Panel/MainButtonContainer/SpawnSoldierButton.gui_input.connect(_on_barracks_button_input)
	
	$Panel/MainButtonContainer/CollectorButton.text = "🏃 ЦЕНТР КОЛЛЕКТОРОВ\n💰 90⚡ + 15💎\nПроизводят коллекторов"
	$Panel/MainButtonContainer/CollectorButton.gui_input.connect(_on_collector_center_button_input)
	
	$Panel/MainButtonContainer/BuildTowerButton.text = "🗼 БАШНЯ\n💰 60 энергии\nОборона"
	$Panel/MainButtonContainer/BuildTowerButton.gui_input.connect(_on_tower_button_input)
	
	$Panel/MainButtonContainer/EliteSoldierButton.text = "🎖️ ТРЕНИРОВОЧНЫЙ ЛАГЕРЬ\n💰 120⚡ + 20💎\nПроизводят элитных солдат"
	$Panel/MainButtonContainer/EliteSoldierButton.gui_input.connect(_on_training_camp_button_input)
	
	$Panel/MainButtonContainer/CrystalMageButton.text = "🔮 МАГИЧЕСКАЯ АКАДЕМИЯ\n💰 100⚡ + 30💎\nПроизводят магов"
	$Panel/MainButtonContainer/CrystalMageButton.gui_input.connect(_on_magic_academy_button_input)
	
	print("✅ Кнопки зданий настроены на drag&drop")

func setup_ability_buttons():
	# Базовые способности
	if has_node("AbilityPanel/AbilityContainer"):
		if $AbilityPanel/AbilityContainer.has_node("FireballButton"):
			$AbilityPanel/AbilityContainer/FireballButton.text = "🔥 ОГНЕННЫЙ ШАР\n💰 40⚡ + 15💎"
			$AbilityPanel/AbilityContainer/FireballButton.pressed.connect(_on_fireball_ability)
		
		if $AbilityPanel/AbilityContainer.has_node("HealButton"):
			$AbilityPanel/AbilityContainer/HealButton.text = "💚 ЛЕЧЕНИЕ\n💰 30⚡ + 10💎"
			$AbilityPanel/AbilityContainer/HealButton.pressed.connect(_on_heal_ability)
		
		if $AbilityPanel/AbilityContainer.has_node("ShieldButton"):
			$AbilityPanel/AbilityContainer/ShieldButton.text = "🛡️ ЩИТ\n💰 50⚡ + 20💎"
			$AbilityPanel/AbilityContainer/ShieldButton.pressed.connect(_on_shield_ability)
	
	# Кнопка призыва героя (скрыта до выполнения условий)
	create_hero_summon_button()

func create_hero_summon_button():
	# Создаем кнопку призыва героя
	if not has_node("AbilityPanel/AbilityContainer"):
		return
	
	var ability_container = $AbilityPanel/AbilityContainer
	
	var hero_button = Button.new()
	hero_button.name = "HeroSummonButton"
	hero_button.text = "🦸 ПРИЗВАТЬ ГЕРОЯ\n⏰ Нужен алтарь"
	hero_button.size = Vector2(140, 60)
	hero_button.add_theme_font_size_override("font_size", 16)
	hero_button.disabled = true  # Изначально недоступна
	hero_button.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Неактивна
	
	hero_button.pressed.connect(_on_hero_summon_pressed)
	ability_container.add_child(hero_button)
	
	print("🦸 Кнопка призыва героя создана (неактивна)")

# Drag&drop обработчики для зданий
func _on_barracks_button_input(event):
	_handle_building_drag(event, "barracks", $Panel/MainButtonContainer/SpawnSoldierButton)

func _on_collector_center_button_input(event):
	_handle_building_drag(event, "collector_facility", $Panel/MainButtonContainer/CollectorButton)

func _on_tower_button_input(event):
	_handle_building_drag(event, "tower", $Panel/MainButtonContainer/BuildTowerButton)

func _on_training_camp_button_input(event):
	_handle_building_drag(event, "training_camp", $Panel/MainButtonContainer/EliteSoldierButton)

func _on_magic_academy_button_input(event):
	_handle_building_drag(event, "magic_academy", $Panel/MainButtonContainer/CrystalMageButton)

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

func _on_hero_summon_pressed():
	print("🦸 Призыв героя!")
	summon_hero.emit()

func update_info(player_hp, player_energy, enemy_hp, enemy_energy, player_crystals = 0, enemy_crystals = 0):
	# HUD с информацией
	$PlayerHUD.text = "🟦 ИГРОК | ⚡%d | 💎%d | ❤️%d" % [player_energy, player_crystals, player_hp]
	$EnemyHUD.text = "🟥 ВРАГ | ⚡%d | 💎%d | ❤️%d" % [enemy_energy, enemy_crystals, enemy_hp]
	
	# Цветовая индикация
	$PlayerHUD.modulate = Color(0.7, 0.9, 1.0)
	$EnemyHUD.modulate = Color(1.0, 0.7, 0.7)
	
	# Обновляем доступность кнопок
	update_button_availability(player_energy, player_crystals)

func update_button_availability(energy: int, crystals: int):
	# Казармы
	update_single_button("Panel/MainButtonContainer/SpawnSoldierButton", energy >= 80)
	
	# Центр коллекторов
	update_single_button("Panel/MainButtonContainer/CollectorButton", energy >= 90 and crystals >= 15)
	
	# Башня
	update_single_button("Panel/MainButtonContainer/BuildTowerButton", energy >= 60)
	
	# Тренировочный лагерь
	update_single_button("Panel/MainButtonContainer/EliteSoldierButton", energy >= 120 and crystals >= 20)
	
	# Магическая академия
	update_single_button("Panel/MainButtonContainer/CrystalMageButton", energy >= 100 and crystals >= 30)
	
	# Способности
	if has_node("AbilityPanel/AbilityContainer"):
		update_single_button("AbilityPanel/AbilityContainer/FireballButton", energy >= 40 and crystals >= 15)
		update_single_button("AbilityPanel/AbilityContainer/HealButton", energy >= 30 and crystals >= 10)
		update_single_button("AbilityPanel/AbilityContainer/ShieldButton", energy >= 50 and crystals >= 20)

func update_single_button(button_path: String, can_afford: bool):
	if has_node(button_path):
		var button = get_node(button_path)
		if can_afford:
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			button.modulate = Color(0.5, 0.5, 0.5, 0.7)
		button.disabled = not can_afford

func enable_hero_summon():
	# Активируем кнопку призыва героя когда алтарь готов
	var hero_button = get_node_or_null("AbilityPanel/AbilityContainer/HeroSummonButton")
	if hero_button:
		hero_button.disabled = false
		hero_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		hero_button.text = "🦸 ПРИЗВАТЬ ГЕРОЯ\n⏰ Готов!"
		print("🦸 Кнопка призыва героя активирована!")

func add_hero_ability_buttons():
	# Добавляем кнопки способностей героя после его призыва
	if not has_node("AbilityPanel/AbilityContainer"):
		return
	
	var ability_container = $AbilityPanel/AbilityContainer
	
	# Способность 1: Боевой клич
	var battle_cry_button = Button.new()
	battle_cry_button.name = "BattleCryButton"
	battle_cry_button.text = "⚔️ БОЕВОЙ КЛИЧ\n💪 +50% урона"
	battle_cry_button.size = Vector2(140, 60)
	battle_cry_button.add_theme_font_size_override("font_size", 14)
	battle_cry_button.pressed.connect(_on_battle_cry_pressed)
	ability_container.add_child(battle_cry_button)
	
	# Способность 2: Массовое лечение
	var mass_heal_button = Button.new()
	mass_heal_button.name = "MassHealButton"
	mass_heal_button.text = "💚 МАССОВОЕ ЛЕЧЕНИЕ\n🔄 Восстанавливает всех"
	mass_heal_button.size = Vector2(140, 60)
	mass_heal_button.add_theme_font_size_override("font_size", 14)
	mass_heal_button.pressed.connect(_on_mass_heal_pressed)
	ability_container.add_child(mass_heal_button)
	
	# Способность 3: Ударная волна
	var shockwave_button = Button.new()
	shockwave_button.name = "ShockwaveButton"
	shockwave_button.text = "💥 УДАРНАЯ ВОЛНА\n⚡ Область урона"
	shockwave_button.size = Vector2(140, 60)
	shockwave_button.add_theme_font_size_override("font_size", 14)
	shockwave_button.pressed.connect(_on_shockwave_pressed)
	ability_container.add_child(shockwave_button)
	
	print("🦸 Способности героя добавлены!")

func _on_battle_cry_pressed():
	print("⚔️ Боевой клич героя!")
	use_ability.emit("battle_cry", Vector3(0, 0, 10))

func _on_mass_heal_pressed():
	print("💚 Массовое лечение!")
	use_ability.emit("mass_heal", Vector3(0, 0, 10))

func _on_shockwave_pressed():
	print("💥 Ударная волна!")
	use_ability.emit("shockwave", Vector3(0, 0, -10))

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
	print("🚀 === НАЧАЛО ИГРЫ С DRAG&DROP ===")
	main_menu.visible = false
	game_panel.visible = true
	ability_panel.visible = true
	$PlayerHUD.visible = true
	$EnemyHUD.visible = true
	
	# Показываем инструкции
	var instructions = get_node_or_null("DragDropInstructions")
	if instructions:
		instructions.visible = true
	
	start_battle.emit()
	print("🎮 Игра с drag&drop запущена!")

func _on_exit_pressed():
	print("🚪 Выход из игры")
	get_tree().quit()

func add_drag_drop_instructions():
	# Инструкции для drag&drop
	var instructions = Label.new()
	instructions.name = "DragDropInstructions"
	instructions.text = """🎮 DRAG & DROP УПРАВЛЕНИЕ:
🖱️ ПКМ + драг = камера
🎮 Скролл = зум
🏗️ ЗАЖМИ И ПЕРЕТАЩИ кнопку здания!
1️⃣ Зажми кнопку здания
2️⃣ Перетащи на карту
3️⃣ Отпусти = постройка!

🏰 Казармы производят солдат
🦸 Герой: захвати 2 боковых территории!"""
	
	instructions.anchors_preset = Control.PRESET_TOP_RIGHT
	instructions.position = Vector2(-400, 10)
	instructions.size = Vector2(390, 180)
	instructions.add_theme_font_size_override("font_size", 16)
	instructions.add_theme_color_override("font_color", Color.YELLOW)
	instructions.add_theme_color_override("font_shadow_color", Color.BLACK)
	instructions.add_theme_constant_override("shadow_offset_x", 2)
	instructions.add_theme_constant_override("shadow_offset_y", 2)
	instructions.visible = false
	
	add_child(instructions)

func show_main_menu():
	# Возврат в главное меню
	main_menu.visible = true
	game_panel.visible = false
	ability_panel.visible = false
	$PlayerHUD.visible = false
	$EnemyHUD.visible = false
