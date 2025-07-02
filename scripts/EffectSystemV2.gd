class_name EffectSystemV2
extends GameSystem

# EffectSystemV2 — улучшенная система визуальных эффектов для TERRION
# Наследует от GameSystem для единообразия архитектуры

# Пулы эффектов для оптимизации
var explosion_pool: Array[GPUParticles3D] = []
var hit_pool: Array[GPUParticles3D] = []
var spawn_pool: Array[GPUParticles3D] = []

var max_pool_size: int = 20
var active_effects: Array[GPUParticles3D] = []

func _init():
	system_name = "EffectSystem"

func initialize_system():
	super.initialize_system()
	
	# Создаем пулы эффектов
	create_effect_pools()
	
	# Подключаемся к EventBus
	if has_node("/root/EventBus"):
		var event_bus = get_node("/root/EventBus")
		event_bus.unit_spawned.connect(_on_unit_spawned)
		event_bus.unit_killed.connect(_on_unit_killed)
		event_bus.building_constructed.connect(_on_building_constructed)
		event_bus.ability_used.connect(_on_ability_used)
	
	print("✨ EffectSystemV2 инициализирована с пулами эффектов")

func create_effect_pools():
	# (documentation comment)
	for i in range(max_pool_size):
		# Пул взрывов
		var explosion = create_explosion_particle()
		explosion.emitting = false
		explosion.visible = false
		explosion_pool.append(explosion)
		add_child(explosion)
		
		# Пул попаданий
		var hit = create_hit_particle()
		hit.emitting = false
		hit.visible = false
		hit_pool.append(hit)
		add_child(hit)
		
		# Пул спавна
		var spawn = create_spawn_particle()
		spawn.emitting = false
		spawn.visible = false
		spawn_pool.append(spawn)
		add_child(spawn)

func get_pooled_effect(pool: Array[GPUParticles3D]) -> GPUParticles3D:
	# (documentation comment)
	for effect in pool:
		if not effect.emitting:
			return effect
	
	# Если все заняты, возвращаем первый (переиспользуем)
	return pool[0] if pool.size() > 0 else null

func play_explosion_effect(position: Vector3, team: String = "neutral"):
	safe_execute(func(): _play_explosion_effect(position, team), 
				"Не удалось воспроизвести эффект взрыва")

func _play_explosion_effect(position: Vector3, team: String):
	var explosion = get_pooled_effect(explosion_pool)
	if not explosion:
		return
	
	explosion.global_position = position
	explosion.visible = true
	
	# Цвет по команде
	var color = Color.ORANGE
	if team == "player":
		color = Color.CYAN
	elif team == "enemy":
		color = Color.RED
	
	set_particle_color(explosion, color)
	explosion.restart()
	
	# Автоскрытие через 2 секунды
	get_tree().create_timer(2.0).timeout.connect(func(): hide_effect(explosion))

func play_hit_effect(position: Vector3, damage: int):
	safe_execute(func(): _play_hit_effect(position, damage),
				"Не удалось воспроизвести эффект попадания")

func _play_hit_effect(position: Vector3, damage: int):
	var hit = get_pooled_effect(hit_pool)
	if not hit:
		return
	
	hit.global_position = position
	hit.visible = true
	
	# Интенсивность зависит от урона
	var intensity = clamp(damage / 50.0, 0.3, 2.0)
	hit.amount = int(20 * intensity)
	
	hit.restart()
	get_tree().create_timer(1.0).timeout.connect(func(): hide_effect(hit))

func play_spawn_effect(position: Vector3, team: String):
	safe_execute(func(): _play_spawn_effect(position, team),
				"Не удалось воспроизвести эффект спавна")

func _play_spawn_effect(position: Vector3, team: String):
	var spawn = get_pooled_effect(spawn_pool)
	if not spawn:
		return
	
	spawn.global_position = position
	spawn.visible = true
	
	var color = Color.WHITE
	if team == "player":
		color = Color.CYAN
	elif team == "enemy":
		color = Color.RED
	
	set_particle_color(spawn, color)
	spawn.restart()
	get_tree().create_timer(1.0).timeout.connect(func(): hide_effect(spawn))

func hide_effect(effect: GPUParticles3D):
	# (documentation comment)
	if effect:
		effect.emitting = false
		effect.visible = false

func set_particle_color(particles: GPUParticles3D, color: Color):
	# (documentation comment)
	if particles.process_material and particles.process_material is ParticleProcessMaterial:
		particles.process_material.color = color

# Создание базовых частиц
func create_explosion_particle() -> GPUParticles3D:
	var particles = GPUParticles3D.new()
	var material = ParticleProcessMaterial.new()
	
	material.direction = Vector3(0, 1, 0)
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = Color.ORANGE
	
	particles.process_material = material
	particles.amount = 50
	particles.lifetime = 1.5
	particles.explosiveness = 1.0
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	particles.draw_pass_1 = mesh
	
	return particles

func create_hit_particle() -> GPUParticles3D:
	var particles = GPUParticles3D.new()
	var material = ParticleProcessMaterial.new()
	
	material.direction = Vector3(0, 1, 0)
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 8.0
	material.gravity = Vector3(0, -5.0, 0)
	material.scale_min = 0.05
	material.scale_max = 0.15
	material.color = Color.YELLOW
	
	particles.process_material = material
	particles.amount = 20
	particles.lifetime = 0.8
	particles.explosiveness = 1.0
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh
	
	return particles

func create_spawn_particle() -> GPUParticles3D:
	var particles = GPUParticles3D.new()
	var material = ParticleProcessMaterial.new()
	
	material.direction = Vector3(0, 1, 0)
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 10.0
	material.gravity = Vector3(0, -3.0, 0)
	material.scale_min = 0.1
	material.scale_max = 0.25
	material.color = Color.WHITE
	
	particles.process_material = material
	particles.amount = 25
	particles.lifetime = 1.0
	particles.explosiveness = 1.0
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	particles.draw_pass_1 = mesh
	
	return particles

# Обработчики событий EventBus
func _on_unit_spawned(_team: String, _unit_type: String, position: Vector3):
	play_spawn_effect(position, _team)

func _on_unit_killed(_team: String, _unit_type: String, position: Vector3):
	play_explosion_effect(position, _team)

func _on_building_constructed(_team: String, _building_type: String, position: Vector3):
	play_spawn_effect(position, _team)

func _on_ability_used(team: String, ability_name: String, position: Vector3):
	# Специальные эффекты для способностей
	match ability_name:
		"fireball":
			play_explosion_effect(position, team)
		"heal_wave":
			play_spawn_effect(position, "neutral")
		_:
			play_hit_effect(position, 25)

func cleanup_system():
	# (documentation comment)
	super.cleanup_system()
	
	# Очищаем пулы
	for pool in [explosion_pool, hit_pool, spawn_pool]:
		for effect in pool:
			if is_instance_valid(effect):
				effect.queue_free()
		pool.clear()
	
	active_effects.clear()
	print("🧹 EffectSystemV2 очищена") 