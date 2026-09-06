class_name SkillMissedEvent

var player_id: int
var target_zone: Formation.Zone

func _init(_player_id: int, _target_zone: Formation.Zone) -> void:
	player_id = _player_id
	target_zone = _target_zone
	
func serialize() -> Dictionary[String, Variant]:
	return {
		'player_id': player_id,
		'target_zone': target_zone,
	}

static func deserialize(event_dict: Dictionary[String, Variant]) -> SkillMissedEvent:
	return SkillMissedEvent.new(
		event_dict['player_id'],
		event_dict['target_zone']
	)
