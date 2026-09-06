extends Node

@rpc("any_peer", "call_remote", "reliable")
func client_battle_scene_loaded(battle_id: int) -> void:
	assert(multiplayer.is_server())
	
	var battle_info: BattleInfo = ServerVariables.battles[battle_id]
	var player1: int = battle_info.player1_id
	var player2: int = battle_info.player2_id
	battle_info.responses_to_server.append(multiplayer.get_remote_sender_id())
	if (player1 not in battle_info.responses_to_server or
	player2 not in battle_info.responses_to_server):
		return
	
	battle_info.responses_to_server = []
	var battlefield: BattleField = battle_info.battlefield
	battlefield.apply_support_effects(player1)
	battlefield.apply_support_effects(player2)
	
	battlefield.who_goes_first()
	
	battlefield.start_turn()

@rpc("any_peer", "call_remote", "reliable")
func end_turn(battle_id: int) -> void:
	assert(multiplayer.is_server())
	var sender_player_id: int = multiplayer.get_remote_sender_id()
	var battle_info: BattleInfo = ServerVariables.battles[battle_id]
	var battlefield: BattleField = battle_info.battlefield
	if sender_player_id != battlefield.turn_id:
		return
	
	battlefield.end_turn()
	battlefield.start_turn()

# TODO move to impl
@rpc("any_peer", "call_remote", "reliable")
func use_skill(battle_id: int, initiator_zone: int, skill_id: String, target_player_id: int = -1, target_zone: int = -1) -> void:
	assert(multiplayer.is_server())

	var initiator_player_id: int = multiplayer.get_remote_sender_id()
	
	var battle_info: BattleInfo = ServerVariables.battles[battle_id]
	var battlefield: BattleField = battle_info.battlefield
	
	if battlefield.turn_id != initiator_player_id:
		Logging.error('Player %d can\'t use a skill now. Not their turn' % initiator_player_id)
		return
	
	if [Formation.Zone.SZ1, Formation.Zone.SZ2].has(initiator_zone) and [Formation.Zone.SZ1, Formation.Zone.SZ2].has(target_zone):
		Logging.error('A vivosaur in the SZ cannot target another vivosaur in the enemy SZ, only the AZ')
	
	var initiator: Vivosaur = battlefield.formations[initiator_player_id].get_vivosaur_from_zone(initiator_zone)
	if not initiator:
		Logging.error('Vivosaur does not exist')
		return
	if not initiator.can_use_skill:
		Logging.error('This vivosaur already used a skill this turn')
		return
	
	var initiator_skill: Skill = initiator.vivosaur_info.skills.filter(func(skill: Skill) -> bool: return skill.id == skill_id)[0]

	var target: Vivosaur = (battlefield.formations[target_player_id].get_vivosaur_from_zone(target_zone)
		if target_player_id != -1 and target_zone != -1 else null)
	
	if not battlefield.formations[initiator_player_id].spend_fp(initiator_skill.fp_cost):
		Logging.error('Not enough FP use skill')
		return

	Logging.info('%d - Player %d\'s %s uses %s' % [battle_id, initiator_player_id, initiator.vivosaur_info.name, initiator_skill.name])
	
	match initiator_skill.target:
		Skill.Target.ENEMY:
			if not target:
				Logging.error('Single enemy target skills must specify a target')
				return
			if battlefield.is_hit(initiator, target):
				battlefield.calculate_damage(initiator_player_id, initiator, target, initiator_skill)
			# TODO: Check if move misses or hits
		Skill.Target.ENEMY_AZ_AND_SZ:
			var opponent_id: int = battlefield.get_opponent_id(initiator_player_id)
			for zone: Formation.Zone in [Formation.Zone.AZ, Formation.Zone.SZ1, Formation.Zone.SZ2]:
				target = battlefield.formations[opponent_id].get_vivosaur_from_zone(zone)
				if target and battlefield.is_hit(initiator, target):
					battlefield.calculate_damage(initiator_player_id, initiator, target, initiator_skill)
		_:
			Logging.error('Not implemented yet')
			return
	
	initiator.can_use_skill = false

@rpc("any_peer", "call_remote", "reliable")
func swap_to_ez(battle_id: int, target_zone: int) -> void:
	assert(multiplayer.is_server())

	var player_id: int = multiplayer.get_remote_sender_id()
	var battle_info: BattleInfo = ServerVariables.battles[battle_id]
	var battlefield: BattleField = battle_info.battlefield
	
	if battlefield.turn_id != player_id:
		Logging.error('Player %d can\'t swap to ez. Not their turn' % player_id)
		return

	if target_zone == Formation.Zone.AZ:
		Logging.error('Target zone can only be one of the SZs')
		return
	
	battlefield.formations[player_id].swap_to_ez(target_zone)
