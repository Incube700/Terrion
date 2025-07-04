# GameOver.gd - Экран окончания игры
# Показывает результат битвы, статистику и кнопки для продолжения

extends Control

signal restart_game
signal exit_game

var winner: String = ""
var battle_stats: Dictionary = {}
var balance_report: Dictionary = {}

@onready var result_label: Label = $VBoxContainer/ResultLabel
@onready var battle_duration_label: Label = $VBoxContainer/StatsContainer/BattleDuration
@onready var units_spawned_label: Label = $VBoxContainer/StatsContainer/UnitsSpawned
@onready var units_killed_label: Label = $VBoxContainer/StatsContainer/UnitsKilled
@onready var buildings_built_label: Label = $VBoxContainer/StatsContainer/BuildingsBuilt
@onready var restart_button: Button = $VBoxContainer/ButtonsContainer/RestartButton
@onready var exit_button: Button = $VBoxContainer/ButtonsContainer/ExitButton

func _ready():
	# Подключаем сигналы кнопок
	restart_button.pressed.connect(_on_restart_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# Скрываем экран по умолчанию
	visible = false

# Установка победителя
func set_winner(winner_team: String):
	winner = winner_team
	
	if winner == "player":
		result_label.text = "ПОБЕДА!"
		result_label.modulate = Color.GREEN
	else:
		result_label.text = "ПОРАЖЕНИЕ"
		result_label.modulate = Color.RED
	
	print("🎮 Установлен победитель: ", winner)

# Установка статистики битвы
func set_battle_stats(stats: Dictionary):
	battle_stats = stats
	
	# Форматируем длительность битвы
	var duration_seconds = stats.get("battle_duration", 0.0)
	var minutes = int(duration_seconds) / 60
	var seconds = int(duration_seconds) % 60
	battle_duration_label.text = "Длительность битвы: %d:%02d" % [minutes, seconds]
	
	# Статистика юнитов
	var player_units = stats.get("units_spawned", {}).get("player", 0)
	var enemy_units = stats.get("units_spawned", {}).get("enemy", 0)
	units_spawned_label.text = "Создано юнитов: %d (игрок) / %d (враг)" % [player_units, enemy_units]
	
	# Уничтоженные враги
	var player_kills = stats.get("units_killed", {}).get("enemy", 0)
	units_killed_label.text = "Уничтожено врагов: %d" % player_kills
	
	# Построенные здания
	var player_buildings = stats.get("buildings_built", {}).get("player", 0)
	var enemy_buildings = stats.get("buildings_built", {}).get("enemy", 0)
	buildings_built_label.text = "Построено зданий: %d (игрок) / %d (враг)" % [player_buildings, enemy_buildings]
	
	print("📊 Статистика битвы установлена")

# Установка отчёта по балансу
func set_balance_report(report: Dictionary):
	balance_report = report
	print("📈 Отчёт по балансу установлен")

# Показ экрана
func show_screen():
	visible = true
	print("🎮 Экран окончания игры показан")

# Скрытие экрана
func hide_screen():
	visible = false
	print("🎮 Экран окончания игры скрыт")

# Обработка нажатия кнопки "Начать заново"
func _on_restart_pressed():
	print("🔄 Перезапуск игры...")
	restart_game.emit()

# Обработка нажатия кнопки "Выход"
func _on_exit_pressed():
	print("🚪 Выход из игры...")
	exit_game.emit() 