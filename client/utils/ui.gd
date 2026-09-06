class_name UIUtils

static var SkillScene: Resource = preload("res://client/modules/ui/skill_button/skill_button.tscn")

static func load_medal_texture(vivosaur_id: String) -> Resource:
	return load("res://client/assets/vivosaurs/%s/medal.png" % vivosaur_id)

static func update_skills_shown(skills_container: VBoxContainer, skills: Array[Skill], _on_skill_clicked: Callable, disabled: bool = true, can_use_skill: bool = true) -> void:
	clear_skills(skills_container)

	if not can_use_skill:
		return

	for skill: Skill in skills:
		var skill_node: SkillButton = SkillScene.instantiate()
		skill_node.initialize(skill, _on_skill_clicked, disabled)
		skills_container.add_child(skill_node)
		
static func clear_skills(skills_container: VBoxContainer) -> void:
	for old_skill: Node in skills_container.get_children():
		old_skill.queue_free()
