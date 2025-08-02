extends CharacterBody2D
class_name Enemy

# ---------- Tunables (exported so child scenes just change values) ----------
@export var max_health      : int   = 3
@export var move_speed      : float = 10.0
@export var attack_range    : float = 40.0   # px radius of AttackZone
@export var attack_cooldown : float = 2    # seconds between attacks
@export var damage          : int   = 1
@export var jump_height      : float = 48.0   # px at peak
@export var gravity          : float = 640.0  # px/s²
@export var launch_speed     : float = 320.0  # initial vertical vel

# ---------- Runtime -----------
var health        : int
var attack_timer  : float = 0.0
var elevation     : float = 0.0   # current “height” above ground
var v_speed       : float = 0.0   # vertical speed
var airborne      : bool  = false
var facing : int = 1
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite_lift : Node2D = $Visual/SpriteLift
@onready var anim : AnimatedSprite2D  = $Visual/SpriteLift/AnimatedSprite2D
@onready var visuals   : Node2D   = $Visual
@onready var shadow    : Sprite2D = $Visual/Shadow
@onready var player                := get_tree().get_first_node_in_group("player")

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	$AttackZone/CollisionShape2D.shape.radius = attack_range

# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
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
		
		if dist_to_player <= attack_range:
			_try_attack()
			velocity = Vector2.ZERO
		elif attack_timer == 0.0:
			attack_timer = 0.2        # or remove entirely
			velocity = to_player.normalized() * move_speed
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
	anim.play("attack")
	player.take_damage(damage)

# ---------------------------------------------------------------------------
func take_damage(amount: int) -> void:
	health -= amount
	print("HP: %d / %d" % [health, max_health])
	if health <= 0:
		_die()
	else:
		anim.play("hurt")
	

func _die() -> void:
	anim.play("death")
	set_collision_layer_value(1, false)  # turn off collisions
	$AttackZone.monitoring = false
	await anim.animation_finished
	queue_free()

# ---------------------------------------------------------------------------
func _update_anim() -> void:
	if health <= 0:
		return
	if attack_timer > attack_cooldown - 0.2:
		return                    # keep attack clip
	if velocity.length() > 5:
		anim.play("run")
	else:
		anim.play("idle")

func _on_attack_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_body"):
		_try_attack()

func launch_upward() -> void:
	if airborne:
		return
	airborne = true
	v_speed  = min(launch_speed, v_speed + launch_speed)
	anim.play("hurt")
