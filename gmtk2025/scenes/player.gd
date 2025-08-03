extends CharacterBody2D

@export var MOVE_SPEED: float = 100.0
@export var ACCELERATION : float = 800.0   # higher = snappier start
@export var FRICTION     : float = 800.0   # higher = quicker stop
@export var PUNCH_MIN_IMPULSE  : float = 60.0    # tap–punch
@export var PUNCH_MAX_IMPULSE  : float = 600.0   # furll charge
@export var UPPERCUT_IMPULSE   : float = 50.0
@export var ATTACK_FRICTION    : float = 1600.0  # how quickly the burst stops
@export var HURT_LOCK_TIME : float = 0.20   # seconds you’re stunned
@export var punch_range := 40.0
@export var uppercut_range := 40.0

@export var max_health : int = 10          # tweak as you like
var health             : int = max_health
var invincible         : bool = false     # simple i-frame flag
@export var i_frames   : float = 0.3      # seconds of invulnerability

var is_attacking : bool  = false
var is_attacking2: bool  = false
var is_hurt      : bool  = false            # true while stun lasts
var hurt_timer   : float = 0.0
var attack_impulse_velocity : Vector2 = Vector2.ZERO



@onready var anim: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var hitbox1: Area2D       = $Visual/PunchHitbox
@onready var hitbox1_shape     : CollisionShape2D  = $Visual/PunchHitbox/CollisionShape2D
@onready var hitbox2: Area2D       = $Visual/UppercutHitbox
@onready var hitbox2_shape     : CollisionShape2D  = $Visual/UppercutHitbox/CollisionShape2D
@onready var hurt_shape := $CollisionShape2D
@onready var visuals : Node2D = $Visual  # parent of sprite + hitboxes
@onready var shadow    : Sprite2D = $Visual/Shadow

signal health_changed(current: int, max: int)

# ---------- Punch / charge tuning ----------
const ATTACK_ANIM        := "punch"
const ATTACK2_ANIM       := "uppercut"
const CHARGE_ANIM        := "charge"      # loops while holding
const HURT_ANIM			 := "hurt"
const IDLE_ANIM			 := "idle"
const RUN_ANIM			 := "run"
const MIN_DAMAGE         := 2             # quick-tap damage
const MAX_DAMAGE         := 6             # fully charged
const MAX_CHARGE_TIME    := 1.0           # seconds to full power
const MIN_CHARGE_SPEED : float = 0.0      # floor at 20 % of run speed
const MAX_CHARGE_SPEED : float = 1.0      # 100 % when you first press





var is_charging          := false
var charge_time          := 0.0           # accumulates while holding
var current_punch_damage := MIN_DAMAGE    # set on release
var attack_dir : Vector2 = Vector2.RIGHT

var facing : int = 1                     # 1 = facing right, -1 = left



func _ready() -> void:
	anim.play(IDLE_ANIM)
	add_to_group("player")
	hitbox1.add_to_group("player_attack")
	hitbox2.add_to_group("player_attack")
	emit_signal("health_changed", health, max_health)
	hurt_shape.add_to_group("player_body")
	hitbox1_shape.disabled = true
	hitbox2_shape.disabled = true
	hitbox1.monitoring     = false   # optional—doesn’t hurt to leave off
	hitbox2.monitoring     = false
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

	if is_hurt:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			is_hurt = false
			_cancel_attack()
			_return_to_idle_or_run()            # helper below
		move_and_slide()                        # still collide if pushed
		return


	if is_attacking or is_attacking2:
		velocity = velocity.move_toward(attack_impulse_velocity, ATTACK_FRICTION * delta)
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
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and !is_attacking and !is_charging and !is_attacking2:
		# If doing uppercut or punch, queue charge
		_start_charge()
		print("attack pressed")  

	if event.is_action_released("attack") and is_charging:
		# If doing anything other than charging, queue a punch. otherwise, punch immediately
		_finish_charge()
		print("attack released")  
		
	if event.is_action_pressed("attack2") and !is_attacking and !is_charging and !is_attacking2:
		_start_uppercut()
		print("uppercut pressed") 
		


