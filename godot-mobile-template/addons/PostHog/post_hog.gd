extends Node

const USER_FILE_PATH: String = "user://posthog_user.json"
const APP_FILE_PATH: String = "res://posthog.json"

var api_key: String = ""
var capture_url: String = ""
var distinct_id: String = ""
## https://posthog.com/docs/data/anonymous-vs-identified-events
var anonymous_events: bool = true:
	set = _update_anonymous_events
## Opt-in: analytics stay off until the player explicitly consents, so no event
## and no persistent identifier exists before then.
var enabled: bool = false
## Whether the player has answered the analytics prompt either way. Separate from
## [member enabled] so an install predating the prompt is asked rather than left off.
var consent_answered: bool = false

signal error_occurred(e: Error)
signal api_response(response: Variant)

## Properties included in every event.
var auto_include_properties: Dictionary = {}

var config: ConfigFile = ConfigFile.new()
const config_path: String = "user://user_config.cfg"

## Whether the platform should be included in every event.
@export var include_platform: bool = true
## Whether the version should be included in every event.
@export var include_app_version: bool = true
## Whether the OS version should be included in every event
@export var include_os_version: bool = true
## Whether the OS name should be included in every event
@export var include_os_name: bool = true
## Whether the device model should be included in every event
@export var include_device_model: bool = true
## Whether the screen size should be included in every event
@export var include_screen_size: bool = true
## Whether the sender IP is discarded server-side. Turning this off hands PostHog
## the IP, which is what its geolocation properties are derived from.
@export var discard_ip: bool = true

func _ready() -> void:
	_update_anonymous_events(anonymous_events)
	_load_post_hog_json()
	if enabled and not api_key.is_empty():
		_load_post_hog_user_json()
	if discard_ip:
		auto_include_properties["$ip"] = null
	if include_platform:
		auto_include_properties["platform"] = get_os_platform()
	if include_app_version:
		auto_include_properties["$app_version"] = get_app_version()
	if include_os_version:
		auto_include_properties["$os_version"] = get_os_version()
	if include_os_name:
		auto_include_properties["$os_name"] = get_os_name()
	if include_device_model:
		auto_include_properties["$device_model"] = get_device_model()
	if include_screen_size:
		auto_include_properties["$screen_width"] = get_window().size.x
		auto_include_properties["$screen_height"] = get_window().size.y

## Captures the "app opened" event
func capture_app_loaded() -> void:
	capture("app_loaded")

## Disables PostHog event capturing, saves the preference to config
func disable() -> void:
	enabled = false
	consent_answered = true
	for child: Node in get_children():
		if child is HTTPRequest:
			child.cancel_request()
			child.queue_free()
	_save_config_file()
	
## Enables PostHog event capturing, saves the preference to config
func enable() -> void:
	if AdManager.is_child or not AdManager.age_verified:
		return
	enabled = true
	consent_answered = true
	_save_config_file()
	_load_post_hog_json()
	if enabled and not api_key.is_empty():
		_load_post_hog_user_json()

## Captures a PostHog event
func capture(event_name: String, properties: Dictionary = {}) -> void:
	if not enabled or AdManager.is_child or api_key.is_empty() or capture_url.is_empty():
		return
	# Minted on first consented capture rather than at startup, so a player who
	# never opts in leaves no persistent identifier on disk.
	if distinct_id.is_empty():
		_load_post_hog_user_json()
	var event_properties: Dictionary = properties.duplicate(true)
	event_properties.merge(auto_include_properties, true)
	_send(event_name, event_properties)

