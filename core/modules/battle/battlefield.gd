class_name BattleField

const Element = VivosaurInfo.Element
const Zone = Formation.Zone

signal first_player_determined(first_player_determined_event: FirstPlayerDeterminedEvent)
signal turn_started(turn_started_event: TurnStartedEvent)
signal fp_gained(fp_gained_event: FpGainedEvent)
signal fp_spent(fp_spent_event: FpSpentEvent)
signal turn_ended(turn_ended_event: TurnEndedEvent)
signal vivosaur_damaged(vivosaur_damaged_event: VivosaurDamagedEvent)
signal vivosaur_swapped_to_ez(vivosaur_swapped_to_ez_event: VivosaurSwappedToEZEvent)
signal vivosaur_back_to_sz(vivosaur_back_to_sz_event: VivosaurBackToSzEvent)
signal skill_missed(skill_missed_event: SkillMissedEvent)

var player1_id: int
var player2_id: int
var formations: Dictionary[int, Formation]
var turn_id: int

func _init(
	_formations: Dictionary[int, Formation],
	_player1_id: int,
	_player2_id: int
) -> void:
	assert(len(_formations.keys()) == 2)

	formations = _formations
	turn_id = -1
	player1_id = _player1_id
	player2_id = _player2_id
	
	formations[player1_id].fp_gained.connect(func(fp_diff: int, current_fp: int) -> void:
		fp_gained.emit(FpGainedEvent.new(player1_id, fp_diff, current_fp))
	)
	formations[player2_id].fp_gained.connect(func(fp_diff: int, current_fp: int) -> void:
		fp_gained.emit(FpGainedEvent.new(player2_id, fp_diff, current_fp))
	)

	formations[player1_id].fp_spent.connect(func(fp_cost: int, current_fp: int) -> void:
		fp_spent.emit(FpSpentEvent.new(player1_id, fp_cost, current_fp))
	)
	formations[player2_id].fp_spent.connect(func(fp_cost: int, current_fp: int) -> void:
		fp_spent.emit(FpSpentEvent.new(player2_id, fp_cost, current_fp))
	)

	formations[player1_id].vivosaur_swapped_to_ez.connect(func(sz: Formation.Zone) -> void:
		vivosaur_swapped_to_ez.emit(VivosaurSwappedToEZEvent.new(player1_id, sz))
	)
	formations[player2_id].vivosaur_swapped_to_ez.connect(func(sz: Formation.Zone) -> void:
		vivosaur_swapped_to_ez.emit(VivosaurSwappedToEZEvent.new(player2_id, sz))
	)

	formations[player1_id].vivosaur_back_to_sz.connect(func() -> void:
		vivosaur_back_to_sz.emit(VivosaurBackToSzEvent.new(player1_id))
	)
	formations[player2_id].vivosaur_back_to_sz.connect(func() -> void:
		vivosaur_back_to_sz.emit(VivosaurBackToSzEvent.new(player2_id))
	)

func who_goes_first() -> int:
	var player_1_total_lp: int = formations[player1_id].calculate_total_lp()
	var player_2_total_lp: int = formations[player2_id].calculate_total_lp()
	var first_player_id: int
	
	if player_1_total_lp < player_2_total_lp:
		first_player_id = player1_id
	elif player_1_total_lp > player_2_total_lp:
		first_player_id = player2_id
	else:
		first_player_id = player1_id if randi() % 100 < 50 else player2_id
	
	first_player_determined.emit(FirstPlayerDeterminedEvent.new(
		first_player_id,
		player1_id,
		player2_id,
		player_1_total_lp,
		player_2_total_lp
	))
	
	turn_id = first_player_id
	return first_player_id

func start_turn() -> void:
	turn_started.emit(TurnStartedEvent.new(turn_id))

	formations[turn_id].move_ez_back_to_sz()

	apply_support_effects(turn_id)
#	TODO activate skills like Auto LP and FP plus
	
	if formations[turn_id].az: formations[turn_id].az.can_use_skill = true
	if formations[turn_id].sz1: formations[turn_id].sz1.can_use_skill = true
	if formations[turn_id].sz2: formations[turn_id].sz2.can_use_skill = true

	formations[turn_id].recharge_fp()

func end_turn() -> void:
	turn_ended.emit(TurnEndedEvent.new(turn_id))
	if formations[turn_id].az: formations[turn_id].az.can_use_skill = false
	if formations[turn_id].sz1: formations[turn_id].sz1.can_use_skill = false
	if formations[turn_id].sz2: formations[turn_id].sz2.can_use_skill = false
	
	turn_id = player1_id if turn_id == player2_id else player2_id

