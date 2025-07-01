extends CanvasLayer

# Интерфейс командира TERRION - управление фракцией в космических битвах
# Адаптирован для мобильных устройств с тач-управлением

signal start_battle
signal spawn_soldier
signal build_tower
signal spawn_elite_soldier
signal spawn_crystal_mage
signal spawn_unit_drag(unit_type, screen_pos)
signal build_structure_drag(screen_pos)
signal use_ability(ability_name: String, position: Vector3)

# Сигналы для командиров фракций (используются в расширенной системе рас)
signal summon_commander(position: Vector3)
signal use_faction_ability(ability_name: String, position: Vector3)
signal spawn_collector

var drag_type = ""
var is_dragging = false
var drag_start_pos = Vector2.ZERO

@onready var spawner_panel = $SpawnerPanel

func _ready():
	print("📱 Интерфейс командира TERRION активирован")
	
	# Подключение основных команд
	$Panel/MainButtonContainer/StartButton.pressed.connect(_on_start_operation_pressed)
	$Panel/MainButtonContainer/SpawnSoldierButton.pressed.connect(_on_deploy_unit_pressed)
	$Panel/MainButtonContainer/BuildTowerButton.pressed.connect(_on_construct_facility_pressed)
	$Panel/MainButtonContainer/EliteSoldierButton.pressed.connect(_on_deploy_specialist_pressed)
	$Panel/MainButtonContainer/CrystalMageButton.pressed.connect(_on_deploy_technician_pressed)
	$Panel/MainButtonContainer/CollectorButton.pressed.connect(_on_spawn_collector_pressed)
	
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
	
	# Подключение drag&drop для мобильного управления
	$Panel/MainButtonContainer/SpawnSoldierButton.gui_input.connect(_on_unit_button_input)
	$Panel/MainButtonContainer/BuildTowerButton.gui_input.connect(_on_structure_button_input)

	if spawner_panel:
		spawner_panel.spawner_drag_start.connect(_on_spawner_drag_start)
		spawner_panel.spawner_drag_end.connect(_on_spawner_drag_end)
	
	# Обновление текста кнопок под новый лор
	update_button_texts()

func update_button_texts():
	"""Обновляет текст кнопок под космический лор"""
	$Panel/MainButtonContainer/StartButton.text = "Начать Операцию"
	$Panel/MainButtonContainer/SpawnSoldierButton.text = "Развернуть Войска"
	$Panel/MainButtonContainer/BuildTowerButton.text = "Построить Модуль"
	$Panel/MainButtonContainer/EliteSoldierButton.text = "Элитный Отряд"
	$Panel/MainButtonContainer/CrystalMageButton.text = "Техно-Специалист"
	$Panel/MainButtonContainer/CollectorButton.text = "🏃 Коллектор"
	
	if has_node("AbilityPanel/AbilityContainer"):
		if $AbilityPanel/AbilityContainer.has_node("FireballButton"):
			$AbilityPanel/AbilityContainer/FireballButton.text = "Плазменный Удар"
		if $AbilityPanel/AbilityContainer.has_node("HealButton"):
			$AbilityPanel/AbilityContainer/HealButton.text = "Волна Ремонта"
		if $AbilityPanel/AbilityContainer.has_node("ShieldButton"):
			$AbilityPanel/AbilityContainer/ShieldButton.text = "Энерго-Барьер"
		if $AbilityPanel/AbilityContainer.has_node("LightningButton"):
			$AbilityPanel/AbilityContainer/LightningButton.text = "Ионная Буря"

func _on_start_operation_pressed():
	print("🚀 Командир начинает операцию")
	start_battle.emit()

func _on_deploy_unit_pressed():
	print("⚔️ Развертывание базовых войск")
	spawn_soldier.emit()

func _on_construct_facility_pressed():
	print("🏗️ Строительство оборонительного модуля")
	build_tower.emit()

func _on_deploy_specialist_pressed():
	print("🎖️ Развертывание элитного отряда")
	spawn_elite_soldier.emit()

