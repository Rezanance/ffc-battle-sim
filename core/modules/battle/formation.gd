class_name Formation

signal fp_gained(fp_diff: int, current_fp: int)
signal fp_spent(fp_cost: int, current_fp: int)
signal vivosaur_swapped_to_ez(sz: Zone)
signal vivosaur_back_to_sz()

enum Zone {AZ, SZ1, SZ2, EZ}
const BASE_FP_RECHARGE: int = 180
const MAX_FP: int = 500
const FP_GAIN_AFTER_KNOCKOUT: int = BASE_FP_RECHARGE * 2

class PlayerZone:
	var player_id: int
	var zone: Zone
	
	func _init(_player_id: int, _zone: Zone) -> void:
		player_id = _player_id
		zone = _zone
	
	func equals(player_zone: PlayerZone) -> bool:
		return (
			self.player_id == player_zone.player_id and
			self.zone == player_zone.zone
		)

# Vivosaur | null
var az: Vivosaur
var sz1: Vivosaur
var sz2: Vivosaur
var ez: Vivosaur

var fp: int

var turns_left_in_ez: int

func _init(_az: Vivosaur, _sz1: Vivosaur = null, _sz2: Vivosaur = null) -> void:
	az = _az
	sz1 = _sz1
	sz2 = _sz2
	ez = null
	fp = 0
	turns_left_in_ez = 0

# Server shouldn't send the whole formation data since it can be computed on client side
# Just for initial formation
func serialize() -> Dictionary[String, Variant]:
	@warning_ignore("incompatible_ternary")
	return {
		'az': az.serialize(),
		'sz1': sz1.serialize() if sz1 else null,
		'sz2': sz2.serialize() if sz2 else null,
	}

static func deserialize(formation_dict: Dictionary[String, Variant]) -> Formation:
	return Formation.new(
		Vivosaur.deserialize(formation_dict['az']),
		Vivosaur.deserialize(formation_dict['sz1']) if formation_dict['sz1'] else null,
		Vivosaur.deserialize(formation_dict['sz2']) if formation_dict['sz2'] else null,
	)

func get_sz_vivosaurs() -> Array[Vivosaur]:
	return [sz1, sz2]

func calculate_total_lp() -> int:
	var az_lp: int = az.get('current_lp') if az != null else 0
	var sz1_lp: int = sz1.get('current_lp') if sz1 != null else 0
	var sz2_lp: int = sz2.get('current_lp') if sz2 != null else 0

	return az_lp + sz1_lp + sz2_lp

func recharge_fp() -> void:
	var fp_diff: int
	if fp + BASE_FP_RECHARGE > MAX_FP:
		fp_diff = MAX_FP - fp
		fp += fp_diff
	else:
		fp_diff = BASE_FP_RECHARGE
		fp += fp_diff
	
	fp_gained.emit(fp_diff, fp)

func spend_fp(fp_cost: int) -> bool:
	if fp - fp_cost < 0:
		return false

	fp -= fp_cost

	fp_spent.emit(fp_cost, fp)
	return true
	
func get_vivosaur_zone(vivo: Vivosaur) -> Zone:
	var az_id: String = az.vivosaur_info.id
	var sz1_id: String = sz1.vivosaur_info.id if sz1 else ''
	var sz2_id: String = sz2.vivosaur_info.id if sz2 else ''

	match vivo.vivosaur_info.id:
		az_id:
			return Zone.AZ
		sz1_id:
			return Zone.SZ1
		sz2_id:
			return Zone.SZ2
		_:
			return Zone.EZ

func get_vivosaur_from_zone(zone: Zone) -> Vivosaur:
	match zone:
		Zone.AZ:
			return az
		Zone.SZ1:
			return sz1
		Zone.SZ2:
			return sz2
	return ez
		

func swap_to_ez(support_zone: Zone) -> void:
	if ez:
		Logging.error('Cannot swap to EZ when there is already a vivosaur already in the EZ')
		return
	if not sz1 and not sz2:
		Logging.error('Must have a vivosaur in one of the support zones to swap to EZ')
		return
	 
	ez = az
	az = get_vivosaur_from_zone(support_zone)
	
	ez.attack_modifier = 0
	ez.defense_modifier = 0
	ez.accuracy_modifier = 0
	ez.evasion_modifier = 0

	az.attack_modifier = 0
	az.defense_modifier = 0
	az.accuracy_modifier = 0
	az.evasion_modifier = 0

	if support_zone == Zone.SZ1:
		sz1 = null
		vivosaur_swapped_to_ez.emit(Zone.SZ1)
	else:
		sz2 = null
		vivosaur_swapped_to_ez.emit(Zone.SZ2)
	
	ez.can_use_skill = false

	turns_left_in_ez = 3

func move_ez_back_to_sz(override_turns_left: bool = false) -> void:
	if turns_left_in_ez > 0:
		turns_left_in_ez -= 1
	
	if ez != null and (turns_left_in_ez == 0 or override_turns_left):
		vivosaur_back_to_sz.emit()
		ez.can_use_skill = true
		if not sz1:
			sz1 = ez
		else:
			sz2 = ez
