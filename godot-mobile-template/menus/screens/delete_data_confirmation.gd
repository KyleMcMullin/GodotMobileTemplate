extends "res://menus/components/menu_screen.gd"

func _on_confirm_pressed() -> void:
	%ConfirmButton.disabled = true
	AdManager.delete_all_user_data()
