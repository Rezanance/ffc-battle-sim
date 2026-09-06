extends Node

const Target = Skill.Target
const Zone = Formation.Zone

signal event_queued()

@export var battling_component: BattlingComponent
@export var player_formation_ui: FormationUI
@export var opponent_formation_ui: FormationUI
@export var swap_to_ez_btn: TextureButton
@export var end_turn_btn: TextureButton
@export var back_btn: TextureButton
@export var ok_btn: TextureButton
@export var waiting_for_server_overlay: Panel
@export var animation_player: AnimationPlayer

var event_queue: Array[EventCallback] = []
var formations_ui: Dictionary[int, FormationUI] = {}

func _ready() -> void:
	var player_id: int = Networking.player_info.player_id
	var opponent_id: int = Networking.opponent_info.player_id
	formations_ui[player_id] = player_formation_ui
	formations_ui[opponent_id] = opponent_formation_ui

	animation_player.play('blink_transparent')
	
	player_formation_ui.vivosaur_selected.connect(select_vivosaur.bind(player_id))
	player_formation_ui.skill_clicked.connect(show_skill_targets)
	opponent_formation_ui.vivosaur_selected.connect(select_vivosaur.bind(opponent_id))
	
	end_turn_btn.pressed.connect(end_turn)
	swap_to_ez_btn.pressed.connect(choose_swap_target)
	back_btn.pressed.connect(go_back)
	ok_btn.pressed.connect(ok_btn_pressed)
	
	ClientBattling.support_effects_applied.connect(queue_event.bind(update_support_effects))
	ClientBattling.first_player_determined.connect(queue_event.bind(show_who_goes_first))
	ClientBattling.turn_started.connect(queue_event.bind(start_turn))
	ClientBattling.fp_gained.connect(queue_event.bind(gain_fp))
	ClientBattling.fp_spent.connect(queue_event.bind(spend_fp))
	ClientBattling.vivosaur_damaged.connect(queue_event.bind(show_damage_taken))
	ClientBattling.vivosaur_swapped_to_ez.connect(queue_event.bind(swap_to_ez))
	ClientBattling.skill_missed.connect(queue_event.bind(show_skill_missed))
	ClientBattling.vivosaur_back_to_sz.connect(queue_event.bind(back_to_sz))
	
	await get_tree().create_timer(0.25).timeout
	player_formation_ui.initialize()
	await opponent_formation_ui.initialize()
	
	battling_component.notify_battle_scene_loaded()
	
	process_events()

func queue_event(event: Variant, callback: Callable) -> void:
	event_queue.append(EventCallback.new(event, callback))
	event_queued.emit()

func process_events() -> void:
	while true:
		var event_callback: EventCallback = event_queue.pop_front()
		if event_callback:
			await event_callback.callback.call(event_callback.event)
		else:
			await event_queued

func update_support_effects(event: SupportEffectsAppliedEvent) -> void:
	var formation_ui: FormationUI = formations_ui[event.player_id]
	var target_formation_ui: FormationUI = formations_ui[event.target_player_id]
	var target_formation: Formation = Battling.formations[event.target_player_id]
	
	await formation_ui.vivosaur_sprite_zones[event.support_zone].pulse()
	
	var target_az: Vivosaur = target_formation.az
	target_az.attack_modifier += event.attack_modifier
	target_az.defense_modifier += event.defense_modifier
	target_az.accuracy_modifier += event.accuracy_modifier
	target_az.evasion_modifier += event.evasion_modifier
	
	target_formation_ui.update_support_effects(target_az)
	
func show_who_goes_first(event: FirstPlayerDeterminedEvent) -> void:
	var player1_formation_ui: FormationUI = formations_ui[event.player1_id]
	var player2_formation_ui: FormationUI = formations_ui[event.player2_id]
	
	var sg: SignalGroup = SignalGroup.new()
	player1_formation_ui.show_who_goes_first(
		event.player1_total_lp,
		event.first_player_id == event.player1_id
	)
	player2_formation_ui.show_who_goes_first(
		event.player2_total_lp,
		event.first_player_id == event.player2_id
	)
	
	await sg.all([
		player1_formation_ui.first_player_revealed,
		player2_formation_ui.first_player_revealed
	])
	
