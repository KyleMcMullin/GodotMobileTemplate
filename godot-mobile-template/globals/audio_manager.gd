extends Node

signal fade_out_done

# Note that this is a very simple audio manager designed for universal/non directional sound
# all FX go through the FX audio bus
# all music goes through Music audio bus
# both of those busses are nested under the Master audio bus
# if more complex uses of busses are needed (especially for FX use cases) this will need heavy editing

enum SONG {} # example: MAIN_MENU
enum SFX {} # example: BOOM

const SONG_ASSETS: Dictionary = {} # example: SONG.MAIN_MENU: preload("res://audio/songs/main_menu.wav")
const SFX_ASSETS: Dictionary = {} # example: SFX.BOOM: preload("res://audio/sfx/boom.wav")

# Default values for random FX pitch
var random_pitch_min: float = 0.5
var random_pitch_max: float = 1

var config: ConfigFile = ConfigFile.new()
const config_path: String = "user://user_config.cfg"

# Whether any sound, sfx, or music should be played. Can be toggle independently 
var play_sound: bool = true
var play_sfx: bool = true
var play_music: bool = true

# Assumption that we will only play one song at a time, and thus only need one audiostreamplayer
var music_stream_player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready() -> void:
	_load_config_file()
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_stream_player.bus = "Music"
	add_child(music_stream_player)

	# initialize the music player volume low so it can be faded in 
	music_stream_player.volume_db = -50
	
## Creates a sound effect with the option for random pitch and custom random pitch min/max
## Begins playing the sound and connects a signal to delete the player once it finishes
func create_sound_fx(sound: SFX, random_pitch: bool = false, custom_rand_pitch_min: float = 0.0, custom_rand_pitch_max: float = 0.0) -> void:
	if !play_sound or !play_sfx: return
	var fx_stream_player: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child(fx_stream_player)
	fx_stream_player.bus = "FX"
	fx_stream_player.stream = SFX_ASSETS[sound]
	if random_pitch:
		if custom_rand_pitch_min != custom_rand_pitch_max:
			fx_stream_player.pitch_scale = randf_range(custom_rand_pitch_min, custom_rand_pitch_max)
		else:
			fx_stream_player.pitch_scale = randf_range(random_pitch_min, random_pitch_max)
	fx_stream_player.play()
	fx_stream_player.finished.connect(remove_fx_player.bind(fx_stream_player))
	
## Remove the audio stream player when it is done playing
func remove_fx_player(player: AudioStreamPlayer) -> void:
	player.queue_free()

## Fades in selected song over period of time
func fade_in_song(song: SONG, fade_in_time: float) -> void:
	music_stream_player.stream = SONG_ASSETS[song]
	music_stream_player.play()
	if !play_music or !play_sound: return
	
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(music_stream_player, "volume_db", 0, fade_in_time)
	
## Fades in the currently playing song (a song can be playing with no volume)
func fade_in_continue_playing(fade_in_time: float) -> void:
	if !play_music or !play_sound: return
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(music_stream_player, "volume_db", 0, fade_in_time)
	
## Fades out the currently playing song (does not stop it from playing, just turns the volume down)
func fade_out_song(fade_out_time: float) -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(music_stream_player, "volume_db", -75, fade_out_time)
	tween.finished.connect(fade_out_done.emit)
	
## Fades out the current song and in the new song provided
func cross_fade(song: SONG, fade_out_time: float, fade_in_time: float) -> void:
	fade_out_song(fade_out_time)
	await fade_out_done
	fade_in_song(song, fade_in_time)
	
## Adjusts whether sound should be muted
## Auto captures for PostHog
func adjust_sound_mute(new_play_sound: bool) -> void:
	if new_play_sound:
		PostHog.capture("sound_enabled")
	else:
		PostHog.capture("sound_disabled")
	play_sound = new_play_sound
	if !play_sound:
		fade_out_song(.5)
	_save_config_file()
	
## Adjusts whether music should be muted
## Auto captures for PostHog
func adjust_music_mute(new_play_music: bool) -> void:
	if new_play_music:
		PostHog.capture("music_enabled")
	else:
		PostHog.capture("music_disabled")
	play_music = new_play_music
	if !play_music:
		fade_out_song(.5)
	_save_config_file()
	
## Adjusts whether sfx should be muted
## Auto captures for PostHog
func adjust_fx_mute(new_play_sfx: bool) -> void:
	if new_play_sfx:
		PostHog.capture("SFX_enabled")
	else:
		PostHog.capture("SFX_disabled")
	play_sfx = new_play_sfx
	_save_config_file()
	
func _load_config_file() -> bool:
	var err: Error = config.load(config_path)
	if err != OK:
		return false
	
	play_sound = config.get_value("audio", "play_sound", true)
	play_music = config.get_value("audio", "play_music", true)
	play_sfx = config.get_value("audio", "play_sfx", true)
	return true

func _save_config_file() -> void:
	var _err: Error = config.load(config_path)
	config.set_value("audio", "play_sound", play_sound)
	config.set_value("audio", "play_music", play_music)
	config.set_value("audio", "play_sfx", play_sfx)
	config.save(config_path)
	PlatformServices.cloud_save_config()
	
