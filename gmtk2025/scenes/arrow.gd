extends AnimatedSprite2D

func flash(on: bool):
	modulate.a = 1.0 if on else 0.0
	if on: play()
