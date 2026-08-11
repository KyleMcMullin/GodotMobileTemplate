extends Node

enum SCREEN {
	MAIN_MENU
}

const SCREEN_PATHS: Dictionary = {
	SCREEN.MAIN_MENU: "res://menus/screens/main_menu.tscn"
}

## Screens that reset the back stack, so they are always the bottom of history
const ROOT_SCREENS: Array[SCREEN] = [SCREEN.MAIN_MENU]

var current_screen: Control = null

## Which [enum SCREEN] [member current_screen] is, so back navigation can record it
var current_screen_id: SCREEN = SCREEN.MAIN_MENU

## Screens the back stack can return to, most recently left last
var _history: Array[SCREEN] = []

## Blocks a second press while a switch is already deferred, which would pop history twice
var _is_switching: bool = false

func _ready() -> void:
	var root: Window = get_tree().root
	current_screen = get_tree().root.get_child(root.get_child_count() - 1)

## Switches screens with the transition screen
## See menus/components/transition_screen. Defaults to a simple fade in/out
func switch_screen_transition(screen: SCREEN) -> void:
	_start_switch(screen, true, true)

## Switches screens instantly, with no transition veil
func switch_screen(screen: SCREEN) -> void:
	_start_switch(screen, true, false)

## Returns to the screen that opened the current one, falling back to the main menu
func go_back_transition() -> void:
	_start_back(true)

## Returns to the previous screen instantly, with no transition veil
func go_back() -> void:
	_start_back(false)

## Drops the back stack, for flows that should not be re-enterable
func clear_history() -> void:
	_history.clear()

func _start_back(use_transition: bool) -> void:
	if _is_switching:
		return
	var target: SCREEN = SCREEN.MAIN_MENU
	if not _history.is_empty():
		target = _history.pop_back()
	_start_switch(target, false, use_transition)

## Records the jump then defers the swap. [param record_history] is false for back
## navigation, which consumes history instead of adding to it
func _start_switch(screen: SCREEN, record_history: bool, use_transition: bool) -> void:
	if _is_switching:
		return
	_is_switching = true
	if screen in ROOT_SCREENS:
		_history.clear()
	elif record_history:
		# Jumping to a screen already behind us rewinds to it rather than stacking a duplicate
		var seen: int = _history.find(screen)
		if seen == -1:
			_history.append(current_screen_id)
		else:
			_history.resize(seen)
	current_screen_id = screen
	_deferred_switch.call_deferred(screen, use_transition)

## Waits for the transition screen to cover current content, then replaces the screen
func _deferred_switch(screen: SCREEN, use_transition: bool) -> void:
	var new_screen: PackedScene = load(SCREEN_PATHS[screen])
	if use_transition:
		TransitionScreen.transition()
		await TransitionScreen.on_fade_out_finised
	current_screen.free()
	current_screen = new_screen.instantiate()
	get_tree().root.add_child(current_screen)
	get_tree().current_scene = current_screen
	_is_switching = false
