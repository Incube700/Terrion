extends CharacterBody2D

@onready var area = $Area2D

func _ready():
	area.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name.begins_with("Crystal"):
		var main = get_tree().get_first_node_in_group("main")
		if main:
			main.resources += 10
			print("Кристалл собран! Ресурсы: ", main.resources)
		body.queue_free() 