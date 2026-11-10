--!nocheck
-- Starter packs sold for Robux as consumable Developer Products.
-- Each pack is used up by one story run. Buying does NOT gate any ending:
-- tools/test_story.py verifies every ending is reachable with no packs.
--
-- SETUP: create a Developer Product per pack in the Creator Dashboard and put
-- its id in productId. While productId is 0, packs are free in Studio only
-- (for testing) and unavailable in the live game.
return {
	{
		id = "supplies",
		name = "Supply Pack",
		desc = "Start with water and food.",
		items = { "water", "food" },
		healthBonus = 0,
		productId = 0,
	},
	{
		id = "knife",
		name = "Survival Knife",
		desc = "Start with a knife. Opens extra options in some scenes.",
		items = { "knife" },
		healthBonus = 0,
		productId = 0,
	},
	{
		id = "vitality",
		name = "Extra HP",
		desc = "Start with 150 health instead of 100.",
		items = {},
		healthBonus = 50,
		productId = 0,
	},
	{
		id = "bundle",
		name = "Ultimate Survivor Bundle",
		desc = "Water, food, a knife, and 150 health.",
		items = { "water", "food", "knife" },
		healthBonus = 50,
		productId = 0,
	},
}
