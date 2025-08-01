extends CharacterBody2D

@export var MOVE_SPEED: float = 200.0

@export var max_health : int = 10          # tweak as you like
var health             : int = max_health
var invincible         : bool = false     # simple i-frame flag
@export var i_frames   : float = 0.3      # seconds of invulnerability

var is_attacking := false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D       = $PunchHitbox
@onready var hurt_shape := $CollisionShape2D

signal health_changed(current: int, max: int)

# ---------- Punch / charge tuning ----------
const ATTACK_ANIM        := "punch"
const CHARGE_ANIM        := "charge"      # loops while holding
const MIN_DAMAGE         := 2             # quick-tap damage
const MAX_DAMAGE         := 6             # fully charged
const MAX_CHARGE_TIME    := 1.0           # seconds to full power

var is_charging          := false
var charge_time          := 0.0           # accumulates while holding
var current_punch_damage := MIN_DAMAGE    # set on release

func _ready() -> void:
	anim.play("idle")
	add_to_group("player")
	emit_signal("health_changed", health, max_health)
	hurt_shape.add_to_group("player_body")
	hitbox.monitoring = false          # only on during swing
	anim.animation_finished.connect(_on_anim_finished)
	anim.frame_changed.connect(_on_frame_changed)

# ------------------------------------------------------------------------
# Movement ─ converts WASD into 45°-rotated isometric motion
# ------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_charging:
		velocity = Vector2.ZERO
		move_and_slide()            # stop completely
		charge_time += delta        # keep building power
		return                      # skip the rest of this method

	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
	).normalized()

	if is_attacking:
		velocity = Vector2.ZERO
	else:
		velocity = dir * MOVE_SPEED

	move_and_slide()
	_update_move_anim(dir)

# ------------------------------------------------------------------------
# Input
# ------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and !is_attacking and !is_charging:
		_start_charge()

	if event.is_action_released("attack") and is_charging:
		_finish_charge()


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
		current_punch_damage = MIN_DAMAGE

		var input_vec := Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
		)
		anim.play("idle" if input_vec == Vector2.ZERO else "run")



# ------------------------------------------------------------------------
# Utility
# ------------------------------------------------------------------------
func _update_move_anim(dir: Vector2) -> void:
	if is_attacking or is_charging:          # ← new guard
		return
	if dir == Vector2.ZERO:
		if anim.animation != "idle":
			anim.play("idle")
	else:
		if anim.animation != "run":
			anim.play("run")


func _on_frame_changed() -> void:
	if anim.animation == ATTACK_ANIM:  # ATTACK_ANIM = "punch"
		# Turn on only for frames 2..4 (0-based indexing). Tweak to taste.
		var active := anim.frame >= 0 and anim.frame <= 3
		hitbox.monitoring = active

func _on_animated_sprite_2d_animation_finished() -> void:
	pass # Replace with function body.


func _on_punch_hitbox_body_entered(body: Node2D) -> void:
	if body == self:
		return
	if body.is_in_group("enemies"):
		body.take_damage(current_punch_damage)
		print("HIT ", body)


func take_damage(amount: int) -> void:
	if invincible:
		return
	_cancel_charge()
	health -= amount
	emit_signal("health_changed", health, max_health)
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
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
	
func _start_charge() -> void:
	is_charging = true
	charge_time = 0.0
	anim.play(CHARGE_ANIM)           # must be set to Loop = On
	hitbox.monitoring = false        # no hits during charge

func _finish_charge() -> void:
	# calculate scaled damage
	var t: float = clamp(charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
	current_punch_damage = lerp(MIN_DAMAGE, MAX_DAMAGE, t)

	is_charging  = false
	_start_attack()                  # reuse your punch routine

func _cancel_charge() -> void:
	is_charging = false
	charge_time = 0.0
	anim.play("idle")