func _on_deploy_technician_pressed():
	print("🔧 Развертывание техно-специалиста")
	spawn_crystal_mage.emit()

func _on_spawn_collector_pressed():
	print("🟢 Спавн Collector (сборщик ресурсов)")
	spawn_collector.emit()

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
	"""Обновляет состояние кнопок технологий"""
	if has_node("AbilityPanel/AbilityContainer"):
		update_button_state("AbilityPanel/AbilityContainer/FireballButton", energy >= 40, crystals >= 15)
		update_button_state("AbilityPanel/AbilityContainer/HealButton", energy >= 30, crystals >= 10)
		update_button_state("AbilityPanel/AbilityContainer/ShieldButton", energy >= 50, crystals >= 20)
		update_button_state("AbilityPanel/AbilityContainer/LightningButton", energy >= 60, crystals >= 25)

func update_unit_buttons(energy: int, crystals: int):
	"""Обновляет состояние кнопок развертывания войск"""
	update_button_state("Panel/MainButtonContainer/SpawnSoldierButton", energy >= 20, true)
	update_button_state("Panel/MainButtonContainer/EliteSoldierButton", energy >= 30, crystals >= 10)
	update_button_state("Panel/MainButtonContainer/CrystalMageButton", energy >= 25, crystals >= 15)
	update_button_state("Panel/MainButtonContainer/BuildTowerButton", energy >= 60, true)

func update_button_state(button_path: String, has_energy: bool, has_crystals: bool):
	"""Визуальное отображение доступности команд"""
	if has_node(button_path):
		var button = get_node(button_path)
		var can_afford = has_energy and has_crystals
		
		# Изменяем прозрачность для мобильной читаемости
		if can_afford:
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Активная команда
		else:
			button.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Недоступная команда
		
		button.disabled = not can_afford

func _on_unit_button_input(event):
	"""Обработка тач-управления для развертывания войск"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Начало drag-операции
			drag_type = "soldier"
			is_dragging = true
			drag_start_pos = event.position
		else:
			# Завершение drag - развертывание войск
			if is_dragging and drag_type == "soldier":
				spawn_unit_drag.emit("soldier", event.position)
			is_dragging = false
			drag_type = ""

func _on_structure_button_input(event):
	"""Обработка тач-управления для строительства"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Начало drag-операции
			drag_type = "tower"
			is_dragging = true
			drag_start_pos = event.position
		else:
			# Завершение drag - строительство модуля
			if is_dragging and drag_type == "tower":
				build_structure_drag.emit(event.position)
			is_dragging = false
			drag_type = ""

func update_info(player_hp, player_energy, enemy_hp, enemy_energy, player_crystals = 0, enemy_crystals = 0):
	"""Обновление информации о состоянии фракций"""
	$PlayerHUD.text = "Командир | Энергия: %d | Кристаллы: %d | Центр: %d" % [player_energy, player_crystals, player_hp]
	$EnemyHUD.text = "Противник | Энергия: %d | Кристаллы: %d | Центр: %d" % [enemy_energy, enemy_crystals, enemy_hp]
	
	# Обновляем состояние всех команд
	update_ability_buttons(player_energy, player_crystals)
	update_unit_buttons(player_energy, player_crystals)

func _input(event):
	"""Обработка пользовательского ввода для мобильных устройств"""
	if is_dragging:
		if event is InputEventMouseMotion:
			# Можно добавить визуальную обратную связь при drag
			pass 

func _on_spawner_drag_start(spawner_type):
	"""Начало размещения производственного модуля"""
	print("[Интерфейс] Начато размещение модуля: ", spawner_type)

func _on_spawner_drag_end(spawner_type, global_pos):
	"""Завершение размещения производственного модуля"""
	print("[Интерфейс] Модуль размещен: ", spawner_type, " в точке ", global_pos)
	# Передача команды в центральную систему управления
	if get_parent().has_method("on_spawner_drop"):
		get_parent().on_spawner_drop(spawner_type, global_pos)
