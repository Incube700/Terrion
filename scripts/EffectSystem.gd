class_name EffectSystem
extends Node

# EffectSystem — система визуальных эффектов для TERRION
# Управляет партиклами, анимациями и визуальными эффектами боя

var battle_manager = null

# Префабы эффектов
# var explosion_effect_scene = preload("res://effects/ExplosionEffect.tscn")
# var hit_effect_scene = preload("res://effects/HitEffect.tscn")

func _ready():
	print("✨ Система эффектов инициализирована")

# Эффект взрыва при смерти юнита
func create_explosion_effect(position: Vector3, team: String = "neutral"):
	var explosion = create_simple_explosion()
	explosion.position = position
	
	# Цвет взрыва по команде
	var color = Color.ORANGE
	if team == "player":
		color = Color.CYAN
	elif team == "enemy":
		color = Color.RED
	
	set_particle_color(explosion, color)
	
	if battle_manager:
		battle_manager.add_child(explosion)
	else:
		get_parent().add_child(explosion)
	
	# Автоудаление через 2 секунды
	explosion.get_tree().create_timer(2.0).timeout.connect(func(): explosion.queue_free())

# Эффект попадания при атаке
func create_hit_effect(position: Vector3, damage: int):
	var hit = create_simple_hit_effect()
	hit.position = position
	
	# Интенсивность эффекта зависит от урона
	var intensity = clamp(damage / 50.0, 0.3, 2.0)
	set_particle_amount(hit, int(10 * intensity))
	
	if battle_manager:
		battle_manager.add_child(hit)
	else:
		get_parent().add_child(hit)
	
	# Автоудаление через 1 секунду
	hit.get_tree().create_timer(1.0).timeout.connect(func(): hit.queue_free())

# Эффект лечения
func create_heal_effect(position: Vector3):
	var heal = create_simple_heal_effect()
	heal.position = position
	
	if battle_manager:
		battle_manager.add_child(heal)
	else:
		get_parent().add_child(heal)
	
	# Автоудаление через 1.5 секунды
	heal.get_tree().create_timer(1.5).timeout.connect(func(): heal.queue_free())

# Эффект спавна юнита
func create_spawn_effect(position: Vector3, team: String):
	var spawn = create_simple_spawn_effect()
	spawn.position = position
	
	var color = Color.WHITE
	if team == "player":
		color = Color.CYAN
	elif team == "enemy":
		color = Color.RED
	
	set_particle_color(spawn, color)
	
	if battle_manager:
		battle_manager.add_child(spawn)
	else:
		get_parent().add_child(spawn)
	
	# Автоудаление через 1 секунду
	spawn.get_tree().create_timer(1.0).timeout.connect(func(): spawn.queue_free())

# Создание простого эффекта взрыва
func create_simple_explosion() -> GPUParticles3D:
	var particles = GPUParticles3D.new()
	
	# Настройка материала частиц
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = Color.ORANGE
	
	particles.process_material = material
	particles.amount = 50
	particles.lifetime = 1.5
	particles.explosiveness = 1.0
	particles.emitting = true
	
	# Простой меш для частиц
	var mesh = SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	particles.draw_pass_1 = mesh
	
	return particles

# Создание эффекта попадания
func create_simple_hit_effect() -> GPUParticles3D:
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
	particles.emitting = true
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	particles.draw_pass_1 = mesh
	
	return particles

# Создание эффекта лечения
func create_simple_heal_effect() -> GPUParticles3D:
	var particles = GPUParticles3D.new()
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 4.0
	material.gravity = Vector3(0, -2.0, 0)
	material.scale_min = 0.08
	material.scale_max = 0.2
	material.color = Color.GREEN
	
	particles.process_material = material
	particles.amount = 30
	particles.lifetime = 1.2
	particles.explosiveness = 0.8
	particles.emitting = true
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	particles.draw_pass_1 = mesh
	
	return particles

# Создание эффекта спавна
func create_simple_spawn_effect() -> GPUParticles3D:
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
	particles.emitting = true
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	particles.draw_pass_1 = mesh
	
	return particles

# Вспомогательные функции
func set_particle_color(particles: GPUParticles3D, color: Color):
	if particles.process_material and particles.process_material is ParticleProcessMaterial:
		particles.process_material.color = color

