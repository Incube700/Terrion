class_name GameSystem
extends Node

# GameSystem — базовый класс для всех игровых систем TERRION
# Обеспечивает единый интерфейс и общую функциональность

@export var system_name: String = ""
@export var enabled: bool = true

var battle_manager = null
var is_initialized: bool = false

signal system_ready
signal system_error(error_message: String)

func _ready():
	if enabled:
		initialize_system()

# Виртуальная функция для инициализации системы
func initialize_system():
	print("🔧 Инициализация системы: ", system_name)
	is_initialized = true
	system_ready.emit()

# Виртуальная функция для очистки системы
func cleanup_system():
	print("🧹 Очистка системы: ", system_name)
	is_initialized = false

# Безопасное выполнение операций только для инициализированных систем
func safe_execute(operation: Callable, error_msg: String = ""):
	if not is_initialized or not enabled:
		if error_msg:
			print("⚠️ ", error_msg)
		return false
	
	# Выполняем операцию с проверкой
	if operation.is_valid():
		operation.call()
		return true
	else:
		system_error.emit("Ошибка в системе " + system_name + ": " + error_msg)
		return false

# Получение статуса системы
func get_system_status() -> Dictionary:
	return {
		"name": system_name,
		"enabled": enabled,
		"initialized": is_initialized,
		"node_count": get_child_count()
	}

# Включение/выключение системы
func set_system_enabled(value: bool):
	enabled = value
	if not enabled and is_initialized:
		cleanup_system()
	elif enabled and not is_initialized:
		initialize_system() 