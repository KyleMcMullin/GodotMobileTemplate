extends Node

enum SCREEN {
	MAIN_MENU
}

const SCREEN_PATHS: Dictionary = {
	SCREEN.MAIN_MENU: "res://menus/screens/main_menu.tscn"
}

var current_screen: Control = null

# If you need substantial back button behavior you can add a stack here
# that stores old scenes that can be navigated back to like a browser.
# not including here since that's more advanced functionality than currently needing

func _ready() -> void:
	var root: Window = get_tree().root
	current_screen = get_tree().root.get_child(root.get_child_count() - 1)

## Switches screens with the transition screen
## See menus/components/transition_screen. Defaults to a simple fade in/out
func switch_screen_transition(screen: SCREEN) -> void:
	call_deferred("_deferred_switch_screen_transition", screen)
	
## Deferred switching screens with a transition, waits for the transition screen to cover
## current content, then replaces the screen with the new one
func _deferred_switch_screen_transition(screen: SCREEN) -> void:
	var new_screen: PackedScene = load(SCREEN_PATHS[screen])
	TransitionScreen.transition()
	await TransitionScreen.on_fade_out_finised
	current_screen.free()
	current_screen = new_screen.instantiate()
	get_tree().root.add_child(current_screen)
	get_tree().current_scene = current_screen

## Switch screens without using a transition
func switch_screen(screen: SCREEN) -> void:
	call_deferred("_deferred_switch_screen", screen)
	
## Deferred switching screens without a transition, instantly replaces them
func _deferred_switch_screen(screen: SCREEN) -> void:
	var new_screen: PackedScene = load(SCREEN_PATHS[screen])
	TransitionScreen.transition()
	await TransitionScreen.on_fade_out_finised
	current_screen.free()
	current_screen = new_screen.instantiate()
	get_tree().root.add_child(current_screen)
	get_tree().current_scene = current_screen