func start_turn(event: TurnStartedEvent) -> void:
	var is_player_turn: bool = event.player_id == Networking.player_info.player_id
	var formation_ui: FormationUI = formations_ui[event.player_id]
	
	player_formation_ui.change_fp_banner(is_player_turn)
	opponent_formation_ui.change_fp_banner(not is_player_turn)

	if is_player_turn:
		for zone: Formation.Zone in Formation.Zone.values():
			var vivosaur: Vivosaur = Battling.formations[Networking.player_info.player_id].get_vivosaur_from_zone(zone)
			if vivosaur:
				vivosaur.can_use_skill = true
	
	await formation_ui.animate_turn_start()

	end_turn_btn.disabled = event.player_id != Networking.player_info.player_id
	swap_to_ez_btn.disabled = event.player_id != Networking.player_info.player_id or player_formation_ui.vivosaur_sprite_zones[Formation.Zone.EZ] != null

func end_turn() -> void:
	battling_component.notify_ending_turn()
	
	for zone: Formation.Zone in Formation.Zone.values():
		if zone == Formation.Zone.EZ:
			continue

		var vivosaur: Vivosaur = Battling.formations[Networking.player_info.player_id].get_vivosaur_from_zone(zone)
		var sprite: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[zone]
		if sprite:
			sprite.set_instance_shader_parameter('used_skill', false)
		if vivosaur:
			vivosaur.can_use_skill = false

	end_turn_btn.disabled = true
	swap_to_ez_btn.disabled = true

func gain_fp(event: FpGainedEvent) -> void:
	Battling.formations[event.player_id].fp = event.current_fp
	await formations_ui[event.player_id].animate_fp_gain(event)

func spend_fp(event: FpSpentEvent) -> void:
	Battling.formations[event.player_id].fp = event.current_fp
	await formations_ui[event.player_id].animate_fp_spent(event)
	
func select_vivosaur(zone: Formation.Zone, player_id: int) -> void:
	var previous_selection: VivosaurSelection = Battling.selection
	if previous_selection and not previous_selection.equals(VivosaurSelection.new(zone, player_id)):
		var previous_vivosaur_sprite_selected: VivosaurSprite = formations_ui[previous_selection.player_id].vivosaur_sprite_zones[previous_selection.zone]
		previous_vivosaur_sprite_selected.arrow.visible = false
	if Battling.target and not Battling.target.equals(VivosaurSelection.new(zone, player_id)):
		var previous_vivosaur_sprite_target: VivosaurSprite = formations_ui[Battling.target.player_id].vivosaur_sprite_zones[Battling.target.zone]
		previous_vivosaur_sprite_target.cursor.visible = false
		if Battling.ui_step == Battling.UI_STEP.CHOOSE_SWAP_TARGET:
			if Battling.target.zone == Formation.Zone.SZ1:
				player_formation_ui.get_node('EZ SZ1 Arrow').visible = false
				player_formation_ui.get_node('EZ SZ2 Arrow').visible = true
			else:
				player_formation_ui.get_node('EZ SZ1 Arrow').visible = true
				player_formation_ui.get_node('EZ SZ2 Arrow').visible = false


	Battling.selection = VivosaurSelection.new(zone, player_id)
	Battling.target = VivosaurSelection.new(zone, player_id)
	
