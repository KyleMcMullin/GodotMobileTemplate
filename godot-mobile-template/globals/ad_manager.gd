extends Node

signal got_ad_free

signal has_form
signal manual_form_loaded

var is_development: bool = false

var has_ad_free: bool = false
var has_temp_ad_free: bool = false

## Single source of truth for the age-gate result; other systems read this directly.
var is_child: bool = false
## Whether the age gate has been resolved, distinct from is_child so a default
## false can't be mistaken for a real "not a child" answer.
var age_verified: bool = false

## Max ad content rating requested for non-child sessions; child sessions are
## always hardcoded to MAX_AD_CONTENT_RATING_G.
const ADULT_MAX_AD_CONTENT_RATING: String = RequestConfiguration.MAX_AD_CONTENT_RATING_T

var config: ConfigFile = ConfigFile.new()
const config_path: String = "user://user_config.cfg"

var _consent_form: ConsentForm

func _ready() -> void:
	_load_config_file()
	_apply_child_directed_request_configuration()
	# Update consent information
	# If the player is in an area that requires specific consent that they have yet to provide
	# then show them the form
	# otherwise, if consent has been obtained, initialize the ads plugin
	var request: ConsentRequestParameters = ConsentRequestParameters.new()
	request.tag_for_under_age_of_consent = is_child
	UserMessagingPlatform.consent_information.update(request, _on_consent_info_updated_success, _on_consent_info_updated_failure)
	if UserMessagingPlatform.consent_information.get_consent_status() == UserMessagingPlatform.consent_information.ConsentStatus.OBTAINED:
		MobileAds.initialize()

## Load config file to check if they have ad free
func _load_config_file() -> bool:
	var err: Error = config.load(config_path)
	if err != OK:
		return false

	has_ad_free = config.get_value("ads", "ad_free", false)
	is_child = config.get_value("child_safety", "is_child", false)
	age_verified = config.get_value("child_safety", "age_verified", false)
	return true

## Call this when purchasing ad free to locally save that they have it
func _save_config_file() -> void:
	var _err: Error = config.load(config_path)
	config.set_value("ads", "ad_free", has_ad_free)
	config.set_value("child_safety", "is_child", is_child)
	config.set_value("child_safety", "age_verified", age_verified)
	config.save(config_path)
	#PlatformServices.cloud_save_config()

## Called by the age-gate flow as soon as a child/non-child determination is made.
func set_child_directed(under_age: bool) -> void:
	is_child = under_age
	age_verified = true
	_save_config_file()
	_apply_child_directed_request_configuration()

func _apply_child_directed_request_configuration() -> void:
	var request_configuration: RequestConfiguration = RequestConfiguration.new()
	if is_child:
		request_configuration.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.TRUE
		request_configuration.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G
	else:
		request_configuration.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.FALSE
		request_configuration.max_ad_content_rating = ADULT_MAX_AD_CONTENT_RATING
	MobileAds.set_request_configuration(request_configuration)

## Permanently erases all local and cloud user data except the ad-free purchase
## entitlement, then quits since state re-hydrates from disk on next launch.
func delete_all_user_data() -> void:
	PlatformServices.delete_save_data()
	_wipe_config_preserving_purchases()
	if FileAccess.file_exists(PostHog.USER_FILE_PATH):
		DirAccess.remove_absolute(PostHog.USER_FILE_PATH)
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()

## Deletes the config file, then restores just the ad-free flag if the player had it.
func _wipe_config_preserving_purchases() -> void:
	var had_ad_free: bool = has_ad_free
	if FileAccess.file_exists(config_path):
		DirAccess.remove_absolute(config_path)
	if had_ad_free:
		config.set_value("ads", "ad_free", true)
		config.save(config_path)
	
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
	request.tag_for_under_age_of_consent = is_child
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
