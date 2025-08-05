extends CharacterBody2D
class_name Enemy

signal died

# ---------- Tunables (exported so child scenes just change values) ----------
@export var max_health      : int   = 3
@export var move_speed      : float = 10.0
@export var attack_range    : float = 40.0   # px radius of AttackZone
@export var attack_cooldown : float = 2    # seconds between attacks
@export var damage          : int   = 1
@export var jump_height      : float = 48.0   # px at peak
@export var gravity          : float = 640.0  # px/s²
@export var launch_speed     : float = 320.0  # initial vertical vel
@export var knockback_force : float = 300.0
@export var HURT_LOCK_TIME : float = 0.20 


# ---------- Runtime -----------
var health        : int
var attack_timer  : float = 0.0
var elevation     : float = 0.0   # current “height” above ground
var v_speed       : float = 0.0   # vertical speed
var airborne      : bool  = false
var facing : int = 1
var is_attacking : bool = false
var is_hurt      : bool  = false   
var hurt_timer   : float = 0.0
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite_lift : Node2D = $Visual/SpriteLift
@onready var anim : AnimatedSprite2D  = $Visual/SpriteLift/AnimatedSprite2D
@onready var visuals   : Node2D   = $Visual
@onready var shadow    : Sprite2D = $Visual/Shadow
@onready var alert_anim : AnimatedSprite2D = $Visual/AlertAnim
@onready var player                := get_tree().get_first_node_in_group("player")
var awake : bool = false        # starts asleep until camera settles

const ATTACK_ANIM        := "attack"

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	$AttackZone/CollisionShape2D.shape.radius = attack_range
	anim.animation_finished.connect(_on_anim_finished)
	anim.frame_changed.connect(_on_frame_changed)
	$BiteBox/CollisionShape2D.disabled = true
	$BiteBox.monitoring = false
	#set_physics_process(false)
	set_physics_process(false)
	alert_anim.visible = false  

# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if !awake:
		return
	
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
			
	if is_hurt:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			is_hurt = false

		move_and_slide()                        # still collide if pushed
		return
			
	if airborne:
		v_speed -= gravity * delta
		elevation += v_speed * delta
		if elevation <= 0:
			elevation = 0
			v_speed = 0
			airborne = false

	sprite_lift.position.y = -elevation   # sprite goes up
	var t := clampf(elevation / jump_height, 0.0, 1.0)
	shadow.scale      = Vector2(1.0 - 0.4 * t, 1.0 - 0.4 * t)
	shadow.modulate.a = 0.3 * (1.0 - t)


	attack_timer = maxf(attack_timer - delta, 0.0)
	
	if health <= 0:
		return

	if not airborne:
		if velocity.x != 0:
			facing = sign(velocity.x)
			sprite_lift.scale.x = facing
		
		var to_player: Vector2 = player.global_position - global_position
		var dist_to_player: float = to_player.length()
		
		if is_attacking:
			velocity = Vector2.ZERO
		
		elif (dist_to_player <= attack_range) and (attack_timer <= 0.0):
			_try_attack()
			velocity = Vector2.ZERO
		
		else:
			velocity = to_player.normalized() * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_update_anim()


# ---------------------------------------------------------------------------
func _try_attack() -> void:
	if attack_timer > 0.0 or airborne:
		return
	attack_timer = attack_cooldown
	is_attacking = true
	
	anim.play("attack")
	
	
func _on_frame_changed() -> void:
	if anim.animation == ATTACK_ANIM: 

		var active := anim.frame == 6
		$BiteBox/CollisionShape2D.disabled = !active
		$BiteBox.monitoring = active

# ---------------------------------------------------------------------------
func take_damage(amount: int, from_pos: Vector2) -> void:
	health -= amount
	print("HP: %d / %d" % [health, max_health])
	
	if is_attacking:
		Audiomanager.play_sfx("parry", -20, 0.1)
	
	#Cancel the attack
	is_attacking = false
	is_hurt    = true
	hurt_timer = HURT_LOCK_TIME
	
	
	$BiteBox.monitoring = false
	$BiteBox/CollisionShape2D.disabled = true
	
	var dir = (global_position - from_pos).normalized()
	velocity = dir * knockback_force
	
	if health <= 0:
		_die()
	else:
		anim.play("hurt")
	

func _die() -> void:
	Audiomanager.play_sfx("explodemini", -10, 0)
	anim.play("death")
	set_collision_layer_value(1, false)
	$AttackZone.monitoring         = false
	$BiteBox.monitoring            = false
	is_attacking                   = false

	# 2) Fire off the death particles
	var death_p := $Visual/DieParticles
	death_p.one_shot   = true             # so they stop automatically
	death_p.emitting   = true


	$Visual/Shadow.visible = false

	# 4) Wait for the particles’ lifetime before really freeing
	#    CPUParticles2D has a `lifetime` property you set in the Inspector.
	var t : float = death_p.lifetime
	await get_tree().create_timer(t).timeout

	# 5) Let anything listening know this enemy is gone
	died.emit()

	# 6) Finally remove the spider node
	queue_free()

# ---------------------------------------------------------------------------
func _update_anim() -> void:
	if health <= 0:
		return
	if attack_timer > attack_cooldown - 0.2:
		return
	if is_attacking:
		return                    # keep attack clip
	if velocity.length() > 5:
		anim.play("run")
	else:
		anim.play("idle")

func _on_attack_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		Audiomanager.play_sfx("spider_bite", -10)
		player.take_damage(damage, global_position)
		
func _on_anim_finished() -> void:
	if anim.animation == ATTACK_ANIM:
		is_attacking = false


	if health > 0:
		anim.play("idle" if velocity == Vector2.ZERO else "run")

		


func launch_upward() -> void:
	if airborne:
		return
	airborne = true
	v_speed  = min(launch_speed, v_speed + launch_speed)

	
func show_alert_and_activate() -> void:
	print("spiderside wakeup")
	# called by Arena/Main after camera pan
	alert_anim.visible = true
	Audiomanager.play_sfx("alert", -20, 0)
	alert_anim.play("alert")
	await alert_anim.animation_finished
	alert_anim.visible = false

	awake = true
	set_physics_process(true)
	anim.play("idle")
	
