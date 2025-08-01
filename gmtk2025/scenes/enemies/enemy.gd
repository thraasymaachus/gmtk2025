extends CharacterBody2D
class_name Enemy

# ---------- Tunables (exported so child scenes just change values) ----------
@export var max_health      : int   = 3
@export var move_speed      : float = 10.0
@export var attack_range    : float = 40.0   # px radius of AttackZone
@export var attack_cooldown : float = 2    # seconds between attacks
@export var damage          : int   = 1

# ---------- Runtime -----------
var health        : int
var attack_timer  : float = 0.0
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var anim : AnimatedSprite2D  = $AnimatedSprite2D
@onready var player                := get_tree().get_first_node_in_group("player")

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	$AttackZone/CollisionShape2D.shape.radius = attack_range

# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if health <= 0:
		return
		
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return   # wait until player exists


	attack_timer = maxf(attack_timer - delta, 0.0)

	var dist := global_position.distance_to(player.global_position)
	if dist <= attack_range:
		_try_attack()
		velocity = Vector2.ZERO
	else:
		agent.target_position = player.global_position
		velocity = agent.get_next_path_position() - global_position
		velocity = velocity.normalized() * move_speed

	move_and_slide()
	_update_anim()

# ---------------------------------------------------------------------------
func _try_attack() -> void:
	if attack_timer == 0.0:
		attack_timer = attack_cooldown
		anim.play("attack")
		# Deal damage once hitbox frame arrives (simplest: immediate)
		player.take_damage(damage)

# ---------------------------------------------------------------------------
func take_damage(amount: int) -> void:
	health -= amount
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
