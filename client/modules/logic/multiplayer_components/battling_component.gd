extends Node
class_name BattlingComponent

func notify_battle_scene_loaded() -> void:
	ServerBattling.client_battle_scene_loaded.rpc_id(
		Networking.SERVER_PEER_ID,
		Networking.battle_id
	)

func notify_ending_turn() -> void:
	ServerBattling.end_turn.rpc_id(
		Networking.SERVER_PEER_ID,
		Networking.battle_id
	)

func notify_skill_used(initiator_zone: Formation.Zone, skill_id: String, target_player_id: int, target_zone: Formation.Zone = Formation.Zone.EZ) -> void:
	ServerBattling.use_skill.rpc_id(
		Networking.SERVER_PEER_ID,
		Networking.battle_id,
		initiator_zone,
		skill_id,
		target_player_id,
		target_zone,
	)

func notify_swap_to_ez(target_zone: Formation.Zone) -> void:
	ServerBattling.swap_to_ez.rpc_id(
		Networking.SERVER_PEER_ID,
		Networking.battle_id,
		target_zone
	)