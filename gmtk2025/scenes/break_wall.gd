extends Node2D
signal wall_broken

@export var open_door_texture : Texture2D
@export var break_anim_time   : float = 0.25   # rubble emission time

var breakable : bool = false

@onready var wall_sprite  : Sprite2D          = $WallSprite
@onready var explode_anim : AnimatedSprite2D  = $ExplodeAnim
@onready var rubble       : CPUParticles2D    = $RubbleParticles
@onready var wall_col     : CollisionShape2D  = $CollisionShape2D

# ---- called by Arena when arena_cleared fires ---------------------------
func enable_break() -> void:
	breakable = true
	print("breakable")
	#wall_sprite.modulate = Color(1, 1, 1, 0.7)   # slight highlight

# ---- Punch detection ----------------------------------------------------
func _on_PunchDet_area_entered(body: PhysicsBody2D) -> void:
	print("punchdet saw ", body)
	if breakable and body.is_in_group("player_attack"):
		_break()

# ---- Break sequence -----------------------------------------------------
func _break() -> void:
	breakable = false
	wall_col.disabled = true     # let player walk through
	$PunchDet.monitoring = false

	# 1) hide cracked wall, play explosion
	explode_anim.visible = true
	explode_anim.play("boom")    # frames: flash, explosion

	# 2) emit rubble particles
	rubble.emitting = true
	wall_sprite.texture = open_door_texture
	wall_sprite.modulate.a = 1
	wall_sprite.visible = true
	await explode_anim.animation_finished   # waits ≈ 0.16 s

	# 3) stop particles after a short burst
	await get_tree().create_timer(break_anim_time).timeout
	rubble.emitting = false

	# 4) swap sprite to open door
	
	
	explode_anim.visible = false

	emit_signal("wall_broken")   # Arena/Main can pan camera now


func _on_punch_det_area_entered(area: Area2D) -> void:
	print("punchdet saw ", area)
	if breakable and area.is_in_group("player_attack"):
		_break()
