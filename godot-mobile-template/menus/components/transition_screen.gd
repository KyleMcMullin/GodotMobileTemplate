extends CanvasLayer

signal on_fade_out_finised

@export
var fade_out_time: float = .4
@export
var fade_in_time: float = .4

@export
var fade_out_color: Color
@export 
var fade_in_color: Color

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	color_rect.visible = false
	
func transition() -> void:
	color_rect.visible = true
	_fade_out()
	
func _fade_out() -> void:
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(color_rect, "modulate", fade_out_color, fade_out_time)
	tween.finished.connect(_fade_in)
	
func _fade_in() -> void:
	on_fade_out_finised.emit()
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(color_rect, "modulate", fade_in_color, fade_in_time)
	tween.finished.connect(_end_transition)
	
func _end_transition() -> void:
	color_rect.visible = false
	
