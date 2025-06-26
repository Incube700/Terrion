extends CanvasLayer

signal start_battle

@onready var player_info = $PlayerInfo
@onready var enemy_info = $EnemyInfo
@onready var start_button = $StartButton

func _ready():
	start_button.pressed.connect(_on_start_pressed)

func _on_start_pressed():
	emit_signal("start_battle")

func update_info(player_hp, player_res, enemy_hp, enemy_res):
	player_info.text = "Player: %d HP | %d Resources" % [player_hp, player_res]
	enemy_info.text = "Enemy: %d HP | %d Resources" % [enemy_hp, enemy_res] 
