extends CanvasLayer

func _ready() -> void:
	# Find the Player and connect once
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_health_changed)
		_on_health_changed(player.health, player.max_health)  # set initial value

func _on_health_changed(current: int, max: int) -> void:
	$HealthLabel.text = "HP: %d / %d" % [current, max]