func show_skill_targets(skill: Skill) -> void:
	Battling.ui_step = Battling.UI_STEP.CHOOSE_SKILL_TARGET
	var ally_az: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[Zone.AZ]
	var ally_sz1: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[Zone.SZ1]
	var ally_sz2: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[Zone.SZ2]
	var ally_ez: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[Zone.EZ]

	var enemy_az: VivosaurSprite = opponent_formation_ui.vivosaur_sprite_zones[Zone.AZ]
	var enemy_sz1: VivosaurSprite = opponent_formation_ui.vivosaur_sprite_zones[Zone.SZ1]
	var enemy_sz2: VivosaurSprite = opponent_formation_ui.vivosaur_sprite_zones[Zone.SZ2]
	var enemy_ez: VivosaurSprite = opponent_formation_ui.vivosaur_sprite_zones[Zone.EZ]

	var initiator_sprite: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[Battling.selection.zone]
	initiator_sprite.set_instance_shader_parameter('is_using_skill', true)

	var ally_modulate: Color = Color.BLUE
	var enemy_modulate: Color = Color.RED

	Battling.initiator = Battling.selection.zone
	Battling.skill_id_selected = skill.id
	back_btn.visible = true
	ok_btn.visible = true
	reset_targets()

	match skill.target:
		Target.ALL:
			if ally_az: ally_az.cursor.visible = true
			if ally_sz1: ally_sz1.cursor.visible = true
			if ally_sz2: ally_sz2.cursor.visible = true
			if ally_ez: ally_ez.cursor.visible = true

			if enemy_az: enemy_az.cursor.visible = true
			if enemy_sz1: enemy_sz1.cursor.visible = true
			if enemy_sz2: enemy_sz2.cursor.visible = true
			if enemy_ez: enemy_ez.cursor.visible = true
		Target.ALL_ALLIES:
			if ally_az: ally_az.cursor.visible = true
			if ally_sz1: ally_sz1.cursor.visible = true
			if ally_sz2: ally_sz2.cursor.visible = true
			if ally_ez: ally_ez.cursor.visible = true

			if ally_az: ally_az.self_modulate = ally_modulate
			if ally_sz1: ally_sz1.self_modulate = ally_modulate
			if ally_sz2: ally_sz2.self_modulate = ally_modulate
			if ally_ez: ally_ez.self_modulate = ally_modulate
		Target.ALL_ENEMIES:
			if enemy_az: enemy_az.cursor.visible = true
			if enemy_sz1: enemy_sz1.cursor.visible = true
			if enemy_sz2: enemy_sz2.cursor.visible = true
			if enemy_ez: enemy_ez.cursor.visible = true

			if enemy_az: enemy_az.self_modulate = enemy_modulate
			if enemy_sz1: enemy_sz1.self_modulate = enemy_modulate
			if enemy_sz2: enemy_sz2.self_modulate = enemy_modulate
			if enemy_ez: enemy_ez.self_modulate = enemy_modulate
		Target.ALLY:
			if ally_az:
				ally_az.self_modulate = ally_modulate
				ally_az.is_targetable = true
			if ally_sz1:
				ally_sz1.self_modulate = ally_modulate
				ally_sz1.is_targetable = true
			if ally_sz2:
				ally_sz2.self_modulate = ally_modulate
				ally_sz2.is_targetable = true
		Target.ALLY_AZ_AND_SZ:
			if ally_az: ally_az.cursor.visible = true
			if ally_sz1: ally_sz1.cursor.visible = true
			if ally_sz2: ally_sz2.cursor.visible = true

			if ally_az: ally_az.self_modulate = ally_modulate
			if ally_sz1: ally_sz1.self_modulate = ally_modulate
			if ally_sz2: ally_sz2.self_modulate = ally_modulate
		Target.ENEMY_AZ_AND_SZ:
			if enemy_az: enemy_az.cursor.visible = true
			if enemy_sz1: enemy_sz1.cursor.visible = true
			if enemy_sz2: enemy_sz2.cursor.visible = true

			if enemy_az: enemy_az.self_modulate = enemy_modulate
			if enemy_sz1: enemy_sz1.self_modulate = enemy_modulate
			if enemy_sz2: enemy_sz2.self_modulate = enemy_modulate
		Target.ALLY_EXCEPT_SELF:
			# TODO: enable cursors for other allies
			pass
		Target.ENEMY:
			if enemy_az:
				enemy_az.self_modulate = enemy_modulate
				enemy_az.is_targetable = true
				enemy_az.cursor.visible = true
				Battling.target = VivosaurSelection.new(Formation.Zone.AZ, Networking.opponent_info.player_id)
			if enemy_sz1 and Battling.initiator == Formation.Zone.AZ:
				enemy_sz1.self_modulate = enemy_modulate
				enemy_sz1.is_targetable = true
			if enemy_sz2 and Battling.initiator == Formation.Zone.AZ:
				enemy_sz2.self_modulate = enemy_modulate
				enemy_sz2.is_targetable = true
		Target.SELF:
			initiator_sprite.cursor.visible = true

