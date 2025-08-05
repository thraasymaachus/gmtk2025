extends Node
class_name AudioManager

# preload all your sounds here
const SFX = {
	"player_attack": preload("res://sounds/punchman/rumble.mp3"),
	"parry": preload("res://sounds/punchman/parry.mp3"),
	"spider_bite": preload("res://sounds/crab/sfx_hit.ogg"),
	"alert": preload("res://sounds/crab/sfx_alarm.ogg"), #Audiomanager.play_sfx("alert", -10, 0)
	"explode": preload("res://sounds/wall break/explode.wav"),
	"explodemini": preload("res://sounds/wall break/explodemini.wav"),
}

func play_sfx(name: String, volume_db: float = 0.0, delay_sec: float = 0.0) -> void:
	if not SFX.has(name):
		push_warning("Unknown SFX: %s" % name)
		return
		
	if delay_sec > 0.0:
		await get_tree().create_timer(delay_sec).timeout
		
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream    = SFX[name]
	player.volume_db = volume_db

	player.play()
	# queue_free when done
	player.finished.connect(player.queue_free)
