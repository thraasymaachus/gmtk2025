extends CharacterBody2D

@export var MOVE_SPEED: float = 120.0
@export var ACCELERATION : float = 800.0   # higher = snappier start
@export var FRICTION     : float = 600.0   # higher = quicker stop

@export var max_health : int = 10          # tweak as you like
var health             : int = max_health
var invincible         : bool = false     # simple i-frame flag
@export var i_frames   : float = 0.3      # seconds of invulnerability

var is_attacking := false
var is_attacking2 := false

@onready var anim: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var hitbox1: Area2D       = $Visual/PunchHitbox
@onready var hitbox2: Area2D       = $Visual/UppercutHitbox
@onready var hurt_shape := $CollisionShape2D
@onready var visuals : Node2D = $Visual  # parent of sprite + hitboxes

signal health_changed(current: int, max: int)

# ---------- Punch / charge tuning ----------
const ATTACK_ANIM        := "punch"
const ATTACK2_ANIM       := "uppercut"
const CHARGE_ANIM        := "charge"      # loops while holding
const HURT_ANIM			 := "hurt"
const MIN_DAMAGE         := 2             # quick-tap damage
const MAX_DAMAGE         := 6             # fully charged
const MAX_CHARGE_TIME    := 1.0           # seconds to full power
const MIN_CHARGE_SPEED : float = 0.0      # floor at 20 % of run speed
const MAX_CHARGE_SPEED : float = 1.0      # 100 % when you first press





var is_charging          := false
var charge_time          := 0.0           # accumulates while holding
var current_punch_damage := MIN_DAMAGE    # set on release

var facing : int = 1                     # 1 = facing right, -1 = left



func _ready() -> void:
	anim.play("idle")
	add_to_group("player")
	emit_signal("health_changed", health, max_health)
	hurt_shape.add_to_group("player_body")
	hitbox1.monitoring = false          # only on during swing
	hitbox2.monitoring = false
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
	
	if dir.x != 0:
		facing = sign(dir.x)
		visuals.scale.x = facing             # flips art + hitboxes


	if is_attacking or is_attacking2:
		velocity = Vector2.ZERO
	elif is_charging:
		# charge-progress ratio (0 → 1, clamp for safety)
		var t: float = clampf(charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
		# linear interpolation: 1.0 → MIN_CHARGE_SPEED as t goes 0 → 1
		var charge_speed_mult: float = lerp(MAX_CHARGE_SPEED, MIN_CHARGE_SPEED, t)
		var target_vel = dir * MOVE_SPEED * charge_speed_mult
		var accel: float = FRICTION if dir == Vector2.ZERO else ACCELERATION
		velocity = velocity.move_toward(target_vel, accel * delta)
		
		charge_time += delta                         # keep building power
		move_and_slide()                             # still collide while gliding
		return  
			 
	else:
		var target_vel : Vector2 = dir * MOVE_SPEED
		var accel: float = FRICTION if dir == Vector2.ZERO else ACCELERATION
		velocity = velocity.move_toward(target_vel, accel * delta)

	move_and_slide() 
	_update_move_anim(dir)

# ------------------------------------------------------------------------
# Input
# ------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and !is_attacking and !is_charging and !is_attacking2:
		# If doing uppercut or punch, queue charge
		_start_charge()

	if event.is_action_released("attack") and is_charging:
		# If doing anything other than charging, queue a punch. otherwise, punch immediately
		_finish_charge()
		
	if event.is_action_pressed("attack2") and !is_attacking and !is_charging and !is_attacking2:
		_start_uppercut()


# ------------------------------------------------------------------------
# Attack helpers
# ------------------------------------------------------------------------
func _start_punch() -> void:
	is_attacking = true
	hitbox1.monitoring = true
	anim.play(ATTACK_ANIM)
	
	
func _start_uppercut() -> void:
	is_attacking2 = true
	hitbox2.monitoring = true
	anim.play(ATTACK2_ANIM)
	

func _on_anim_finished() -> void:

	if (anim.animation == ATTACK_ANIM) or (anim.animation == HURT_ANIM) or (anim.animation == ATTACK2_ANIM):
		hitbox1.monitoring = false
		hitbox2.monitoring = false
		is_attacking = false
		is_attacking2 = false
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
	if is_attacking or is_charging or is_attacking2:          # ← new guard
		return
	if dir == Vector2.ZERO:
		if anim.animation != "idle":
			anim.play("idle")
	else:
		if anim.animation != "run":
			anim.play("run")


func _on_frame_changed() -> void:
	if anim.animation == ATTACK_ANIM:  # ATTACK_ANIM = "punch"

		var active := anim.frame >= 0 and anim.frame <= 3
		hitbox1.monitoring = active
		
	if anim.animation == ATTACK2_ANIM:  # ATTACK2_ANIM = "uppercut"

		var active := anim.frame >= 2 and anim.frame <= 4
		hitbox2.monitoring = active


func _on_punch_hitbox_body_entered(body: Node2D) -> void:
	if body == self:
		return
	if body.is_in_group("enemies"):
		body.take_damage(current_punch_damage)
		print("Punched ", body, " for ", current_punch_damage)
		

func _on_uppercut_hitbox_body_entered(body: Node2D) -> void:
	if body == self:
		return
	if body.is_in_group("enemies"):
		body.take_damage(MIN_DAMAGE)
		print("Uppercut ", body, " for ", current_punch_damage)
		if body.has_method("launch_upward"):
			body.launch_upward()
		


func take_damage(amount: int) -> void:
	if invincible:
		return
	_cancel_charge()
	health -= amount
	emit_signal("health_changed", health, max_health)
	invincible = true
	anim.play(HURT_ANIM)        # optional hurt clip
	
	if health <= 0:
		_die()
		return

	# reset invincibility after a short delay
	var timer := get_tree().create_timer(i_frames)
	await timer.timeout
	invincible = false
	anim.play("idle")

func _die() -> void:
	velocity = Vector2.ZERO
	anim.play("death")
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
	
func _start_charge() -> void:
	is_charging = true
	charge_time = 0.0
	anim.play(CHARGE_ANIM)           # must be set to Loop = On

func _finish_charge() -> void:
	# calculate scaled damage
	var t: float = clamp(charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
	current_punch_damage = lerp(MIN_DAMAGE, MAX_DAMAGE, t)
	
	# reset move speed

	is_charging  = false
	_start_punch()                  # reuse your punch routine

func _cancel_charge() -> void:
	is_charging = false
	charge_time = 0.0
	#anim.play("idle")
	# reset move speed
