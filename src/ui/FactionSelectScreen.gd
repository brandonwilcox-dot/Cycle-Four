## FactionSelectScreen.gd
## First screen after launch. Player picks faction and sub-path.
## On confirm, calls FactionManager.select_faction() and emits done signal.
## Design ref: core/16_first-session-flow.md -- Academy intro sequence.
extends Control

signal selection_confirmed()

## Faction definitions for button layout
const FACTIONS: Array[Dictionary] = [
	{
		"id":       "architects",
		"label":    "Architects",
		"tagline":  "Efficiency is virtue.\nBuild. Compound. Transcend.",
		"paths":    [["standard", "Standard"], ["spiritual_tech", "Spiritual-Tech"]],
	},
	{
		"id":       "bloom",
		"label":    "Bloom",
		"tagline":  "Life spreads.\nAdapt or be consumed.",
		"paths":    [["purist", "Purist"], ["assimilator", "Assimilator"]],
	},
	{
		"id":       "mesh",
		"label":    "Mesh",
		"tagline":  "Everything is a system.\nHack it.",
		"paths":    [["networked", "Networked"], ["dreamer", "Dreamer"]],
	},
]

@onready var faction_buttons: HBoxContainer   = $Center/VBox/FactionButtons
@onready var tagline_label: Label             = $Center/VBox/TaglineLabel
@onready var sub_path_buttons: HBoxContainer  = $Center/VBox/SubPathButtons
@onready var confirm_btn: Button              = $Center/VBox/ConfirmBtn

var _selected_faction: String  = ""
var _selected_sub_path: String = ""

func _ready() -> void:
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_on_confirm_pressed)
	_build_faction_buttons()

# -- Build UI dynamically --

func _build_faction_buttons() -> void:
	for f in FACTIONS:
		var btn := Button.new()
		btn.text = f["label"]
		btn.toggle_mode = true
		btn.button_group = ButtonGroup.new()
		btn.pressed.connect(_on_faction_pressed.bind(f))
		faction_buttons.add_child(btn)
	# Share a single ButtonGroup so only one is active
	var grp := ButtonGroup.new()
	for child in faction_buttons.get_children():
		(child as Button).button_group = grp

func _on_faction_pressed(faction_data: Dictionary) -> void:
	_selected_faction  = faction_data["id"]
	_selected_sub_path = ""
	tagline_label.text = faction_data["tagline"]
	confirm_btn.disabled = true

	# Clear and rebuild sub-path buttons
	for child in sub_path_buttons.get_children():
		child.queue_free()

	var sub_grp := ButtonGroup.new()
	for pair in faction_data["paths"]:
		var btn := Button.new()
		btn.text         = pair[1]
		btn.toggle_mode  = true
		btn.button_group = sub_grp
		btn.pressed.connect(_on_sub_path_pressed.bind(pair[0]))
		sub_path_buttons.add_child(btn)

func _on_sub_path_pressed(sub_path_id: String) -> void:
	_selected_sub_path   = sub_path_id
	confirm_btn.disabled = false

func _on_confirm_pressed() -> void:
	if _selected_faction.is_empty() or _selected_sub_path.is_empty():
		return
	FactionManager.select_faction(_selected_faction, _selected_sub_path)
	selection_confirmed.emit()
