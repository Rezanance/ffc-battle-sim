const BattlingImpl = preload("res://server/rpc_impls/battling/impl.gd")

static func create_player_formation(
	battle_id: int,
	player_id: int,
	support_effect_applied_callback: Callable,
) -> Formation:
	var battle_info: BattleInfo = ServerVariables.battles[battle_id]
	var team: Team = battle_info.teams[player_id]
	@warning_ignore("incompatible_ternary")
	var slot1_vivo_id: Variant = team.slots[0].id if team.slots[0] else null
	@warning_ignore("incompatible_ternary")
	var slot2_vivo_id: Variant = team.slots[1].id if team.slots[1] else null
	@warning_ignore("incompatible_ternary")
	var slot3_vivo_id: Variant = team.slots[2].id if team.slots[2] else null
	
	var az: Vivosaur = Vivosaur.new(player_id, DataLoader.load_vivosaur_info(slot1_vivo_id))
	var sz1: Vivosaur = Vivosaur.new(player_id, DataLoader.load_vivosaur_info(slot2_vivo_id)) if slot2_vivo_id else null
	var sz2: Vivosaur = Vivosaur.new(player_id, DataLoader.load_vivosaur_info(slot3_vivo_id)) if slot3_vivo_id else null
	
	az.support_effects_applied.connect(support_effect_applied_callback)
	if sz1:
		sz1.support_effects_applied.connect(support_effect_applied_callback)
	if sz2:
		sz2.support_effects_applied.connect(support_effect_applied_callback)
	
	var formation: Formation = Formation.new(az, sz1, sz2)
	
	return formation

static func create_battle_field(
	battle_id: int,
	player1: int,
	player_1_formation: Formation,
	player2: int,
	player_2_formation: Formation,
) -> BattleField:
	var all_zones: Dictionary[int, Formation] = {}
	all_zones[player1] = player_1_formation
	all_zones[player2] = player_2_formation
	ServerVariables.battles[battle_id].battlefield = BattleField.new(
		all_zones,
		player1,
		player2
	)
	var battlefield: BattleField = ServerVariables.battles[battle_id].battlefield
	return battlefield
