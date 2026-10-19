extends Node

signal got_ad_free
signal ad_free_changed(has_it: bool)
signal rewarded_ad_unavailable
signal privacy_options_available
## Clear game-specific save files/caches here before the template deletes its files.
signal user_data_deleting

signal has_form
signal manual_form_loaded

## Emitted once the AdMob SDK has finished initializing and ads may be loaded.
signal ads_initialized

var is_development: bool = false

## The Next-Gen Mobile Ads SDK initializes strictly asynchronously and throws if an ad
## is loaded beforehand, so ad-loading code must gate on this (or await [signal ads_initialized]).
var is_initialized: bool = false

var _initialization_requested: bool = false
var _initialization_listener: OnInitializationCompleteListener
var _consent_form_shown: bool = false
var _rewarded_in_flight: bool = false

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

## One entry per place the game offers a rewarded unlock, so each can be reported
## on and priced separately in AdMob.
enum REWARDED_AD {} # example: EXTRA_LIVES

## Google's public test unit is "ca-app-pub-3940256099942544/5224354917"; swap in
## the real unit ids before release.
const REWARDED_AD_UNIT_IDS: Dictionary = {} # example: REWARDED_AD.EXTRA_LIVES: "ca-app-pub-.../..."

var _rewarded_ad: RewardedAd
## Runs only once the user actually earns the reward, never on skip or failure.
var _on_rewarded_earned: Callable = Callable()
var _rewarded_load_callback: RewardedAdLoadCallback = RewardedAdLoadCallback.new()
var _rewarded_content_callback: FullScreenContentCallback = FullScreenContentCallback.new()
var _rewarded_earned_listener: OnUserEarnedRewardListener = OnUserEarnedRewardListener.new()

var config: ConfigFile = ConfigFile.new()
const config_path: String = "user://user_config.cfg"

var _consent_form: ConsentForm

func _ready() -> void:
	_load_config_file()
	_apply_child_directed_request_configuration()
	_setup_rewarded_callbacks()
	# On a first launch the age gate hasn't been answered yet, so the consent
	# request would carry the wrong age tagging. set_child_directed() starts the
	# flow instead, once the player has told us how old they are.
	if age_verified:
		start_consent_flow()

## Updates consent information and, if a form is required, shows it.
## Otherwise, if consent has already been obtained, initializes the ads plugin.
func start_consent_flow() -> void:
	var request: ConsentRequestParameters = ConsentRequestParameters.new()
	request.tag_for_under_age_of_consent = is_child
	UserMessagingPlatform.consent_information.update(request, _on_consent_info_updated_success, _on_consent_info_updated_failure)
	_initialize_ads_if_allowed()

## Kicks off SDK initialization, which is asynchronous. Safe to call more than once;
## only the first call reaches the SDK, since consent can resolve down two paths.
func _initialize_ads() -> void:
	if _initialization_requested:
		return
	_initialization_requested = true
	_initialization_listener = OnInitializationCompleteListener.new()
	_initialization_listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		is_initialized = true
		ads_initialized.emit()
	MobileAds.initialize(_initialization_listener)

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
## Starts the consent flow, deliberately deferred until now so the first UMP
## request is tagged correctly.
func set_child_directed(under_age: bool) -> void:
	is_child = under_age
	age_verified = true
	_save_config_file()
	_apply_child_directed_request_configuration()
	start_consent_flow()

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
## entitlement and the age-gate answer, then quits since state re-hydrates from
## disk on next launch.
func delete_all_user_data() -> void:
	PostHog.disable()
	PlatformServices.delete_save_data()
	user_data_deleting.emit()
	_wipe_config_preserving_purchase_and_age_gate()
	if FileAccess.file_exists(PostHog.USER_FILE_PATH):
		DirAccess.remove_absolute(PostHog.USER_FILE_PATH)
	get_tree().quit()

## Deletes the config file, then restores just the ad-free flag if the player had
## it. The age-gate answer is kept for the same reason in reverse: a wipe must
## not reclassify a child as an adult.
func _wipe_config_preserving_purchase_and_age_gate() -> void:
	var had_ad_free: bool = has_ad_free
	var was_age_verified: bool = age_verified
	var was_child: bool = is_child
	if FileAccess.file_exists(config_path):
		DirAccess.remove_absolute(config_path)
	config.clear()
	if had_ad_free:
		config.set_value("ads", "ad_free", true)
	if was_age_verified:
		config.set_value("child_safety", "age_verified", true)
		config.set_value("child_safety", "is_child", was_child)
	if had_ad_free or was_age_verified:
		config.save(config_path)
	
func get_ad_free() -> void:
	#pass
	# Uncomment above and comment below when needed to test ads
	has_ad_free = true
	got_ad_free.emit()
	ad_free_changed.emit(true)
	_save_config_file()
	
# This is ad_free that expires when the session (app) closes, does not save to config file
func get_temporary_ad_free() -> void:
	has_temp_ad_free = true

## Loads and shows the rewarded ad for [param ad]. [param on_earned] runs only
## when the reward is genuinely earned - a skipped, failed, or dismissed ad grants
## nothing. Players who already paid for ad-free are rewarded immediately.
func show_rewarded_ad(ad: REWARDED_AD, on_earned: Callable) -> void:
	if not on_earned.is_valid() or _rewarded_in_flight:
		return
	# Off-device there is no ad inventory, so gated features would be unreachable
	if has_ad_free or is_development or not (PlatformServices.is_android() or PlatformServices.is_ios()):
		on_earned.call()
		return

	# Loading before the SDK is up throws, so treat it like any other load failure
	if not is_initialized or not _can_request_ads() or not REWARDED_AD_UNIT_IDS.has(ad):
		rewarded_ad_unavailable.emit()
		return

	_rewarded_in_flight = true
	_on_rewarded_earned = on_earned
	RewardedAdLoader.new().load(REWARDED_AD_UNIT_IDS[ad], AdRequest.new(), _rewarded_load_callback)

