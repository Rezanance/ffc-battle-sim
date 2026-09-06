extends Node
class_name FormationUI

signal support_effects_updated()
signal first_player_revealed()
signal vivosaur_selected(zone: Formation.Zone)
signal skill_clicked(skill: Skill)

@export var total_lp_panel: TextureRect
@export var total_lp_panel_position: Control

@export var az_position: Control
@export var sz1_position: Control
@export var sz2_position: Control
@export var ez_position: Control

@export var vivosaur_sprite_1: VivosaurSprite
@export var vivosaur_sprite_2: VivosaurSprite
@export var vivosaur_sprite_3: VivosaurSprite

@export var support_effects: TextureRect

@export var fp_bg: TextureRect
@export var fp: Label
@export var fp_delta: Label

@export var turn_banner: Control
@export var turn_banner_start: Control

@export var is_player_formation: bool = true

@export var texture_manager: TextureManager
@export var vivosaur_summary: VivosaurSummary
@export var skills: VBoxContainer

var vivosaur_sprite_zones: Array[VivosaurSprite] = [null, null, null, null]

func initialize() -> void:
	initialize_vivosaur_sprites()
	await animate_vivosaur_entrance()

func initialize_vivosaur_sprites() -> void:
	var formation: Formation = get_formation()
	var az: Vivosaur = formation.az
	var sz1: Vivosaur = formation.sz1
	var sz2: Vivosaur = formation.sz2
	
	vivosaur_sprite_zones[Formation.Zone.AZ] = vivosaur_sprite_1
	vivosaur_sprite_zones[Formation.Zone.SZ1] = vivosaur_sprite_2
	vivosaur_sprite_zones[Formation.Zone.SZ2] = vivosaur_sprite_3
	
	_initialize_sprite(az, vivosaur_sprite_1)
	_initialize_sprite(sz1, vivosaur_sprite_2)
	_initialize_sprite(sz2, vivosaur_sprite_3)

func get_formation() -> Formation:
	if is_player_formation:
		return Battling.formations[Networking.player_info.player_id]
	else:
		return Battling.formations[Networking.opponent_info.player_id]
		

func _initialize_sprite(vivosaur: Vivosaur, sprite: VivosaurSprite) -> void:
	if vivosaur:
		var vivosaur_info: VivosaurInfo = vivosaur.vivosaur_info
		var vivosaur_resource: VivosaurResource = load("res://core/data/vivosaurs/%s.tres" % vivosaur_info.id)
		sprite.id = vivosaur_info.id
		sprite.texture_normal = vivosaur_resource.sprite
		sprite.get_node('LifeBar/Bg').texture = load('res://client/assets/lifebars/%d.png' % vivosaur_info.element)
		sprite.pressed.connect(_update_vivosaur_summary.bind(vivosaur))
		sprite.pressed.connect(_notify_vivosaur_selected.bind(vivosaur))
		sprite.current_lp_bubble.get_node('HBox').get_node('CurrentLp').text = '%d' % vivosaur.current_lp
	else:
		sprite.queue_free()

func _update_vivosaur_summary(vivosaur: Vivosaur) -> void:
	vivosaur_summary.update_summary(vivosaur.vivosaur_info.id)
	if is_player_formation:
		UIUtils.update_skills_shown(
			skills,
			vivosaur.vivosaur_info.skills,
			_on_skill_clicked,
			false,
			vivosaur.can_use_skill
		)
	else:
		UIUtils.clear_skills(skills)

func _notify_vivosaur_selected(vivosaur: Vivosaur) -> void:
	vivosaur_selected.emit(get_vivosaur_zone(vivosaur))

func get_vivosaur_zone(vivosaur: Vivosaur) -> Formation.Zone:
	for zone: int in Formation.Zone.values():
		var vivo_sprite: VivosaurSprite = vivosaur_sprite_zones[zone]
		if vivo_sprite != null and vivo_sprite.id == vivosaur.vivosaur_info.id:
			return zone as Formation.Zone
		
	return Formation.Zone.AZ
	
func _on_skill_clicked(event: InputEvent, skill: Skill) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and
	event.pressed and is_player_formation):
		UIUtils.clear_skills(skills)
		skill_clicked.emit(skill)
	
func initialize_turn_banner() -> void:
	var icon_id: int = Networking.player_info.icon_id if is_player_formation else Networking.opponent_info.icon_id
	var display_name: String = Networking.player_info.display_name if is_player_formation else Networking.opponent_info.display_name
	turn_banner.get_node('Icon').texture = load('res://client/assets/player-icons/%d.png' % icon_id)
	turn_banner.get_node('Name').text = display_name

func animate_vivosaur_entrance() -> void:
	var az_sprite: VivosaurSprite = vivosaur_sprite_zones[Formation.Zone.AZ]
	var sz1_sprite: VivosaurSprite = vivosaur_sprite_zones[Formation.Zone.SZ1]
	var sz2_sprite: VivosaurSprite = vivosaur_sprite_zones[Formation.Zone.SZ2]
	var tween: Tween = create_tween()
	if is_instance_valid(sz1_sprite):
		tween.tween_property(
			sz1_sprite,
			'global_position',
			sz1_position.global_position,
			0.2
		)
	tween.set_parallel()
	tween.tween_property(
		az_sprite,
		'global_position',
		az_position.global_position,
		0.2
	).set_delay(0.1)
	if is_instance_valid(sz2_sprite):
		tween.tween_property(
			sz2_sprite,
			'global_position',
			sz2_position.global_position,
			0.2
		).set_delay(0.2)
	await tween.finished

