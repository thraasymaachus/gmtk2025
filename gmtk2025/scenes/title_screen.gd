extends Control

func _ready():
	$StartButton.pressed.connect(_on_start_pressed)
	$QuitButton.pressed.connect(_on_quit_pressed)
	$CreditsButton.pressed.connect(_on_credits_pressed)

	
	$StartupVoice.play()
	$TitleMusic.play()
	


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_credits_pressed() -> void:
	$CreditsScreen.visible = true
	$CreditsScreen.mouse_filter = Control.MOUSE_FILTER_PASS
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("return"):
		$CreditsScreen.visible = false
