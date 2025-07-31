extends CharacterBody2D

@export var MOVE_SPEED: float = 250.0

var is_attacking := false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D       = $SwordHitbox

func _ready() -> void:
	anim.play("idle")
	hitbox.monitoring = false          # only on during swing
	anim.animation_finished.connect(_on_anim_finished)

# ------------------------------------------------------------------------
# Movement ─ converts WASD into 45°-rotated isometric motion
# ------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
	).normalized()

	if is_attacking:
		velocity = Vector2.ZERO         # stay planted while swinging
	else:
		velocity = dir * MOVE_SPEED
		move_and_slide()
		_update_move_anim(dir)

# ------------------------------------------------------------------------
# Input
# ------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and !is_attacking:
		_start_attack()

# ------------------------------------------------------------------------
# Attack helpers
# ------------------------------------------------------------------------
func _start_attack() -> void:
	is_attacking = true
	anim.play("punch")      # plays once
	hitbox.monitoring = true

func _on_anim_finished(name: StringName) -> void:
	if name == "punch":
		hitbox.monitoring = false
		is_attacking = false
		# choose correct post-swing anim based on current input
		var input_vec := Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
		)
		anim.play("idle" if input_vec == Vector2.ZERO else "run")


# ------------------------------------------------------------------------
# Utility
# ------------------------------------------------------------------------
func _update_move_anim(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		if anim.animation != "idle" and !is_attacking:
			anim.play("idle")
	else:
		if anim.animation != "run" and !is_attacking:
			anim.play("run")
