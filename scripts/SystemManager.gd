extends Node

# SystemManager — менеджер для безопасной работы с игровыми системами
# Решает проблемы с типизацией и инициализацией

var systems = {}
var battle_manager = null

func _ready():
	print("🔧 SystemManager инициализирован")

func init_system(system_name: String, system_script_path: String, parent_node: Node):
	# Безопасная инициализация системы без строгой типизации
	print("🔧 Инициализация системы: ", system_name)
	
	# Загружаем скрипт системы
	var system_script = load(system_script_path)
	if not system_script:
		print("❌ Не удалось загрузить скрипт: ", system_script_path)
		return null
	
	# Создаем экземпляр
	var system_instance = system_script.new()
	if not system_instance:
		print("❌ Не удалось создать экземпляр: ", system_name)
		return null
	
	system_instance.name = system_name
	
	# Устанавливаем battle_manager если есть
	if "battle_manager" in system_instance:
		system_instance.battle_manager = battle_manager
	
	# Добавляем в сцену
	parent_node.add_child(system_instance)
	
	# Сохраняем ссылку
	systems[system_name] = system_instance
	
	print("✅ Система ", system_name, " инициализирована")
	return system_instance

func get_system(system_name: String):
	# Получение системы по имени
	return systems.get(system_name, null)

func is_system_ready(system_name: String) -> bool:
	# Проверка готовности системы
	var system = get_system(system_name)
	return system != null

func call_system_method(system_name: String, method_name: String, args: Array = []):
	# Безопасный вызов метода системы
	var system = get_system(system_name)
	if system and system.has_method(method_name):
		if args.size() == 0:
			return system.call(method_name)
		else:
			return system.callv(method_name, args)
	else:
		print("⚠️ Метод ", method_name, " недоступен в системе ", system_name)
		return null

func init_all_systems(parent_node: Node):
	# Инициализация всех систем
	battle_manager = parent_node
	
	var systems_to_init = [
		{"name": "EffectSystem", "path": "res://scripts/EffectSystem.gd"},
		{"name": "AudioSystem", "path": "res://scripts/AudioSystem.gd"},
		{"name": "NotificationSystem", "path": "res://scripts/NotificationSystem.gd"},
		{"name": "StatisticsSystem", "path": "res://scripts/StatisticsSystem.gd"}
	]
	
	for system_data in systems_to_init:
		init_system(system_data.name, system_data.path, parent_node)
	
	print("✅ Все системы инициализированы через SystemManager")

func cleanup_all_systems():
	# Очистка всех систем
	for system_name in systems:
		var system = systems[system_name]
		if system and is_instance_valid(system):
			if system.has_method("cleanup_system"):
				system.cleanup_system()
			system.queue_free()
	
	systems.clear()
	print("🧹 Все системы очищены") 