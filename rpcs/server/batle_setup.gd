extends Node


const Common = preload("res://server/rpc_impls/battle_setup/common.gd")
const InitializeBattle = preload("res://server/rpc_impls/battle_setup/initialize_battle.gd")
const RegisterTeamInitial = preload("res://server/rpc_impls/battle_setup/register_team_initial.gd")
const StartBattle = preload("res://server/rpc_impls/battle_setup/start_battle.gd")
const BattlingImpl = preload("res://server/rpc_impls/battling/impl.gd")

@rpc("any_peer", "call_remote", "reliable")
func initialize_battle(player1_id: int) -> void:
	assert(multiplayer.is_server())
	var player2_id: int = ServerVariables.challenge_requests[player1_id]
	var battle_id: int = InitializeBattle.generate_battle_id()
	InitializeBattle.initialize_global_vars(battle_id, player1_id, player2_id)
	InitializeBattle.notify_contenders(battle_id, player1_id, player2_id)
	
@rpc("any_peer", 'call_remote', "reliable")
func register_team_initial(battle_id: int, team_info: Dictionary) -> void:
	assert(multiplayer.is_server())
	
	Common.register_team(battle_id, multiplayer.get_remote_sender_id(), team_info)
	var battle_info: BattleInfo = ServerVariables.battles[battle_id]
	var player1: int = battle_info.player1_id
	var player2: int = battle_info.player2_id
	if (player1 not in battle_info.responses_to_server or
	player2 not in battle_info.responses_to_server):
		return
	ServerVariables.battles[battle_id].responses_to_server = []
	
	RegisterTeamInitial.start_battle_setup_timer(battle_id)
	RegisterTeamInitial.notify_battle_prep_started(battle_id)

@rpc("any_peer", "call_remote", "reliable")
func ready_early(battle_id: int) -> void:
	assert(multiplayer.is_server())
	
	ServerVariables.battles[battle_id].responses_to_server.append(multiplayer.get_remote_sender_id())
	var battle_info: BattleInfo = ServerVariables.battles[battle_id]
	var player1: int = battle_info.player1_id
	var player2: int = battle_info.player2_id
	if (player1 not in battle_info.responses_to_server or
	player2 not in battle_info.responses_to_server):
		return
	
	ServerVariables.battles[battle_id].responses_to_server = []
	ServerVariables.battles[battle_id].timer.stop()
	ServerVariables.battles[battle_id].timer.timeout.emit()
	
@rpc("any_peer", "call_remote", "reliable")
func start_battle(battle_id: int, team_info_final: Dictionary) -> void:
	assert(multiplayer.is_server())
	
	Common.register_team(battle_id, multiplayer.get_remote_sender_id(), team_info_final)
	var battle_info: BattleInfo = ServerVariables.battles[battle_id]
	var player1: int = battle_info.player1_id
	var player2: int = battle_info.player2_id
	if (player1 not in battle_info.responses_to_server or
	player2 not in battle_info.responses_to_server):
		return
	
	ServerVariables.battles[battle_id].responses_to_server = []
	var player1_formation: Formation = StartBattle.create_player_formation(
		battle_id,
		player1,
		BattlingImpl.notify_support_effects_applied.bind(player1, player2)
		)
	var player2_formation: Formation = StartBattle.create_player_formation(
		battle_id,
		player2,
		BattlingImpl.notify_support_effects_applied.bind(player1, player2)
	)
	var formations: Dictionary[int, Dictionary] = {
		player1: player1_formation.serialize(),
		player2: player2_formation.serialize()
	}

	var battlefield: BattleField = StartBattle.create_battle_field(
		battle_id,
		player1,
		player1_formation,
		player2,
		player2_formation,
	)

	battlefield.first_player_determined.connect(BattlingImpl.notify_first_player_determined.bind(player1, player2))
	battlefield.turn_started.connect(BattlingImpl.notify_turn_started.bind(player1, player2))
	battlefield.fp_gained.connect(BattlingImpl.notify_fp_gained.bind(player1, player2))
	battlefield.fp_spent.connect(BattlingImpl.notify_fp_spent.bind(player1, player2))
	battlefield.vivosaur_damaged.connect(BattlingImpl.notify_vivosaur_damaged.bind(player1, player2))
	battlefield.vivosaur_swapped_to_ez.connect(BattlingImpl.notify_vivosaur_swapped_to_ez.bind(player1, player2))
	battlefield.skill_missed.connect(BattlingImpl.notify_skill_missed.bind(player1, player2))
	battlefield.vivosaur_back_to_sz.connect(BattlingImpl.notify_vivosaur_back_to_sz.bind(player1, player2))

	ClientBattleSetup.notify_battle_start.rpc_id(
		player1,
		formations
	)
	ClientBattleSetup.notify_battle_start.rpc_id(
		player2,
		formations
	)
