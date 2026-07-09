extends Control

## Math-challenge friction gate shown before a flagged-child session reaches a
## purchase or destructive action; not full verifiable parental consent.

signal passed
signal failed
signal cancelled

const QUESTION_TEXT: String = "What is 25 - 20?"
const CORRECT_ANSWER: int = 5

@onready var question_label: Label = $CanvasLayer/Control/PanelContainer/VBoxContainer/QuestionLabel
@onready var answer_input: LineEdit = $CanvasLayer/Control/PanelContainer/VBoxContainer/AnswerInput
@onready var wrong_answer_label: Label = $CanvasLayer/Control/PanelContainer/VBoxContainer/WrongAnswerLabel

func _ready() -> void:
	question_label.text = QUESTION_TEXT

func _on_confirm_pressed() -> void:
	var entered: String = answer_input.text.strip_edges()
	if entered.is_valid_int() and entered.to_int() == CORRECT_ANSWER:
		passed.emit()
	else:
		failed.emit()
		wrong_answer_label.visible = true
		answer_input.text = ""

func _on_cancel_pressed() -> void:
	cancelled.emit()