func go_back() -> void:
	reset_targets()
	Battling.ui_step = Battling.UI_STEP.SELECT_ACTION

	var initiator_sprite: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[Battling.initiator]
	initiator_sprite.set_instance_shader_parameter('is_using_skill', false)

	Battling.target = null
	back_btn.visible = false
	ok_btn.visible = false

	player_formation_ui.get_node('EZ AZ Arrow').visible = false
	player_formation_ui.get_node('EZ SZ1 Arrow').visible = false
	player_formation_ui.get_node('EZ SZ2 Arrow').visible = false

func reset_targets() -> void:
	var ally_az: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[Zone.AZ]
	var ally_sz1: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[Zone.SZ1]
	var ally_sz2: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[Zone.SZ2]
	var ally_ez: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[Zone.EZ]

	var enemy_az: VivosaurSprite = opponent_formation_ui.vivosaur_sprite_zones[Zone.AZ]
	var enemy_sz1: VivosaurSprite = opponent_formation_ui.vivosaur_sprite_zones[Zone.SZ1]
	var enemy_sz2: VivosaurSprite = opponent_formation_ui.vivosaur_sprite_zones[Zone.SZ2]
	var enemy_ez: VivosaurSprite = opponent_formation_ui.vivosaur_sprite_zones[Zone.EZ]

	if ally_az:
		ally_az.self_modulate = Color.WHITE
		ally_az.is_targetable = false
		ally_az.cursor.visible = false
	if ally_sz1:
		ally_sz1.self_modulate = Color.WHITE
		ally_sz1.is_targetable = false
		ally_sz1.cursor.visible = false
	if ally_sz2:
		ally_sz2.self_modulate = Color.WHITE
		ally_sz2.is_targetable = false
		ally_sz2.cursor.visible = false
	if ally_ez:
		ally_ez.self_modulate = Color.WHITE
		ally_ez.is_targetable = false
		ally_ez.cursor.visible = false
	
	if enemy_az:
		enemy_az.self_modulate = Color.WHITE
		enemy_az.is_targetable = false
		enemy_az.cursor.visible = false
	if enemy_sz1:
		enemy_sz1.self_modulate = Color.WHITE
		enemy_sz1.is_targetable = false
		enemy_sz1.cursor.visible = false
	if enemy_sz2:
		enemy_sz2.self_modulate = Color.WHITE
		enemy_sz2.is_targetable = false
		enemy_sz2.cursor.visible = false
	if enemy_ez:
		enemy_ez.self_modulate = Color.WHITE
		enemy_ez.is_targetable = false
		enemy_ez.cursor.visible = false

func ok_btn_pressed() -> void:
	match Battling.ui_step:
		Battling.UI_STEP.CHOOSE_SKILL_TARGET:
			use_skill()
		Battling.UI_STEP.CHOOSE_SWAP_TARGET:
			swap_target()

func use_skill() -> void:
	battling_component.notify_skill_used(
		Battling.initiator,
		Battling.skill_id_selected,
		Battling.target.player_id,
		Battling.target.zone,
	)
	waiting_for_server_overlay.visible = true

	var initiator_sprite: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[Battling.initiator]
	Battling.formations[Networking.player_info.player_id].get_vivosaur_from_zone(Battling.initiator).can_use_skill = false
	initiator_sprite.set_instance_shader_parameter('used_skill', true)

