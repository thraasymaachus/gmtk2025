extends Node2D     # or Marker2D

@export var spider_scene := preload("res://scenes/enemies/Spider.tscn")
@export var spawn_interval : float = 8.0   # seconds
@export var max_alive      : int   = 3

var _timer : Timer
var _alive := 0

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = spawn_interval
	_timer.one_shot = false
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	_timer.start()

func _on_timeout() -> void:
	if _alive >= max_alive:
		return
	spawn_spider()

func spawn_spider() -> void:
	var spider := spider_scene.instantiate()
	spider.global_position = global_position   # this Node2D’s spot
	get_parent().add_child(spider)             # add to Arena
	_alive += 1
	# Let the spider tell us when it dies so we can spawn another
	spider.tree_exiting.connect( func(): _alive -= 1 )
