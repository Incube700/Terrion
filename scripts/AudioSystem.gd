class_name AudioSystem
extends Node

# AudioSystem — система звуков для TERRION
# Управляет звуковыми эффектами боя, интерфейса и окружения

var battle_manager = null
var audio_players = []  # Пул аудиоплееров
var max_audio_players = 10  # Максимальное количество одновременных звуков

func _ready():
	# Создаем пул аудиоплееров
	for i in range(max_audio_players):
		var player = AudioStreamPlayer3D.new()
		audio_players.append(player)
		add_child(player)
	
	print("🔊 Аудиосистема инициализирована")

# Воспроизведение звукового эффекта
func play_sound_effect(sound_name: String, position: Vector3 = Vector3.ZERO, volume: float = 0.0):
	var available_player = get_available_audio_player()
	if not available_player:
		return  # Все плееры заняты
	
	var sound_stream = get_sound_stream(sound_name)
	if not sound_stream:
		return  # Звук не найден
	
	available_player.stream = sound_stream
	available_player.global_position = position
	available_player.volume_db = volume
	available_player.play()
	
	print("🔊 Воспроизводится звук: ", sound_name)

# Получение свободного аудиоплеера
func get_available_audio_player() -> AudioStreamPlayer3D:
	for player in audio_players:
		if not player.playing:
			return player
	print("❌ Нет свободных аудиоплееров!")
	return null

# Получение звукового потока по имени
func get_sound_stream(sound_name: String) -> AudioStream:
	match sound_name:
		"unit_spawn":
			return create_spawn_sound()
		"unit_attack":
			return create_attack_sound()
		"unit_death":
			return create_death_sound()
		"building_place":
			return create_building_sound()
		"ability_cast":
			return create_ability_sound()
		"button_click":
			return create_click_sound()
		"energy_gain":
			return create_energy_sound()
		_:
			print("❌ Не найден звуковой поток для: ", sound_name)
			return null

# Создание процедурных звуков
func create_spawn_sound() -> AudioStream:
	# Простой звук спавна (высокий тон)
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.5
	return generator

func create_attack_sound() -> AudioStream:
	# Звук атаки (средний тон)
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.3
	return generator

func create_death_sound() -> AudioStream:
	# Звук смерти (низкий тон)
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.8
	return generator

func create_building_sound() -> AudioStream:
	# Звук постройки (строительный)
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 1.0
	return generator

func create_ability_sound() -> AudioStream:
	# Звук способности (магический)
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.6
	return generator

func create_click_sound() -> AudioStream:
	# Звук клика (короткий)
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.1
	return generator

func create_energy_sound() -> AudioStream:
	# Звук получения энергии (приятный)
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.4
	return generator

# Удобные функции для частых звуков
func play_unit_spawn_sound(position: Vector3):
	play_sound_effect("unit_spawn", position, -10.0)

func play_unit_attack_sound(position: Vector3):
	play_sound_effect("unit_attack", position, -15.0)

func play_unit_death_sound(position: Vector3):
	play_sound_effect("unit_death", position, -12.0)

func play_building_place_sound(position: Vector3):
	play_sound_effect("building_place", position, -8.0)

func play_ability_cast_sound(position: Vector3):
	play_sound_effect("ability_cast", position, -5.0)

func play_button_click_sound():
	play_sound_effect("button_click", Vector3.ZERO, -20.0)

func play_energy_gain_sound():
	play_sound_effect("energy_gain", Vector3.ZERO, -18.0) 