## Sends the captured event properties to PostHog
func _send(event_name: String, properties: Dictionary = {}) -> void:
	var request: HTTPRequest = HTTPRequest.new()
	request.timeout = 15.0
	var headers: Array = ["Content-Type: application/json"]
	var data: Dictionary = {
		"api_key": api_key,
		"distinct_id": distinct_id,
		"event": event_name,
		"properties": properties,
	}
	add_child(request)
	request.request_completed.connect(_http_request_completed.bind(request))
	var error: Error = request.request(capture_url, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	if error != OK:
		# No completion callback fires on a failed request, so free it here.
		request.queue_free()
		error_occurred.emit(error)

## Response from PostHog HTTP API call
func _http_request_completed(_result, _response_code, _headers, body, request: HTTPRequest):
	var json: JSON = JSON.new()
	var response: Variant = null
	if json.parse(body.get_string_from_utf8()) == OK:
		response = json.get_data()
	# One request node is created per event and nothing else owns it.
	request.queue_free()
	api_response.emit(response)

## Loads the PostHog json file that contains the API key
func _load_post_hog_json():
	api_key = ""
	capture_url = ""
	if not FileAccess.file_exists(APP_FILE_PATH):
		print(APP_FILE_PATH, ' not found')
		print('Analytics disabled')
		enabled = false
		return
	_load_config_file()
	if !enabled:
		return
	var app_post_hog_file: FileAccess = FileAccess.open(APP_FILE_PATH, FileAccess.READ)
	var app_data = app_post_hog_file.get_as_text()
	app_post_hog_file.close()
	app_data = JSON.parse_string(app_data)
	if not app_data is Dictionary:
		return
	api_key = str(app_data.get("api_key", ""))
	var base_url: String = str(app_data.get("base_url", ""))
	if base_url.is_empty():
		return
	capture_url = base_url.path_join('i/v0/e/')

## Gets specfic user data for this device, or creates it.
func _load_post_hog_user_json():
	var data: Dictionary = {}
	if FileAccess.file_exists(USER_FILE_PATH):
		var user_post_hog_file = FileAccess.open(USER_FILE_PATH, FileAccess.READ)
		var data_content = user_post_hog_file.get_as_text()
		user_post_hog_file.close()
		data = JSON.parse_string(data_content)
	else:
		data = {
			"id": uuid()
		}
		var user_post_hog_file: FileAccess = FileAccess.open(USER_FILE_PATH, FileAccess.WRITE)
		user_post_hog_file.store_string(JSON.stringify(data))
		user_post_hog_file.close()
	distinct_id = data.id

## Updates the auto_include_properties for anonymous events.
func _update_anonymous_events(val: bool):
	anonymous_events = val
	auto_include_properties["$process_person_profile"] = !anonymous_events
	

## Creates the device's random v4 UUID. The previous 8-letter id drew from a small
## enough space that two players could be handed the same one, merging their events.
static func uuid() -> String:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(16)
	for i in 16:
		bytes[i] = randi() % 256
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

## Grabs the host OS platform.
static func get_os_platform() -> String:
	# First platform found in list is returned.
	var platforms = [
		"editor",
		"android",
		"ios",
		"web_android",
		"web_ios",
		"windows",
		"linux",
		"macos",
		"web_linuxbsd",
		"web_macos",
		"web_windows",
		"web",
		"mobile",
		"pc"
	]
	for platform in platforms:
		if OS.has_feature(platform):
			return platform
	return "unknown"
	
## Grabs the host OS name
static func get_os_name() -> String:
	return OS.get_name()
	
## Grabs the current app version
static func get_app_version() -> String:
	return ProjectSettings.get_setting("application/config/version")
	
## Grabs the current OS version
static func get_os_version() -> String:
	return OS.get_version()
	
## Grabs the current device model name
static func get_device_model() -> String:
	return OS.get_model_name()

## Loads the config file to determine if analytics are enabled
func _load_config_file() -> bool:
	enabled = false
	consent_answered = false
	var err: Error = config.load(config_path)
	if err != OK:
		return false
	
	enabled = config.get_value("analytics", "PostHog", false)
	# Local age gating takes precedence over a restored preference.
	if AdManager.is_child:
		enabled = false
	consent_answered = config.get_value("analytics", "consent_answered", false)
	return enabled

func _save_config_file() -> void:
	var _err: Error = config.load(config_path)
	config.set_value("analytics", "PostHog", enabled)
	config.set_value("analytics", "consent_answered", consent_answered)
	config.save(config_path)
	PlatformServices.cloud_save_config()
