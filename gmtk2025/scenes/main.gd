# Main.gd   (attached to Main.tscn root)
extends Node2D

# ------------------------------------------------------------------------
# Preload the reusable scenes just once
const ARENA_SCENE  : PackedScene = preload("res://scenes/Arena.tscn")
const PLAYER_SCENE : PackedScene = preload("res://scenes/Player.tscn")
const HUD_SCENE    : PackedScene = preload("res://scenes/HUD.tscn")

# Load the level-data resource you created
const LEVEL_CONFIG : ArenaConfig = preload("res://levels/lvl1.tres")

# ------------------------------------------------------------------------
func _ready() -> void:
	# 1) Instantiate the arena and inject the enemy lists
	var arena := ARENA_SCENE.instantiate()
	arena.enemy_scenes  = LEVEL_CONFIG.enemy_scenes
	arena.enemy_offsets = LEVEL_CONFIG.enemy_offsets
	add_child(arena)

	# 2) Spawn player & HUD
	var player := PLAYER_SCENE.instantiate()
	add_child(player)
	add_child(HUD_SCENE.instantiate())

	# 3) Position player at the arena’s PlayerSpawn marker
	var spawn := arena.get_node("PlayerSpawn") as Node2D
	player.global_position = spawn.global_position

	# 4) Camera setup
	$Camera2D.position_smoothing_enabled = true
	$Camera2D.position_smoothing_speed   = 8.0
	$Camera2D.zoom = Vector2(2, 2)

	# Re-parent the camera to the player so it follows automatically
	player.add_child($Camera2D)
	$Camera2D.make_current()