func _setup_rewarded_callbacks() -> void:
	_rewarded_load_callback.on_ad_loaded = _on_rewarded_ad_loaded
	_rewarded_load_callback.on_ad_failed_to_load = _on_rewarded_ad_failed_to_load
	_rewarded_earned_listener.on_user_earned_reward = _on_user_earned_reward
	_rewarded_content_callback.on_ad_dismissed_full_screen_content = _destroy_rewarded_ad
	_rewarded_content_callback.on_ad_failed_to_show_full_screen_content = func(ad_error: AdError) -> void:
		print("rewarded ad failed to show: ", ad_error.message)
		_destroy_rewarded_ad()
		rewarded_ad_unavailable.emit()

func _on_rewarded_ad_loaded(rewarded_ad: RewardedAd) -> void:
	_rewarded_ad = rewarded_ad
	_rewarded_ad.full_screen_content_callback = _rewarded_content_callback
	_rewarded_ad.show(_rewarded_earned_listener)

func _on_rewarded_ad_failed_to_load(ad_error: LoadAdError) -> void:
	print("rewarded ad failed to load: ", ad_error.message)
	_on_rewarded_earned = Callable()
	_rewarded_in_flight = false
	rewarded_ad_unavailable.emit()

func _on_user_earned_reward(_rewarded_item: RewardedItem) -> void:
	if _on_rewarded_earned.is_valid():
		var reward: Callable = _on_rewarded_earned
		_on_rewarded_earned = Callable()
		reward.call()

func _destroy_rewarded_ad() -> void:
	_rewarded_in_flight = false
	_on_rewarded_earned = Callable()
	if _rewarded_ad:
		_rewarded_ad.destroy()
		_rewarded_ad = null

func _on_consent_info_updated_success() -> void:
	# The consent information state was updated, so a form may now be available.
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		load_form()
	_initialize_ads_if_allowed()

func _on_consent_info_updated_failure(form_error : FormError) -> void:
	# Consent state falls back to whatever was cached; still start ads if that
	# cached state allows it, so a network blip doesn't kill the session.
	print(form_error.message)
	_initialize_ads_if_allowed()

func load_form() -> void:
	UserMessagingPlatform.load_consent_form(_on_consent_form_load_success, _on_consent_form_load_failure)

func _on_consent_form_load_success(consent_form : ConsentForm) -> void:
	var status: int = UserMessagingPlatform.consent_information.get_consent_status()
	if status == UserMessagingPlatform.consent_information.ConsentStatus.REQUIRED and !_consent_form_shown:
		_consent_form_shown = true
		consent_form.show(_on_consent_form_dismissed)
		return
	_initialize_ads_if_allowed()

func _on_consent_form_load_failure(form_error : FormError) -> void:
	print(form_error.message)
	_initialize_ads_if_allowed()

func _on_consent_form_dismissed(_form_error : FormError) -> void:
	# Never re-show the form here: a player who dismissed without consenting
	# would be trapped in a loop. They can revisit it from the privacy screen.
	_initialize_ads_if_allowed()
	_emit_privacy_options_availability()


## Re-checks consent state so the privacy screen can decide whether to offer the
## consent-revocation entry point. Required by GDPR wherever consent was needed.
func check_privacy_options() -> void:
	UserMessagingPlatform.consent_information.update(
		_consent_request(),
		_emit_privacy_options_availability,
		_on_consent_info_updated_failure
	)


func _emit_privacy_options_availability() -> void:
	if is_privacy_options_required():
		privacy_options_available.emit()
		has_form.emit()
		manual_form_loaded.emit()


func is_privacy_options_required() -> bool:
	var status: int = UserMessagingPlatform.consent_information.get_privacy_options_requirement_status()
	return status == UserMessagingPlatform.consent_information.PrivacyOptionsRequirementStatus.REQUIRED


## Opens the UMP privacy options form so the player can change or withdraw the
## ad-consent choice they made earlier.
func show_privacy_options_form() -> void:
	UserMessagingPlatform.show_privacy_options_form(_on_privacy_options_form_dismissed)


func _on_privacy_options_form_dismissed(form_error : FormError) -> void:
	if form_error:
		print(form_error.message)
	_initialize_ads_if_allowed()


## Compatibility aliases for games built from earlier template revisions.
func manual_check_messaging_consent() -> void:
	check_privacy_options()

func manual_show_form() -> void:
	show_privacy_options_form()

func _consent_request() -> ConsentRequestParameters:
	var request: ConsentRequestParameters = ConsentRequestParameters.new()
	request.tag_for_under_age_of_consent = is_child
	return request

func _can_request_ads() -> bool:
	var status: int = UserMessagingPlatform.consent_information.get_consent_status()
	return status == ConsentInformation.ConsentStatus.OBTAINED or status == ConsentInformation.ConsentStatus.NOT_REQUIRED

func _initialize_ads_if_allowed() -> void:
	if age_verified and _can_request_ads():
		_initialize_ads()