# Эффект генерации ресурсов от кристалла
func create_resource_generation_effect(position: Vector3, resource_amount: int):
	var resource_effect = create_simple_resource_effect()
	resource_effect.position = position
	
	# Интенсивность эффекта зависит от количества ресурсов
	var intensity = clamp(resource_amount / 10.0, 0.5, 2.0)
	set_particle_amount(resource_effect, int(15 * intensity))
	
	if battle_manager:
		battle_manager.add_child(resource_effect)
	else:
		get_parent().add_child(resource_effect)
	
	# Автоудаление через 1.5 секунды
	resource_effect.get_tree().create_timer(1.5).timeout.connect(func(): resource_effect.queue_free())

# Создание эффекта генерации ресурсов
func create_simple_resource_effect() -> GPUParticles3D:
	var particles = GPUParticles3D.new()
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 6.0
	material.gravity = Vector3(0, -2.0, 0)
	material.scale_min = 0.08
	material.scale_max = 0.2
	material.color = Color.CYAN  # Цвет энергии
	
	particles.process_material = material
	particles.amount = 20
	particles.lifetime = 1.2
	particles.explosiveness = 0.6
	particles.emitting = true
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	particles.draw_pass_1 = mesh
	
	return particles

func set_particle_amount(particles: GPUParticles3D, amount: int):
	if particles:
		particles.amount = amount

# Эффект для способностей
func create_ability_effect(position: Vector3, ability_name: String):
	match ability_name:
		"fireball":
			create_fireball_effect(position)
		"heal_wave":
			create_heal_wave_effect(position)
		"shield_barrier":
			create_shield_effect(position)
		"lightning_storm":
			create_lightning_effect(position)
		_:
			create_explosion_effect(position)

func create_fireball_effect(position: Vector3):
	var fireball = create_simple_explosion()
	fireball.position = position
	set_particle_color(fireball, Color.ORANGE_RED)
	
	if battle_manager:
		battle_manager.add_child(fireball)
	else:
		get_parent().add_child(fireball)
	
	fireball.get_tree().create_timer(2.0).timeout.connect(func(): fireball.queue_free())

func create_heal_wave_effect(position: Vector3):
	var heal_wave = create_simple_heal_effect()
	heal_wave.position = position
	set_particle_amount(heal_wave, 60)  # Больше частиц для волны
	
	if battle_manager:
		battle_manager.add_child(heal_wave)
	else:
		get_parent().add_child(heal_wave)
	
	heal_wave.get_tree().create_timer(2.5).timeout.connect(func(): heal_wave.queue_free())

func create_shield_effect(position: Vector3):
	var shield = GPUParticles3D.new()
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 1)
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 2.0
	material.gravity = Vector3.ZERO
	material.scale_min = 0.2
	material.scale_max = 0.4
	material.color = Color.CYAN
	
	shield.process_material = material
	shield.amount = 40
	shield.lifetime = 3.0
	shield.explosiveness = 0.3
	shield.emitting = true
	shield.position = position
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.3
	shield.draw_pass_1 = mesh
	
	if battle_manager:
		battle_manager.add_child(shield)
	else:
		get_parent().add_child(shield)
	
	shield.get_tree().create_timer(3.0).timeout.connect(func(): shield.queue_free())

func create_lightning_effect(position: Vector3):
	var lightning = GPUParticles3D.new()
	
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, -1, 0)
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 20.0
	material.gravity = Vector3(0, -15.0, 0)
	material.scale_min = 0.05
	material.scale_max = 0.1
	material.color = Color(0.7, 1.0, 0.2)  # Ярко-лаймовый для молнии
	
	lightning.process_material = material
	lightning.amount = 80
	lightning.lifetime = 1.0
	lightning.explosiveness = 1.0
	lightning.emitting = true
	lightning.position = position + Vector3(0, 10, 0)  # Начинаем сверху
	
	var mesh = SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	lightning.draw_pass_1 = mesh
	
	if battle_manager:
		battle_manager.add_child(lightning)
	else:
		get_parent().add_child(lightning)
	
	lightning.get_tree().create_timer(2.0).timeout.connect(func(): lightning.queue_free()) 
 
