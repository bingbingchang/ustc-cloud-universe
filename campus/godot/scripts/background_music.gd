extends AudioStreamPlayer
## One persistent music player for the whole game, including NPC dialogues.

func _ready():
	stream=preload("res://assets/music/sunlit_spring.mp3")
	stream.loop=true
	volume_db=-14.0
	process_mode=Node.PROCESS_MODE_ALWAYS
	play()
