extends TextureButton
class_name VivosaurSprite

const UI_STEP = Battling.UI_STEP

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var arrow: TextureRect = $Arrow
@onready var cursor: AnimatedSprite2D = $Cursor
@onready var damage: Label = $Damage
@onready var life_bar: ColorRect = $LifeBar/Main
@onready var current_lp_bubble: Panel = $CurrentLpBubble

# Removed for now 
# enum PanelPosition {LEFT, RIGHT}
# @export var current_lp_position: PanelPosition = PanelPosition.LEFT

var id: String
var is_targetable: bool = false

func _ready() -> void:
	cursor.play()
	pressed.connect(_on_pressed)
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)

	# if current_lp_position == PanelPosition.RIGHT:
	# 	current_lp_bubble.position.x = 160

func pulse() -> void:
	animation_player.play("pulse")
	await animation_player.animation_finished

func _on_pressed() -> void:
	if is_targetable:
		cursor.visible = true
	animation_player.play("arrow")
	arrow.visible = true

func _mouse_entered() -> void:
	current_lp_bubble.visible = true

func _mouse_exited() -> void:
	current_lp_bubble.visible = false