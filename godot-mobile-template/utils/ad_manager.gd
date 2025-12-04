extends Node

signal got_ad_free

signal has_form
signal manual_form_loaded

var is_development: bool = false

var has_ad_free: bool = false
var has_temp_ad_free: bool = false

var config: ConfigFile = ConfigFile.new()
const config_path: String = "user://user_config.cfg"

var _consent_form: ConsentForm

func _ready() -> void:
	# Update consent information
	# If the player is in an area that requires specific consent that they have yet to provide
	# then show them the form
	# otherwise, if consent has been obtained, initialize the ads plugin
	var request: ConsentRequestParameters = ConsentRequestParameters.new()
	request.tag_for_under_age_of_consent = false
	UserMessagingPlatform.consent_information.update(request, _on_consent_info_updated_success, _on_consent_info_updated_failure)
	if UserMessagingPlatform.consent_information.get_consent_status() == UserMessagingPlatform.consent_information.ConsentStatus.OBTAINED:
		MobileAds.initialize()
	_load_config_file()
	
## Load config file to check if they have ad free
func _load_config_file() -> bool:
	var err: Error = config.load(config_path)
	if err != OK:
		return false
	
	has_ad_free = config.get_value("ads", "ad_free", false)
	return true

## Call this when purchasing ad free to locally save that they have it
func _save_config_file() -> void:
	var _err: Error = config.load(config_path)
	config.set_value("ads", "ad_free", has_ad_free)
	config.save(config_path)
	#PlatformServices.cloud_save_config()
	
func get_ad_free() -> void:
	#pass
	# Uncomment above and comment below when needed to test ads
	has_ad_free = true
	got_ad_free.emit()
	_save_config_file()
	
# This is ad_free that expires when the session (app) closes, does not save to config file
func get_temporary_ad_free() -> void:
	has_temp_ad_free = true
	
func _on_consent_info_updated_success() -> void:
	# The consent information state was updated.
	# You are now ready to check if a form is available.
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		load_form()
		
func _on_consent_info_updated_failure(form_error : FormError) -> void:
	# Handle the error.
	print(form_error.message)

# Load UMP consent form
func load_form() -> void:
	UserMessagingPlatform.load_consent_form(_on_consent_form_load_success, _on_consent_form_load_failure)
	
func _on_consent_form_load_success(consent_form : ConsentForm) -> void:
	_consent_form = consent_form
	if UserMessagingPlatform.consent_information.get_consent_status() == UserMessagingPlatform.consent_information.ConsentStatus.REQUIRED:
		consent_form.show(_on_consent_form_dismissed)

func _on_consent_form_load_failure(form_error : FormError) -> void:
	# Handle the error.
	print(form_error.message)
	
func _on_consent_form_dismissed(_form_error : FormError) -> void:
	if UserMessagingPlatform.consent_information.get_consent_status() == UserMessagingPlatform.consent_information.ConsentStatus.OBTAINED:
		# App can start requesting ads.
		MobileAds.initialize()
		return
	# Handle dismissal by reloading form
	load_form()
	
## Call this to manually check if the player is in an area with a consent form. Like in settings
func manual_check_messaging_consent() -> void:
	var request: ConsentRequestParameters = ConsentRequestParameters.new()
	request.tag_for_under_age_of_consent = false
	UserMessagingPlatform.consent_information.update(request, _on_manual_consent_info_updated_success, _on_consent_info_updated_failure)

func _on_manual_consent_info_updated_success() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		has_form.emit()
		load_manual_form()
		
func load_manual_form() -> void:
	UserMessagingPlatform.load_consent_form(_on_manual_consent_form_load_success, _on_consent_form_load_failure)
	
## Emits a signal when a manual consent form is successfully loaded,
## use this to show a button or some option to open the consent form
func _on_manual_consent_form_load_success(consent_form : ConsentForm) -> void:
	_consent_form = consent_form
	manual_form_loaded.emit()
		
## Show the manual consent form (like in settings)
func manual_show_form() -> void:
	_consent_form.show(_on_consent_form_dismissed)
