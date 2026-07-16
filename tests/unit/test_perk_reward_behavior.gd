extends GutTest


func test_looter_adds_a_third_reward_choice() -> void:
	var controller := RunItemController.new()
	var builder := PerkModifierBuilder.new()
	var effect := PerkModifierEffect.new()
	effect.domain = PerkModifierEffect.Domain.REWARD
	effect.modifier_key = "choice_count_add"
	effect.value = 1.0
	effect.apply(builder)
	controller.set_perk_modifiers(builder.build())
	var chest := load("res://config/items/item_chest.tres") as ItemChestDefinition

	assert_eq(controller._reward_choice_count(chest), 3)
