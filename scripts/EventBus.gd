class_name EventBus
extends Node

# EventBus — глобальная система событий для TERRION
# Обеспечивает слабую связанность между системами

# Игровые события
signal battle_started
signal battle_ended(winner: String)
signal unit_spawned(team: String, unit_type: String, position: Vector3)
signal unit_killed(team: String, unit_type: String, position: Vector3)
signal building_constructed(team: String, building_type: String, position: Vector3)
signal ability_used(team: String, ability_name: String, position: Vector3)
signal territory_captured(territory_name: String, team: String)
signal resource_gained(team: String, resource_type: String, amount: int)

# Системные события
signal system_initialized(system_name: String)
signal system_error(system_name: String, error_message: String)

# UI события
signal ui_button_clicked(button_name: String)
signal notification_shown(text: String, type: String)

func _ready():
	print("📡 EventBus инициализирован")

# Удобные функции для отправки событий
func emit_battle_started():
	battle_started.emit()
	print("📡 Событие: Битва началась")

func emit_battle_ended(winner: String):
	battle_ended.emit(winner)
	print("📡 Событие: Битва завершена, победитель: ", winner)

func emit_unit_spawned(team: String, unit_type: String, position: Vector3):
	unit_spawned.emit(team, unit_type, position)
	print("📡 Событие: Юнит создан - ", team, " ", unit_type)

func emit_unit_killed(team: String, unit_type: String, position: Vector3):
	unit_killed.emit(team, unit_type, position)
	print("📡 Событие: Юнит убит - ", team, " ", unit_type)

func emit_building_constructed(team: String, building_type: String, position: Vector3):
	building_constructed.emit(team, building_type, position)
	print("📡 Событие: Здание построено - ", team, " ", building_type)

func emit_ability_used(team: String, ability_name: String, position: Vector3):
	ability_used.emit(team, ability_name, position)
	print("📡 Событие: Способность использована - ", team, " ", ability_name)

func emit_territory_captured(territory_name: String, team: String):
	territory_captured.emit(territory_name, team)
	print("📡 Событие: Территория захвачена - ", territory_name, " командой ", team)

func emit_resource_gained(team: String, resource_type: String, amount: int):
	resource_gained.emit(team, resource_type, amount)
	print("📡 Событие: Ресурсы получены - ", team, " +", amount, " ", resource_type)

func emit_system_initialized(system_name: String):
	system_initialized.emit(system_name)
	print("📡 Событие: Система инициализирована - ", system_name)

func emit_system_error(system_name: String, error_message: String):
	system_error.emit(system_name, error_message)
	print("📡 Ошибка системы: ", system_name, " - ", error_message) 