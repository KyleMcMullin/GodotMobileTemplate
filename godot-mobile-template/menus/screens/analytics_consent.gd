extends "res://menus/components/menu_screen.gd"

func _ready() -> void:
	_sync_status()

func _sync_status() -> void:
	%StatusLabel.text = "Currently opted in" if PostHog.enabled else "Currently opted out"
	%OptInButton.disabled = AdManager.is_child or not AdManager.age_verified
	if AdManager.is_child:
		%StatusLabel.text = "Analytics are disabled for this age group."

func _on_opt_in_pressed() -> void:
	PostHog.enable()
	_sync_status()

func _on_opt_out_pressed() -> void:
	PostHog.disable()
	_sync_status()