func show_damage_taken(event: VivosaurDamagedEvent) -> void:
	go_back()

	waiting_for_server_overlay.visible = false

	var vivo_sprite_damaged: VivosaurSprite = formations_ui[event.player_id].vivosaur_sprite_zones[event.zone]
	var vivosaur: Vivosaur = Battling.formations[event.player_id].get_vivosaur_from_zone(event.zone)
	vivosaur.current_lp -= event.damage
	vivo_sprite_damaged.current_lp_bubble.get_node('HBox').get_node('CurrentLp').text = '%d' % vivosaur.current_lp

	var tween: Tween = create_tween()
	var direction: int = -1 if event.player_id == Networking.player_info.player_id else 1
	var original_position: Vector2 = vivo_sprite_damaged.position
	if not event.is_critical_hit:
		# Animate normal damage
		vivo_sprite_damaged.damage.scale = Vector2(1, 1)
		tween.tween_property(vivo_sprite_damaged, 'position', Vector2(original_position.x + (30 * direction), original_position.y), 0.25).set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(vivo_sprite_damaged, 'position', Vector2(original_position.x, original_position.y), 0.25)
	else:
		# Animate critical hit
		vivo_sprite_damaged.damage.scale = Vector2(2, 2)
		tween.tween_property(vivo_sprite_damaged, 'position', Vector2(original_position.x + (200 * direction), original_position.y), 0.25).set_trans(Tween.TRANS_ELASTIC)
		tween.set_parallel()
		tween.tween_property(vivo_sprite_damaged, 'rotation', 1.047 * direction, 0.25)
		tween.set_parallel(false)
		tween.tween_property(vivo_sprite_damaged, 'rotation', 0, 0.25)
		tween.tween_property(vivo_sprite_damaged, 'position', Vector2(original_position.x, original_position.y), 0.75)

	vivo_sprite_damaged.life_bar.size.x = event.current_lp_percent

	vivo_sprite_damaged.arrow.visible = false
	vivo_sprite_damaged.damage.text = '%d' % event.damage
	vivo_sprite_damaged.damage.visible = true
	vivo_sprite_damaged.animation_player.play('show_damage')
	await vivo_sprite_damaged.animation_player.animation_finished
	vivo_sprite_damaged.damage.visible = false

func choose_swap_target() -> void:
	Battling.ui_step = Battling.UI_STEP.CHOOSE_SWAP_TARGET
	var ally_sz1: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[Zone.SZ1]
	var ally_sz2: VivosaurSprite = player_formation_ui.vivosaur_sprite_zones[Zone.SZ2]
	player_formation_ui.get_node('EZ AZ Arrow').visible = true

	if ally_sz1:
		ally_sz1.self_modulate = Color.BLUE
		ally_sz1.is_targetable = true
		ally_sz1.cursor.visible = true
		player_formation_ui.get_node('EZ SZ1 Arrow').visible = true
		Battling.target = VivosaurSelection.new(Formation.Zone.SZ1, Networking.player_info.player_id)

	if ally_sz2:
		ally_sz2.self_modulate = Color.BLUE
		ally_sz2.is_targetable = true
		ally_sz2.cursor.visible = not ally_sz1
		player_formation_ui.get_node('EZ SZ2 Arrow').visible = not ally_sz1
		Battling.target = VivosaurSelection.new(Formation.Zone.SZ2, Networking.player_info.player_id) if not ally_sz1 else Battling.target

	back_btn.visible = true
	ok_btn.visible = true

func swap_target() -> void:
	battling_component.notify_swap_to_ez(Battling.target.zone)

func swap_to_ez(event: VivosaurSwappedToEZEvent) -> void:
	go_back()

	var target_formation_ui: FormationUI = formations_ui[event.player_id]
	var target_formation: Formation = Battling.formations[event.player_id]
	var target_az: Vivosaur = target_formation.az
	target_az.attack_modifier = 0
	target_az.defense_modifier = 0
	target_az.accuracy_modifier = 0
	target_az.evasion_modifier = 0
	target_formation_ui.update_support_effects(target_az)

	Battling.formations[event.player_id].swap_to_ez(event.support_zone)
	await formations_ui[event.player_id].animate_swap_to_ez(event)
	swap_to_ez_btn.disabled = Networking.player_info.player_id == event.player_id

func back_to_sz(event: VivosaurBackToSzEvent) -> void:
	Battling.formations[Networking.player_info.player_id].move_ez_back_to_sz(true)
	await formations_ui[event.player_id].animate_back_to_ez()

func show_skill_missed(event: SkillMissedEvent) -> void:
	go_back()

	waiting_for_server_overlay.visible = false

	await formations_ui[event.player_id].animate_miss(event)
