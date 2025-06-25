extends Node2D

@onready var anim = $AnimationPlayer

func _ready():
	anim.play("flash")
	anim.animation_finished.connect(_on_anim_finished)

func _on_anim_finished(_name):
	queue_free() 