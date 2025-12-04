extends Control

@onready var splashes_container: CenterContainer = $SplashesContainer
@onready var policies_container: VBoxContainer = $PolicyContainer
#@onready var rich_text_label: RichTextLabel = $PolicyContainer/MarginContainer/PanelContainer/RichTextLabel

@onready var go_to_main_delay: Timer = $GoToMainDelay
@onready var start_delay: Timer = $StartDelay

@export var in_time: float = .15
@export var out_time: float = .13
@export var pause_time: float = .38

@export var fade_in_trans: Tween.TransitionType = Tween.TransitionType.TRANS_SINE
@export var fade_in_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var fade_time: float = .78

var config: ConfigFile = ConfigFile.new()
var config_path: String = "user://user_config.cfg"

var splashes: Array

## Defaults to having the policies NOT accepted
var policies_accepted: bool = false
## This should be toggled on when privacy policy is accepted
var accept_input: bool = false

var transition_started: bool = false

func _ready() -> void:
	# if not t&c and privacy policy then load that component and don't start delay timer until accepted
	#rich_text_label.meta_clicked.connect(_open_link)
	_load_config_file()
	if !policies_accepted: return
	_transition_in()

	
func _transition_in() -> void:
	policies_container.call_deferred("set_visible", false)
	splashes_container.call_deferred("set_visible", true)
	accept_input = true
	splashes = splashes_container.get_children()
	var temp_splashes: Array = []
	for splash: Control in splashes:
		if splash.visible:
			splash.modulate.a = 0.0
			temp_splashes.append(splash)
	splashes = temp_splashes
	start_delay.start()
	
## Allow skipping the splash screen
#func _input(event: InputEvent) -> void:
	#if !accept_input: return
	#if event is InputEventScreenTouch:
		#go_to_main_delay.stop()
		#_on_go_to_main_delay_timeout()
		
		
func _load_config_file() -> bool:
	var err: Error = config.load(config_path)
	if err != OK:
		return false
	
	policies_accepted = config.get_value("policies", "has_accepted_policies", false)
	return policies_accepted
	
func _start_delay_timeout() -> void:
	_fade()
	
func _fade() -> void:
	for splash: Control in splashes:
		var tween: Tween = create_tween()
		tween.set_ease(fade_in_ease)
		tween.set_trans(fade_in_trans)
		tween.tween_interval(in_time)
		tween.tween_property(splash, "modulate:a", 1.0, fade_time)
		tween.tween_interval(pause_time)
		tween.tween_property(splash, "modulate:a", 0.0, fade_time)
		tween.tween_interval(out_time)
		await tween.finished
	go_to_main_delay.start()

func _on_go_to_main_delay_timeout() -> void:
	if transition_started: return
	transition_started = true
	#if AdManager.has_ad_free:
		#SceneSwitcher.switch_scene("res://menus/screens/main_menu.tscn")
	#else:		
		#SceneSwitcher.switch_scene("res://menus/screens/temp_ad_free_screen.tscn")

func _open_link(meta: Variant) -> void:
	OS.shell_open(meta)


func _on_continue_pressed() -> void:
	policies_accepted = true
	_transition_in()
	var _err: Error = config.load(config_path)
	config.set_value("policies", "has_accepted_policies", true)
	config.save(config_path)
	#PlatformServices.cloud_save_config()
