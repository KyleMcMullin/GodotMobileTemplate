extends Control

@onready var splashes_container: CenterContainer = $SplashesContainer
@onready var policies_container: VBoxContainer = $PolicyContainer
@onready var policies_label: RichTextLabel = $PolicyContainer/MarginContainer/PanelContainer/RichTextLabel

@onready var age_gate_container: VBoxContainer = $AgeGateContainer
@onready var age_input: LineEdit = $AgeGateContainer/MarginContainer2/VBoxContainer/AgeInput
@onready var invalid_age_label: Label = $AgeGateContainer/MarginContainer2/VBoxContainer/InvalidAgeLabel
@onready var child_notice_container: VBoxContainer = $ChildNoticeContainer
@onready var child_notice_label: RichTextLabel = $ChildNoticeContainer/MarginContainer/PanelContainer/RichTextLabel

## Players who report an age under this are flagged as a child session.
const AGE_THRESHOLD_YEARS: int = 16

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

## Defaults to having the policies NOT accepted
var policies_accepted: bool = false
## This should be toggled on when privacy policy is accepted
var accept_input: bool = false

var splashes: Array
var transition_started: bool = false



func _ready() -> void:
	# Age gate goes first; nothing else shows until the child flag is known.
	policies_label.meta_clicked.connect(_open_link)
	child_notice_label.meta_clicked.connect(_open_link)
	_load_config_file()
	if !AdManager.age_verified:
		_show_age_gate()
		return
	if !policies_accepted:
		_show_policy_step()
		return
	# Fire app-opened every launch for non-child returning users only.
	if !AdManager.is_child:
		PostHog.capture_app_loaded()
	_transition_in()

# Transition shows each of the children of SplashesContainer that are visible
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
	
# fade in and out each splash
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
	ScreenSwitcher.switch_screen(ScreenSwitcher.SCREEN.MAIN_MENU)

func _open_link(meta: Variant) -> void:
	OS.shell_open(meta)

## Accept-policies handler for the non-child path.
func _on_continue_pressed() -> void:
	policies_accepted = true
	var _err: Error = config.load(config_path)
	config.set_value("policies", "has_accepted_policies", true)
	config.save(config_path)
	PlatformServices.cloud_save_config()
	PostHog.capture_app_loaded()
	_transition_in()

func _show_age_gate() -> void:
	policies_container.visible = false
	child_notice_container.visible = false
	age_gate_container.visible = true

## Strips any non-digit character as it's typed/pasted.
func _on_age_input_text_changed(new_text: String) -> void:
	var digits_only: String = ""
	for character: String in new_text:
		if character.is_valid_int():
			digits_only += character
	if digits_only != new_text:
		age_input.text = digits_only
		age_input.caret_column = digits_only.length()

## Validates the entered age and flags the session as child/non-child.
func _on_age_submit_pressed() -> void:
	var entered: String = age_input.text.strip_edges()
	if not entered.is_valid_int() or entered.to_int() < 0:
		invalid_age_label.visible = true
		return
	var age: int = entered.to_int()
	var under_age: bool = age < AGE_THRESHOLD_YEARS
	AdManager.set_child_directed(under_age)
	if under_age:
		PostHog.disable()
	_show_policy_step()

## Shows the normal policy-accept screen for non-child sessions, or the
## informational notice for child sessions.
func _show_policy_step() -> void:
	age_gate_container.visible = false
	if AdManager.is_child:
		policies_container.visible = false
		child_notice_container.visible = true
	else:
		child_notice_container.visible = false
		policies_container.visible = true

## Child branch's Continue; skips analytics and cloud save so no data leaves the device.
func _on_child_notice_continue_pressed() -> void:
	policies_accepted = true
	var _err: Error = config.load(config_path)
	config.set_value("policies", "has_accepted_policies", true)
	config.save(config_path)
	child_notice_container.visible = false
	_transition_in()
