extends Control

## Accepts the android back button and exits the app
## Root screens quit instead of going back, since there is nothing behind them
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		get_tree().quit()
