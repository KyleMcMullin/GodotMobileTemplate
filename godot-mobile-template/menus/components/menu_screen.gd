extends Control

## Shared Android back behavior for non-root menu screens.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _on_back_pressed() -> void:
	ScreenSwitcher.go_back_transition()