# ------------------------------------------------------------------------
# Attack helpers
# ------------------------------------------------------------------------
func _start_punch() -> void:
	is_attacking = true
	_aim_hitboxes_at_mouse()
	hitbox1.monitoring = true
	anim.play(ATTACK_ANIM)
	
	
func _start_uppercut() -> void:
	is_attacking2 = true

	# aim the hitbox
	_aim_hitboxes_at_mouse()

	# send yourself flying toward the mouse
	var dir = _get_attack_direction()
	attack_impulse_velocity = dir * UPPERCUT_IMPULSE

	hitbox2.monitoring = true
	anim.play(ATTACK2_ANIM)
	

func _on_anim_finished() -> void:

	if (anim.animation == ATTACK_ANIM) or (anim.animation == HURT_ANIM) or (anim.animation == ATTACK2_ANIM):
		hitbox1_shape.disabled = true
		hitbox2_shape.disabled = true
		hitbox1.monitoring = false
		hitbox2.monitoring = false
		is_attacking = false
		is_attacking2 = false
		current_punch_damage = MIN_DAMAGE
		attack_impulse_velocity = Vector2.ZERO

		var input_vec := Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
		)
		anim.play(IDLE_ANIM if input_vec == Vector2.ZERO else RUN_ANIM)



# ------------------------------------------------------------------------
# Utility
# ------------------------------------------------------------------------
func _update_move_anim(dir: Vector2) -> void:
	if is_attacking or is_charging or is_attacking2 or is_hurt:          # ← new guard
		return
	if dir == Vector2.ZERO:
		if anim.animation != IDLE_ANIM:
			anim.play(IDLE_ANIM)
	else:
		if anim.animation != RUN_ANIM:
			anim.play(RUN_ANIM)


func _on_frame_changed() -> void:
	if anim.animation == ATTACK_ANIM:  # ATTACK_ANIM = "punch"

		var active := anim.frame >= 0 and anim.frame <= 3
		hitbox1_shape.disabled = !active
		hitbox1.monitoring = active
		
	elif anim.animation == ATTACK2_ANIM:  # ATTACK2_ANIM = "uppercut"

		var active := anim.frame >= 2 and anim.frame <= 4
		hitbox2_shape.disabled = !active
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
	
	_cancel_attack()	
	_cancel_charge()
	
	
	health -= amount
	invincible = true
	
	is_hurt    = true
	hurt_timer = HURT_LOCK_TIME
	velocity   = Vector2.ZERO               # stop dead
	anim.play(HURT_ANIM)
	
	emit_signal("health_changed", health, max_health)
	
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

func _finish_charge() -> void:
	# calculate scaled damage
	var t = clamp(charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
	current_punch_damage = lerp(MIN_DAMAGE, MAX_DAMAGE, t)
	var impulse_mag = lerp(PUNCH_MIN_IMPULSE, PUNCH_MAX_IMPULSE, t)

	# build a directional impulse
	var dir = _get_attack_direction()
	attack_impulse_velocity = dir * impulse_mag

	is_charging = false
	_start_punch()      

func _cancel_charge() -> void:
	is_charging = false
	charge_time = 0.0
	#anim.play(IDLE_ANIM)
	# reset move speed
	
func _cancel_attack() -> void:
	is_attacking  = false
	is_attacking2 = false
	attack_impulse_velocity = Vector2.ZERO

	hitbox1.monitoring = false
	hitbox2.monitoring = false


func _return_to_idle_or_run() -> void:
	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down")  - Input.get_action_strength("move_up")
	)
	anim.play(IDLE_ANIM if input_vec == Vector2.ZERO else RUN_ANIM)

func _get_attack_direction() -> Vector2:
	return (get_global_mouse_position() - global_position).normalized()

func _aim_hitboxes_at_mouse():
	var dir = _get_attack_direction()
	_set_hitbox_rotation(dir)


func _set_hitbox_rotation(direction: Vector2) -> void:
	var angle = direction.angle()
	# if you still want to flip the rotation when facing left:
	if facing < 0:
		angle = PI - angle
	hitbox1.rotation = angle
	hitbox2.rotation = angle
