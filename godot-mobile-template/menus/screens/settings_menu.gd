extends "res://menus/components/menu_screen.gd"

func _ready() -> void:
	%SoundToggle.set_pressed_no_signal(AudioManager.play_sound)
	%MusicToggle.set_pressed_no_signal(AudioManager.play_music)
	%SfxToggle.set_pressed_no_signal(AudioManager.play_sfx)
	%SoundToggle.toggled.connect(AudioManager.adjust_sound_mute)
	%MusicToggle.toggled.connect(AudioManager.adjust_music_mute)
	%SfxToggle.toggled.connect(AudioManager.adjust_fx_mute)

func _on_privacy_pressed() -> void:
	ScreenSwitcher.switch_screen_transition(ScreenSwitcher.SCREEN.PRIVACY)

func _on_credits_pressed() -> void:
	ScreenSwitcher.switch_screen_transition(ScreenSwitcher.SCREEN.CREDITS)
