extends TextureButton

@onready var time_manager: TimeManager = %"time manager"
var music_volume: float

func _ready() -> void:
	music_volume = time_manager.music_volume

func _toggled(toggled_on: bool) -> void:
	if not toggled_on:
		time_manager.music_player.volume_db = music_volume
		time_manager.music_volume = music_volume
	else:
		time_manager.music_player.volume_db = -INF
		time_manager.music_volume = -INF
