extends CharacterBody2D

@export var MOVE_SPEED: float = 200.0

@export var max_health : int = 10          # tweak as you like
var health             : int = max_health
var invincible         : bool = false     # simple i-frame flag
@export var i_frames   : float = 0.3      # seconds of invulnerability

var is_attacking := false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D       = $SwordHitbox

const ATTACK_ANIM := "punch"
const PUNCH_DAMAGE := 2

func _ready() -> void:
	anim.play("idle")
	add_to_group("player")
	hitbox.monitoring = false          # only on during swing
	anim.animation_finished.connect(_on_anim_finished)
	anim.frame_changed.connect(_on_frame_changed)

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
	anim.play(ATTACK_ANIM)
	hitbox.monitoring = true

func _on_anim_finished() -> void:

	if anim.animation == ATTACK_ANIM:
		hitbox.monitoring = false
		is_attacking = false

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

func _on_frame_changed() -> void:
	if anim.animation == ATTACK_ANIM:  # ATTACK_ANIM = "punch"
		# Turn on only for frames 2..4 (0-based indexing). Tweak to taste.
		var active := anim.frame >= 0 and anim.frame <= 3
		hitbox.monitoring = active

func _on_animated_sprite_2d_animation_finished() -> void:
	pass # Replace with function body.


func _on_sword_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.take_damage(PUNCH_DAMAGE)
	print("HIT", body)

func take_damage(amount: int) -> void:
	if invincible:
		return
	health -= amount
	invincible = true
	$AnimatedSprite2D.play("hurt")        # optional hurt clip

	if health <= 0:
		_die()
		return

	# reset invincibility after a short delay
	var timer := get_tree().create_timer(i_frames)
	await timer.timeout
	invincible = false

func _die() -> void:
	velocity = Vector2.ZERO
	anim.play("death")
	await anim.animation_finished
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
