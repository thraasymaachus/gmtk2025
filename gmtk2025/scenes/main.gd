# Main.gd attached to Main.tscn root
extends Node2D

@onready var arena   := preload("res://scenes/Arena.tscn").instantiate()
@onready var player  := preload("res://scenes/Player.tscn").instantiate()

func _ready() -> void:
	add_child(arena)
	add_child(player)

	var spawn := arena.get_node("PlayerSpawn")
	player.global_position = spawn.global_position

	# make the Camera2D follow smoothly
	$Camera2D.position_smoothing_enabled = true
	$Camera2D.position_smoothing_speed   = 8.0

	$Camera2D.make_current()
	$Camera2D.zoom = Vector2(3, 3)

	# If the Camera2D is meant to track the player:
	player.add_child($Camera2D)   # keep camera centered on player node