func update_support_effects(
	target_az: Vivosaur
) -> void:
	_format_support_modifier('Atk', target_az.attack_modifier)
	_format_support_modifier('Def', target_az.defense_modifier)
	_format_support_modifier('Acc', target_az.accuracy_modifier)
	_format_support_modifier('Eva', target_az.evasion_modifier)
	
	support_effects_updated.emit()

func _format_support_modifier(
	node: String,
	modifier: float
) -> void:
	var text: String
	var color: Color
	var percent: float = modifier * 100
	if percent >= 1:
		text = '+%d' % percent
		color = Color.AQUA
	elif percent <= -1:
		text = '%d' % percent
		color = Color.DEEP_PINK
	else:
		text = '-'
		color = Color.WHITE_SMOKE
	
	var modifier_label: Label = support_effects.get_node(node)
	modifier_label.text = text
	modifier_label.add_theme_color_override("font_color", color)
	

func show_who_goes_first(total_lp: int, is_first: bool) -> void:
	total_lp_panel.get_node('Lp').text = '%d' % total_lp
	total_lp_panel.visible = true
	
	var tween: Tween = create_tween()
	tween.tween_property(
		total_lp_panel,
		"global_position",
		total_lp_panel_position.global_position,
		0.33
	)
	await tween.finished
	
	var timeout: float = 0.5
	if is_first:
		timeout = 0.3
		tween = create_tween()
		var first_attack: TextureRect = total_lp_panel.get_node('FirstAttack')
		tween.tween_property(first_attack, "modulate", Color(1, 1, 1, 1), 0.1)
		tween.set_parallel()
		tween.tween_property(first_attack, "scale", Vector2(2, 2), 0.2)

		await tween.finished
		
	await get_tree().create_timer(timeout).timeout
	total_lp_panel.queue_free()
	first_player_revealed.emit()
	
func change_fp_banner(is_player_turn: bool) -> void:
	if is_player_turn and is_player_formation:
		fp_bg.texture = texture_manager.player_fp_bg_turn
	elif is_player_turn and not is_player_formation:
		fp_bg.texture = texture_manager.opponent_fp_bg_turn
	elif not is_player_turn and is_player_formation:
		fp_bg.texture = texture_manager.player_fp_bg_not_turn
	else:
		fp_bg.texture = texture_manager.opponent_fp_bg_not_turn
		

func animate_turn_start() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(turn_banner, "position", Vector2(0, 0), 0.2)
	await tween.finished
	
	await get_tree().create_timer(0.33).timeout
	
	turn_banner.position = turn_banner_start.position

func animate_fp_gain(event: FpGainedEvent) -> void:
	fp_delta.visible = true
	fp_delta.text = '+%d' % event.fp_diff
	
	var old_fp: int = event.current_fp - event.fp_diff
	const TIME_BETWEEN_INCREMENTS: float = 0.0056
	for i: int in range(1, event.fp_diff + 1, 5):
		fp.text = '%d' % (old_fp + i)
		await get_tree().create_timer(TIME_BETWEEN_INCREMENTS).timeout
	
	fp.text = '%d' % (old_fp + event.fp_diff)
	fp_delta.visible = false

func animate_fp_spent(event: FpSpentEvent) -> void:
	fp_delta.visible = true
	fp_delta.text = '-%d' % event.fp_cost
	
	var old_fp: int = event.current_fp + event.fp_cost
	var TIME_BETWEEN_INCREMENTS: float = 7 * event.fp_cost / 225000.0
	for i: int in range(1, event.fp_cost + 1, +5):
		fp.text = '%d' % (old_fp - i)
		await get_tree().create_timer(TIME_BETWEEN_INCREMENTS).timeout
	
	fp.text = '%d' % (old_fp - event.fp_cost)
	fp_delta.visible = false

func animate_swap_to_ez(event: VivosaurSwappedToEZEvent) -> void:
	var tween: Tween = create_tween()
	var duration: float = 0.5
	var az_sprite: VivosaurSprite = vivosaur_sprite_zones[Formation.Zone.AZ]

	tween.tween_property(az_sprite, 'position', ez_position.position, duration)
	tween.parallel()
	tween.tween_property(vivosaur_sprite_zones[event.support_zone], 'position', az_position.position, duration)

	az_sprite.set_instance_shader_parameter('used_skill', true)

	vivosaur_sprite_zones[Formation.Zone.EZ] = az_sprite
	vivosaur_sprite_zones[Formation.Zone.AZ] = vivosaur_sprite_zones[event.support_zone]
	vivosaur_sprite_zones[event.support_zone] = null

	await tween.finished

func animate_back_to_ez() -> void:
	var tween: Tween = create_tween()
	var duration: float = 0.5
	var ez_sprite: VivosaurSprite = vivosaur_sprite_zones[Formation.Zone.EZ]

	var position: Vector2 = sz1_position.position if vivosaur_sprite_zones[Formation.Zone.SZ1] == null else sz2_position.position
	var zone: Formation.Zone = Formation.Zone.SZ1 if vivosaur_sprite_zones[Formation.Zone.SZ1] == null else Formation.Zone.SZ2
	tween.tween_property(ez_sprite, 'position', position, duration)

	ez_sprite.set_instance_shader_parameter('used_skill', false)

	vivosaur_sprite_zones[zone] = vivosaur_sprite_zones[Formation.Zone.EZ]
	vivosaur_sprite_zones[Formation.Zone.EZ] = null

	await tween.finished


func animate_miss(event: SkillMissedEvent) -> void:
	vivosaur_sprite_zones[event.target_zone].animation_player.play('miss')

	await vivosaur_sprite_zones[event.target_zone].animation_player.animation_finished;

	vivosaur_sprite_zones[event.target_zone].animation_player.queue('RESET')