func determine_winner() -> Variant:
#	TODO
	return
	
func get_opponent_id(player_id: int) -> int:
	return player1_id if player_id == player2_id else player2_id

func apply_support_effects(player_id: int) -> void:
	var sz1: Vivosaur = formations[player_id].sz1
	var sz2: Vivosaur = formations[player_id].sz2
	var player_az: Vivosaur = formations[player_id].az
	var opponent_az: Vivosaur = formations[get_opponent_id(player_id)].az
	
	if sz1:
		sz1.apply_support_effects(player_id, Formation.Zone.SZ1, player_az, opponent_az)
	if sz2:
		sz2.apply_support_effects(player_id, Formation.Zone.SZ2, player_az, opponent_az)

func is_hit(initiator: Vivosaur, target: Vivosaur) -> bool:
	var acc_min_speed: float = initiator.vivosaur_info.stats.accuracy - target.vivosaur_info.stats.evasion
	var chance: float = 0
	if acc_min_speed < -10:
		chance = 0.1
	elif acc_min_speed >= -10 and acc_min_speed < 0:
		chance = 0.8 + 0.7 * sin(PI * acc_min_speed / 20)
	elif acc_min_speed >= 0 and acc_min_speed < 10:
		chance = 0.8 + 0.2 * sin(PI * acc_min_speed / 20)
	else:
		chance = 1
	
	var result: bool = randf() <= chance
	if not result:
		skill_missed.emit(SkillMissedEvent.new(target.player_id, self.formations[target.player_id].get_vivosaur_zone(target)))
	return result

func calculate_damage(initiator_player_id: int, initiator: Vivosaur, target: Vivosaur, skill: Skill) -> void:
	var initiator_formation: Formation = self.formations[initiator_player_id]
	var target_formation: Formation = self.formations[target.player_id]
	var element_multiplier: float = 1
	var initiator_element: Element = initiator.vivosaur_info.element
	var target_element: Element = target.vivosaur_info.element
	var range_multiplier: float = (initiator.vivosaur_info.stats.ranged_multiplier if
			(initiator_formation.get_vivosaur_zone(initiator) == Zone.AZ and [Zone.SZ1, Zone.SZ2].has(target_formation.get_vivosaur_zone(target)))
			or ([Zone.SZ1, Zone.SZ2].has(initiator_formation.get_vivosaur_zone(initiator)) and target_formation.get_vivosaur_zone(target) == Zone.AZ)
		else 1.0)
	var critical_hit_multiplier: float = 1.5 if skill.type != Skill.Type.TEAM_SKILL and randf() <= initiator.vivosaur_info.stats.crit_chance else 1.0

	# Favorable matchup
	if ((initiator_element == Element.AIR and target_element == Element.WATER)
			or (initiator_element == Element.EARTH and target_element == Element.AIR)
			or (initiator_element == Element.FIRE and target_element == Element.EARTH)
			or (initiator_element == Element.WATER and target_element == Element.FIRE)):
		element_multiplier = 1.5
	elif ((initiator_element == Element.AIR and target_element == Element.EARTH)
			or (initiator_element == Element.EARTH and target_element == Element.FIRE)
			or (initiator_element == Element.FIRE and target_element == Element.WATER)
			or (initiator_element == Element.WATER and target_element == Element.AIR)):
		element_multiplier = 0.75

	var damage: int = ((((initiator.vivosaur_info.stats.attack + skill.damage) * (1 + initiator.attack_modifier))
			- (target.vivosaur_info.stats.defense - (1 + target.defense_modifier)))
			* randfn(1.0, 0.025)
			* element_multiplier
			* range_multiplier
			* critical_hit_multiplier) as int
			# TODO: add parting blow modifier
	
	Logging.info('Damage info - atk: %d, skill dmg: %d, atk mod: %f, def: %d, def mod: %f, element mod: %f, range mod: %d, crit mod: %f' % [
		initiator.vivosaur_info.stats.attack, skill.damage, initiator.attack_modifier, target.vivosaur_info.stats.defense,
		target.defense_modifier, element_multiplier, range_multiplier, critical_hit_multiplier
	])

	if damage > 0:
		target.current_lp -= damage
		vivosaur_damaged.emit(VivosaurDamagedEvent.new(
			damage,
			target.current_lp / (target.vivosaur_info.stats.life_points as float) * 100,
			target.player_id,
			target_formation.get_vivosaur_zone(target),
			critical_hit_multiplier == 1.5,
		))
