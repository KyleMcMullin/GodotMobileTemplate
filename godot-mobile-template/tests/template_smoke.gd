extends Node

var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	# Stop before test writes if the runner did not isolate user:// correctly.
	var expected: String = OS.get_environment("TEMPLATE_TEST_USER_DIR")
	if expected.is_empty() or OS.get_user_data_dir().simplify_path() != expected.simplify_path():
		push_error("FAIL: Tests require disposable user data: expected %s, got %s" % [expected, OS.get_user_data_dir()])
		get_tree().quit(1)
		return
	_run.call_deferred()

func _run() -> void:
	check(not PostHog.enabled, "analytics default off")
	check(PostHog.distinct_id.is_empty(), "no identifier before consent")
	check(not FileAccess.file_exists(PostHog.USER_FILE_PATH), "no identifier on disk")
	check(not AdManager.age_verified, "fresh install requires age gate")
	check(not AdManager.is_development, "test ad bypass defaults off")
	_test_data_wipe()
	_test_analytics_child_guard()
	_test_cloud_config()
	await _test_analytics_requests()
	_test_reward_callbacks()
	await _test_audio()
	await _test_startup()
	await _test_navigation()
	print("Template smoke: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_data_wipe() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("policies", "has_accepted_policies", true)
	config.set_value("analytics", "PostHog", true)
	config.set_value("progress", "level", 99)
	config.set_value("audio", "play_music", false)
	config.save(AdManager.config_path)
	AdManager._load_config_file()
	AdManager.has_ad_free = true
	AdManager.age_verified = true
	AdManager.is_child = true
	AdManager._wipe_config_preserving_purchase_and_age_gate()
	config.clear()
	config.load(AdManager.config_path)
	check(config.get_value("ads", "ad_free", false), "wipe preserves purchase")
	check(config.get_value("child_safety", "is_child", false), "wipe preserves child flag")
	check(config.get_value("child_safety", "age_verified", false), "wipe preserves age verification")
	for section: String in ["policies", "analytics", "progress", "audio"]:
		check(not config.has_section(section), "wipe removes " + section)
	AdManager.has_ad_free = false
	AdManager.age_verified = false
	AdManager.is_child = false
	AdManager._wipe_config_preserving_purchase_and_age_gate()
	check(not FileAccess.file_exists(AdManager.config_path), "empty wipe leaves no config")

func _test_analytics_child_guard() -> void:
	AdManager.is_child = true
	AdManager.age_verified = true
	PostHog.enable()
	PostHog.capture("must_not_send")
	check(not PostHog.enabled, "child cannot opt in")
	check(PostHog.distinct_id.is_empty(), "child gets no analytics identifier")
	check(PostHog.get_child_count() == 0, "child creates no analytics requests")
	AdManager.is_child = false
	AdManager.age_verified = false

func _test_reward_callbacks() -> void:
	var rewards: Array[int] = [0]
	AdManager._on_rewarded_earned = func() -> void: rewards[0] += 1
	AdManager._on_user_earned_reward(null)
	AdManager._on_user_earned_reward(null)
	check(rewards[0] == 1, "duplicate reward callbacks grant once")
	AdManager._rewarded_in_flight = true
	AdManager._on_rewarded_earned = func() -> void: rewards[0] += 1
	AdManager._destroy_rewarded_ad()
	AdManager._on_user_earned_reward(null)
	check(rewards[0] == 1, "dismissed ad leaves no pending reward")
	check(not AdManager._rewarded_in_flight, "dismissal unlocks next ad")

func _test_cloud_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("child_safety", "is_child", true)
	config.set_value("analytics", "PostHog", false)
	config.set_value("ads", "ad_free", true)
	config.save(AdManager.config_path)
	var remote: ConfigFile = ConfigFile.new()
	remote.set_value("child_safety", "is_child", false)
	remote.set_value("analytics", "PostHog", true)
	remote.set_value("ads", "ad_free", false)
	remote.set_value("audio", "play_music", false)
	var snapshot: PlayGamesSnapshot = PlayGamesSnapshot.new({"content": remote.encode_to_text().to_utf8_buffer()})
	# No native plugin is needed to exercise the config merge.
	var services: Node = load("res://globals/google_play_services.gd").new()
	services._update_config_from_snapshot(snapshot)
	services.free()
	config.clear()
	config.load(AdManager.config_path)
	check(config.get_value("child_safety", "is_child", false), "cloud restore preserves local child flag")
	check(not config.get_value("analytics", "PostHog", true), "cloud restore preserves local consent")
	check(config.get_value("ads", "ad_free", false), "cloud restore preserves purchase")
	check(not AudioManager.play_music, "cloud restore applies audio preferences")
	DirAccess.remove_absolute(AdManager.config_path)

func _test_analytics_requests() -> void:
	var request: HTTPRequest = HTTPRequest.new()
	PostHog.add_child(request)
	PostHog._http_request_completed(0, 200, [], "{}".to_utf8_buffer(), request)
	await get_tree().process_frame
	check(not is_instance_valid(request), "completed analytics request freed")
	request = HTTPRequest.new()
	PostHog.add_child(request)
	PostHog.disable()
	await get_tree().process_frame
	check(not is_instance_valid(request), "opting out clears pending requests")
	check(PostHog.consent_answered, "opting out records an answer")
	PostHog.consent_answered = false
	DirAccess.remove_absolute(AdManager.config_path)

func _test_audio() -> void:
	AudioManager.adjust_music_mute(false)
	await get_tree().create_timer(0.6).timeout
	check(AudioManager.music_stream_player.volume_db < -70.0, "music mutes")
	AudioManager.adjust_music_mute(true)
	await get_tree().create_timer(0.6).timeout
	check(AudioManager.music_stream_player.volume_db > -1.0, "music resumes on unmute")
	DirAccess.remove_absolute(AdManager.config_path)

func _test_startup() -> void:
	var splash_scene: PackedScene = load("res://menus/screens/splash_screen.tscn")
	var splash: Control = splash_scene.instantiate()
	add_child(splash)
	check(splash.age_gate_container.visible, "fresh startup shows age gate")
	splash.age_input.text = "121"
	splash._on_age_submit_pressed()
	check(splash.invalid_age_label.visible, "invalid age rejected")
	splash.queue_free()
	await get_tree().process_frame
	var config: ConfigFile = ConfigFile.new()
	config.set_value("policies", "has_accepted_policies", true)
	config.save(AdManager.config_path)
	AdManager.age_verified = true
	splash = splash_scene.instantiate()
	add_child(splash)
	await get_tree().process_frame
	check(splash.analytics_container.visible, "interrupted consent prompt returns next launch")
	splash.queue_free()
	await get_tree().process_frame
	AdManager.age_verified = false

func _test_navigation() -> void:
	# The harness is a Node rather than a Control, matching the startup edge case.
	ScreenSwitcher.current_screen = null
	ScreenSwitcher.switch_screen(ScreenSwitcher.SCREEN.MAIN_MENU)
	await get_tree().process_frame
	check(ScreenSwitcher.current_screen != null, "switcher handles non-Control boot scene")
	ScreenSwitcher.current_screen.free()
	var boot: Control = load("res://menus/screens/splash_screen.tscn").instantiate()
	get_tree().root.add_child(boot)
	get_tree().current_scene = boot
	ScreenSwitcher.current_screen = null
	ScreenSwitcher.switch_screen(ScreenSwitcher.SCREEN.MAIN_MENU)
	await get_tree().process_frame
	check(not is_instance_valid(boot), "real boot splash is replaced, not left behind")
	for screen: ScreenSwitcher.SCREEN in [ScreenSwitcher.SCREEN.SETTINGS,
		ScreenSwitcher.SCREEN.PRIVACY, ScreenSwitcher.SCREEN.ANALYTICS_CONSENT,
		ScreenSwitcher.SCREEN.DELETE_DATA_CONFIRMATION, ScreenSwitcher.SCREEN.CREDITS]:
		ScreenSwitcher.switch_screen(screen)
		await get_tree().process_frame
		check(ScreenSwitcher.current_screen != null, "menu screen loads: " + str(screen))
	ScreenSwitcher.go_back()
	await get_tree().process_frame
	check(ScreenSwitcher.current_screen_id == ScreenSwitcher.SCREEN.DELETE_DATA_CONFIRMATION, "back returns to caller")
	ScreenSwitcher.switch_screen(ScreenSwitcher.SCREEN.MAIN_MENU)
	await get_tree().process_frame
	check(ScreenSwitcher._history.is_empty(), "root clears history")
	ScreenSwitcher.switch_screen_transition(ScreenSwitcher.SCREEN.SETTINGS)
	ScreenSwitcher.switch_screen_transition(ScreenSwitcher.SCREEN.PRIVACY)
	await get_tree().create_timer(1.0).timeout
	check(ScreenSwitcher.current_screen_id == ScreenSwitcher.SCREEN.SETTINGS, "rapid taps do not stack transitions")
	check(not ScreenSwitcher._is_switching, "transition completes and unlocks navigation")
