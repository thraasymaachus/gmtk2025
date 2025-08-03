extends Node2D

@export var enemy_scenes : Array[PackedScene] = []   # one per Spawn marker
@export var enemy_offsets: Array[Vector2]   = []     # optional fine-tune
var alive := 0

signal arena_cleared
signal wall_broken

@onready var break_wall := $BreakWall
@onready var arrow      := $Arrow

func _ready() -> void:
	_spawn_from_config()
	
	 # Arrow & wall start disabled
	arrow.flash(false)
	break_wall.enable_break.call_deferred(false)  # keep off
	
func _spawn_from_config() -> void:
	var markers := $SpawnPoints.get_children()

	for i in enemy_scenes.size():
		var scene := enemy_scenes[i]
		if scene == null:
			continue                                    # skip empty slots

		var spawn := markers[i]
		var enemy  := scene.instantiate()

		# local coordinates inside the arena
		enemy.position = spawn.position
		if i < enemy_offsets.size():
			enemy.position += enemy_offsets[i]

		add_child(enemy)                                # child of this arena
		alive += 1
		enemy.died.connect(_on_enemy_died)
			

func _on_enemy_died():
	alive -= 1
	if alive == 0:
		emit_signal("arena_cleared")
		arrow.flash(true)
		break_wall.enable_break()


func _on_break_wall_wall_broken() -> void:
	arrow.flash(false)          # hide arrow
	emit_signal("wall_broken")  # let Main.gd handle camera pan / next level
	
