# Main.gd   (attached to Main.tscn root)
extends Node2D

# ------------------------------------------------------------------------
# Preload the reusable scenes just once
const ARENA_SCENE  : PackedScene = preload("res://scenes/Arena.tscn")
const PLAYER_SCENE : PackedScene = preload("res://scenes/Player.tscn")
const HUD_SCENE    : PackedScene = preload("res://scenes/HUD.tscn")
const CURSOR_TEX := preload("res://sprites/crosshair.png")   # 32×32 PNG

const LEVEL_CONFIGS : Array[ArenaConfig] = [ 	preload("res://levels/lvl1.tres"), 
												preload("res://levels/lvl2.tres"),
												preload("res://levels/lvl3.tres"),
												preload("res://levels/lvl4.tres")] 

const LEVEL_CONFIG : ArenaConfig = preload("res://levels/lvl1.tres")

const ARENA_OFFSET : Vector2 = Vector2(224, -112)     # 14 tiles north-east
const ARENA_HALF   : Vector2 = ARENA_OFFSET * 0.5     # centre of that room
const XFADE_TIME : float = 1.0          # seconds for cross-fade
const PAN_TIME  : float = 0.8           # camera glide after fade-out


var current_level : int = 0
var arena         : Node2D
var player        : CharacterBody2D


@onready var fade_rect : ColorRect = $FadeLayer/FadeRect
@onready var cam       : Camera2D  = $Camera2D

# ------------------------------------------------------------------------
func _ready() -> void:
	Input.set_custom_mouse_cursor(CURSOR_TEX,
		Input.CURSOR_ARROW,
		CURSOR_TEX.get_size() / 2)
		
		
	_load_level(current_level)
	
func _load_level(idx:int) -> void:
	var cfg = LEVEL_CONFIGS[idx]
	arena = ARENA_SCENE.instantiate()
	arena.enemy_scenes  = cfg.enemy_scenes
	arena.enemy_offsets = cfg.enemy_offsets
	add_child(arena)

	arena.wall_broken.connect(_on_wall_broken)

	if player == null:
		player = PLAYER_SCENE.instantiate()
		add_child(player)
		add_child(HUD_SCENE.instantiate())
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed   = 8
		cam.zoom = Vector2.ONE * 2
		cam.make_current()

	var spawn := arena.get_node("PlayerSpawn") as Node2D
	player.global_position = spawn.global_position
	player.visible = true
	player.set_process_input(true)

# ─────────────────────────  WALL BREAK TRIGGER  ────────────────
func _on_wall_broken() -> void:
	player.set_process_input(false)
	#player.visible = false

	var next_idx := current_level + 1
	if next_idx >= LEVEL_CONFIGS.size():
		push_warning("No more levels!"); return

	var next_cfg : ArenaConfig = LEVEL_CONFIGS[next_idx]
	var next_arena := ARENA_SCENE.instantiate()
	next_arena.enemy_scenes  = next_cfg.enemy_scenes
	next_arena.enemy_offsets = next_cfg.enemy_offsets
	next_arena.modulate.a = 0.0
	next_arena.global_position = arena.global_position + ARENA_OFFSET
	add_child(next_arena)

	# Position next arena one screen to the right of current
	# (adapt if you stack vertically or use different spacing)
	next_arena.global_position = arena.global_position + ARENA_OFFSET

	# Tween sequence:  fade out + pan, then fade in
	var tw := create_tween()

	# simultaneous cross-fade (arena → 0, next_arena → 1)
	tw.tween_property(arena, "modulate:a", 0.0, XFADE_TIME)
	tw.parallel().tween_property(next_arena, "modulate:a", 1.0, XFADE_TIME)

	# after XFADE_TIME, swap arenas and start the camera glide
	tw.tween_callback(Callable(self, "_swap_arenas").bind(next_arena, next_idx))\
	   .set_delay(XFADE_TIME)

	# pan runs in parallel with the rest of the timeline
	tw.parallel().tween_property(
			cam, "global_position",
			next_arena.global_position + ARENA_HALF,
			PAN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			
	tw.tween_callback(Callable(arena, "activate_enemies")).set_delay(PAN_TIME)
	tw.tween_callback(Callable(self, "_resume_player")).set_delay(PAN_TIME)

	
func _swap_arenas(next_arena: Node2D, next_idx:int) -> void:
	arena.queue_free()
	arena = next_arena
	current_level = next_idx
	arena.wall_broken.connect(_on_wall_broken)

	# place player at new spawn
	var spawn := arena.get_node("PlayerSpawn") as Node2D
	player.global_position = spawn.global_position
	# keep camera parented to player; its global_position already set by tween

func _resume_player() -> void:
	player.visible = true
	player.set_process_input(true)
	
	
## 1) Instantiate the arena and inject the enemy lists
	#var arena := ARENA_SCENE.instantiate()
	#arena.enemy_scenes  = LEVEL_CONFIG.enemy_scenes
	#arena.enemy_offsets = LEVEL_CONFIG.enemy_offsets
	#add_child(arena)
#
	## 2) Spawn player & HUD
	#var player := PLAYER_SCENE.instantiate()
	#add_child(player)
	#add_child(HUD_SCENE.instantiate())
#
	## 3) Position player at the arena’s PlayerSpawn marker
	#var spawn := arena.get_node("PlayerSpawn") as Node2D
	#player.global_position = spawn.global_position
#
	## 4) Camera setup
	#$Camera2D.position_smoothing_enabled = true
	#$Camera2D.position_smoothing_speed   = 8.0
	#$Camera2D.zoom = Vector2(3, 3)
	#
	#Input.set_custom_mouse_cursor(CURSOR_TEX,
		#Input.CURSOR_ARROW,
		#CURSOR_TEX.get_size() / 2)
	##Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
#
	## Re-parent the camera to the player so it follows automatically
	#player.add_child($Camera2D)
	#$Camera2D.make_current()
