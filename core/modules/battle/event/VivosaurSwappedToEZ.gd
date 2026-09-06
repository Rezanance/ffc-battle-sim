class_name VivosaurSwappedToEZEvent

var player_id: int
var support_zone: Formation.Zone

func _init(_player_id: int, _support_zone: Formation.Zone) -> void:
	player_id = _player_id
	support_zone = _support_zone
	
func serialize() -> Dictionary[String, Variant]:
	return {
		'player_id': player_id,
		'support_zone': support_zone,
	}

static func deserialize(event_dict: Dictionary[String, Variant]) -> VivosaurSwappedToEZEvent:
	return VivosaurSwappedToEZEvent.new(
		event_dict['player_id'],
		event_dict['support_zone'],
	)
