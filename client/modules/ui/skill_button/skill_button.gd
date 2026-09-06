extends Panel
class_name SkillButton

func initialize(skill: Skill, _on_skill_clicked: Callable, is_disabled: bool) -> void:
	var current_fp: int = Battling.formations[Networking.player_info.player_id].fp if Networking.player_info.player_id else 500

	var disabled_saturation: float = 0.3 if is_disabled or skill.fp_cost > current_fp else 0.0
	var style_box: StyleBox = theme.get_stylebox('panel', 'Panel')
	var style_box_flat: StyleBoxFlat = style_box.duplicate()
	if skill.type == Skill.Type.DAMAGE or skill.type == Skill.Type.NEUTRAL:
		style_box_flat.bg_color = Color.from_hsv(0.058, 0.76, 0.9 - disabled_saturation)
	elif skill.type == Skill.Type.HEAL or skill.type == Skill.Type.ENHANCEMENT:
		style_box_flat.bg_color = Color.from_hsv(0.325, 0.62, 0.71 - disabled_saturation)
	elif skill.type == Skill.Type.TEAM_SKILL:
		style_box_flat.bg_color = Color.from_hsv(1, 0.76, 0.8 - disabled_saturation)
	else:
		style_box_flat.bg_color = Color.from_hsv(0.542, 0.94, 0.88 - disabled_saturation)
	
	add_theme_stylebox_override('panel', style_box_flat)
	
	$HBoxContainer/VBoxContainer/Name.text = skill.name
	$HBoxContainer/VBoxContainer/HBoxContainer/Damage.text = "Dmg: %d" % skill.damage
	$HBoxContainer/VBoxContainer/HBoxContainer/FpCost.text = "%d FP" % skill.fp_cost
	$HBoxContainer/VBoxContainer/Counterable.text = "Counterable: yes" if skill.counterable else "Counterable: no"
	$HBoxContainer/Description.text = skill.description

	if not is_disabled and not skill.fp_cost > current_fp:
		gui_input.connect(_on_skill_clicked.bind(skill))
