extends Node

enum UI_STEP {SELECT_ACTION, CHOOSE_SKILL_TARGET, CHOOSE_SWAP_TARGET, WAIT_FOR_SERVER, WAIT_FOR_OPPONENT}

var formations: Dictionary[int, Formation] = {
	123: Formation.new(
		Vivosaur.new(123, DataLoader.load_vivosaur_info("Trex")),
		Vivosaur.new(123, DataLoader.load_vivosaur_info("Brachio")),
		Vivosaur.new(123, DataLoader.load_vivosaur_info("Mammoth")),
	),
	456: Formation.new(
		Vivosaur.new(456, DataLoader.load_vivosaur_info("Mammoth")),
		null,
		null
	)
}

var selection: VivosaurSelection
var initiator: Formation.Zone
var skill_id_selected: String
var target: VivosaurSelection
var ui_step: UI_STEP = UI_STEP.WAIT_FOR_SERVER