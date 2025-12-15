extends Node

## Util class that marks swipes in 4 direction (UP, DOWN, LEFT, RIGHT) in a way that "feels" right
## Emits signal swiped with the swipe direction

class_name DirectionalSwipe

signal swiped(direction: SWIPE_DIRECTION)

## Use this to block directions like [SWIPE_DIRECTION.UP, SWIPE_DIRECTION.DOWN] to only allow left/right swipes
@export var blocked_directions: Array[SWIPE_DIRECTION] = []

enum SWIPE_DIRECTION { LEFT, RIGHT, UP, DOWN }

var is_swiping: bool = false
var first_swipe_pos: Vector2
var last_swipe_pos: Vector2


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if is_swiping:
			is_swiping = false
			var x_diff: float = first_swipe_pos.x - last_swipe_pos.x
			var y_diff: float = first_swipe_pos.y - last_swipe_pos.y
			var swipe_direction: SWIPE_DIRECTION
			if abs(x_diff) > abs(y_diff):
				swipe_direction = SWIPE_DIRECTION.LEFT if x_diff > 0 else SWIPE_DIRECTION.RIGHT
			else:
				swipe_direction = SWIPE_DIRECTION.UP if y_diff > 0 else SWIPE_DIRECTION.DOWN
				
			# Early return if the direction is blocked
			if swipe_direction in blocked_directions: return
			
			print("Swiping " + SWIPE_DIRECTION.find_key(swipe_direction))
			swiped.emit(swipe_direction)
			
	if event is InputEventScreenDrag:
		if !is_swiping:
			first_swipe_pos = event.position
		
		is_swiping = true
		last_swipe_pos = event.position

## Block a direction for swiping in code
func block_direction(direction: SWIPE_DIRECTION) -> void:
	blocked_directions.append(direction)

## Clear all blocked swipe directions
func clear_blocked_directions() -> void:
	blocked_directions = []
