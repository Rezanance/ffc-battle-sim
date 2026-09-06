extends Node

signal support_effects_applied(event: SupportEffectsAppliedEvent)
signal first_player_determined(event: FirstPlayerDeterminedEvent)
signal turn_started(event: TurnStartedEvent)
signal fp_gained(event: FpGainedEvent)
signal fp_spent(event: FpSpentEvent)
signal vivosaur_damaged(event: VivosaurDamagedEvent)
signal vivosaur_swapped_to_ez(event: VivosaurSwappedToEZEvent)
signal vivosaur_back_to_sz(event: VivosaurBackToSzEvent)
signal skill_missed(event: SkillMissedEvent)

@rpc("authority", "call_remote", "reliable")
func notify_support_effects_applied(event_dict: Dictionary[String, Variant]) -> void:
	support_effects_applied.emit(SupportEffectsAppliedEvent.deserialize(event_dict))

@rpc("authority", "call_remote", "reliable")
func notify_first_player_determined(event_dict: Dictionary[String, int]) -> void:
	first_player_determined.emit(FirstPlayerDeterminedEvent.deserialize(event_dict))

@rpc("authority", "call_remote", "reliable")
func notify_turn_start(event_dict: Dictionary[String, int]) -> void:
	turn_started.emit(TurnStartedEvent.deserialize(event_dict))

@rpc("authority", "call_remote", "reliable")
func notify_fp_gained(event_dict: Dictionary[String, int]) -> void:
	fp_gained.emit(FpGainedEvent.deserialize(event_dict))

@rpc("authority", "call_remote", "reliable")
func notify_fp_spent(event_dict: Dictionary[String, int]) -> void:
	fp_spent.emit(FpSpentEvent.deserialize(event_dict))

@rpc("authority", "call_remote", "reliable")
func notify_vivosaur_damaged(event_dict: Dictionary[String, Variant]) -> void:
	vivosaur_damaged.emit(VivosaurDamagedEvent.deserialize(event_dict))

@rpc("authority", "call_remote", "reliable")
func notify_vivosaur_swapped_to_ez(event_dict: Dictionary[String, Variant]) -> void:
	vivosaur_swapped_to_ez.emit(VivosaurSwappedToEZEvent.deserialize(event_dict))

@rpc("authority", "call_remote", "reliable")
func notify_skill_missed(event_dict: Dictionary[String, Variant]) -> void:
	skill_missed.emit(SkillMissedEvent.deserialize(event_dict))

@rpc("authority", "call_remote", "reliable")
func notify_vivosaur_back_to_sz(event_dict: Dictionary[String, Variant]) -> void:
	vivosaur_back_to_sz.emit(VivosaurBackToSzEvent.deserialize(event_dict))
