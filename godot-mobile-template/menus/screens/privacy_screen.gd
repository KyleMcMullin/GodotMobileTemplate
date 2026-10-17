extends "res://menus/components/menu_screen.gd"

func _ready() -> void:
	%ConsentButton.visible = AdManager.is_privacy_options_required()
	AdManager.privacy_options_available.connect(_on_privacy_options_available)
	AdManager.check_privacy_options()

func _on_privacy_options_available() -> void:
	%ConsentButton.visible = true

func _on_policy_pressed() -> void:
	OS.shell_open(AppConfig.PRIVACY_POLICY_URL)

func _on_terms_pressed() -> void:
	OS.shell_open(AppConfig.TERMS_URL)

func _on_analytics_pressed() -> void:
	ScreenSwitcher.switch_screen_transition(ScreenSwitcher.SCREEN.ANALYTICS_CONSENT)

func _on_consent_pressed() -> void:
	AdManager.show_privacy_options_form()

func _on_delete_pressed() -> void:
	ScreenSwitcher.switch_screen_transition(ScreenSwitcher.SCREEN.DELETE_DATA_CONFIRMATION)
