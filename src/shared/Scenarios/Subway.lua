--!nocheck
-- Scenario: flash flood reaches an underground station.
return {
	id = "subway",
	title = "Rising Water",
	place = "Subway",
	disaster = "Flash Flood",
	icon = "🚇",
	difficulty = "Medium",
	blurb = "Marlow Street Station. A storm has been raining for hours, and the tunnel is filling up.",
	start = "start",
	deathNode = "death",
	lesson = "Floodwater is faster and stronger than it looks. Move up and away, never through it.",
	nodes = {
		start = {
			fx = "flood",
			text = "Evening rush hour. You are on the Line 4 platform at Marlow Street, soaked from the storm outside. The board flickers: SERVICE SUSPENDED.\n\nThen you notice the thin sheet of water spreading across the platform floor, and a roar from the staircase you came down. Brown water is pouring down the steps.",
			choices = {
				{ text = "Run up the stairs, against the water.", next = "stairs", effects = { calm = -10 } },
				{ text = "Press the emergency intercom and call for help.", next = "intercom", effects = { calm = 5 }, note = "A tired voice answers: \"Station control.\"" },
				{ text = "Walk toward the far end of the platform.", next = "far_end" },
				{ text = "Climb onto the stalled train for a better view.", next = "train_roof", effects = { calm = -5, give = { "phone light" } } },
			},
		},

		stairs = {
			fx = "flood",
			text = "Halfway up, the water hits your knees and shoves you backward. A man grabs the rail beside you and shouts that the street is flooded too. It is knee-deep and brown, and it is full of debris.\n\nYou slip. The current drags your legs out from under you.",
			choices = {
				{ text = "Grab the handrail with both hands and hang on.", next = "stairs_hold", hold = 5, chance = { p = 0.6, win = "stairs_hold", lose = "washed_back", loseEffects = { health = -30 } }, note = "Your grip is slipping..." },
				{ text = "Let go and swim for the platform.", next = "washed_back", effects = { health = -30 } },
			},
		},

		stairs_hold = {
			fx = "flood",
			text = "You hold on. The man from the stairs hauls you up by your jacket and together you cling to the rail until the surge passes. But the street exit is under a meter of water. You cannot go out that way.",
			choices = {
				{ text = "Go back down and use the intercom.", next = "intercom", effects = { health = -10, calm = -10 } },
				{ text = "Head for the far end of the platform.", next = "far_end", effects = { health = -10 } },
			},
		},

		washed_back = {
			fx = "flood",
			text = "The water carries you back down the stairs and dumps you on the platform. You cough and gasp. Water is now ankle-deep and rising fast. A stranger hauls you to your feet. \"The ladder to the maintenance shaft!\" she shouts, pointing down the platform.",
			choices = {
				{ text = "Follow her to the far end.", next = "far_end", effects = { calm = -5 } },
			},
		},

		intercom = {
			fx = "flood",
			text = "\"Station control. Marlow Street is flooding. We are evacuating via Exit C at the far end. Do NOT use the tracks. The rails are live until we cut power.\"\n\nThe voice cuts out. Water laps at the platform edge. Behind you, an elderly man with a cane is struggling to stay upright against the flow.",
			choices = {
				{ text = "Help the elderly man walk toward Exit C.", next = "far_end", effects = { calm = 5, set = { "helped_stranger" } }, note = "He leans on your arm. \"Thank you, kid.\"" },
				{ text = "Head to Exit C alone. You cannot carry everyone.", next = "far_end", effects = { calm = -10 } },
				{ text = "Jump down to the tracks and run through the tunnel.", next = "tunnel", effects = { calm = -10 } },
			},
		},

		tunnel = {
			fx = "dark",
			text = "You drop onto the tracks. It is pitch black and the water is already at your shins. You feel the metal of the rail brush your foot. Is power still on?\n\nA flicker of sparks lights the tunnel. The third rail is half-submerged ahead of you.",
			choices = {
				{ text = "Climb back to the platform. Do not touch the rails.", next = "far_end", effects = { health = -15, calm = -15 }, note = "You scramble up, heart pounding." },
				{ text = "Wade past the rail, hugging the wall.", next = "death", effects = { health = -100 }, note = "The water carries the current." },
			},
		},

		train_roof = {
			fx = "flood",
			text = "You pull yourself up onto the roof of the train. From here you can see the whole platform: the water has swallowed the benches and is already above the first rung of the maintenance ladder at the far end. Others on the platform are screaming for help.\n\nThe water keeps rising. The roof of the train will not stay above it for long.",
			choices = {
				{ text = "Jump back down and run for the ladder at the far end.", next = "far_end", effects = { calm = -5 } },
				{ text = "Stay on the roof and wait for rescue.", next = "wait_roof" },
			},
		},

		wait_roof = {
			fx = "flood",
			text = "Twenty minutes pass. The water climbs until it laps at the underside of the train carriage. The roof begins to shake as the current rocks the train. Your teeth are chattering.",
			choices = {
				{ text = "Shout for help and wave your phone light.", next = "boat_rescue", requires = { items = { "phone light" } } },
				{ text = "Jump down and swim for the ladder.", next = "far_end", effects = { health = -25, calm = -10 }, note = "The water is freezing and fast." },
			},
		},

		boat_rescue = {
			fx = "calm",
			text = "A rescue boat finds you at last. You wait on the roof as the rescuers pull people up one by one. When the boat reaches the ladder, you climb in. It is only when you are out in the open air that you realise how dangerous that tunnel was.",
			ending = { kind = "survived", title = "Rescued by Boat" },
			lesson = "If you cannot get out, go to the highest dry point and signal clearly for help. Do not try to move through fast-moving water.",
		},

		far_end = {
			fx = "flood",
			text = "At the far end of the platform, a steel door marked EXIT C hangs open. Beyond it a metal ladder climbs into a dark maintenance shaft. Water is up to your thighs and surging.\n\nA small group is already there. A girl with a toddler cannot reach the first rung.",
			choices = {
				{ text = "Lift the toddler onto the ladder first.", next = "shaft", effects = { calm = 5, health = -10, set = { "helped_child" } }, note = "The mother sobs thanks as you boost her kid up." },
				{ text = "Push to the front. You need to get out now.", next = "shaft", effects = { calm = -15 }, note = "Others shout at you, but you are up the ladder." },
				{ text = "Cut a strap from a bag with your knife for a rope.", next = "shaft", requires = { items = { "knife" } }, hiddenIfLocked = true, effects = { give = { "belt" }, calm = 5 } },
				{ text = "Look for something to use as a rope.", next = "shaft", effects = { give = { "belt" } }, note = "You pull a strap from a bag." },
			},
		},

		shaft = {
			fx = "dark",
			text = "The ladder climbs for what feels like forever. Halfway up, the one above you freezes. The rung is rusted through and swinging loose. The water is rising right behind you.",
			choices = {
				{ text = "Swing across to the next ladder and pull yourself up.", next = "hatch", hold = 3, chance = { p = 0.55, win = "hatch", lose = "hatch", loseEffects = { health = -25 }, winNote = "You catch the rung and haul yourself up.", loseNote = "You slip and crash into the rungs, scraping both arms." } },
				{ text = "Use the belt to bind the broken rung.", next = "hatch", requires = { items = { "belt" } }, note = "It holds, barely." },
				{ text = "Keep climbing on the damaged ladder.", next = "death", effects = { health = -100 }, note = "The rung gives way." },
			},
		},

		hatch = {
			fx = "dark",
			text = "At the top of the shaft is a heavy steel hatch, held shut by the pressure of the rain on the other side. Below you, water is rising. The people on the ladder are shoving against you.",
			choices = {
				{ text = "Push the hatch with your shoulder and shout for the others to help.", next = "street", chance = { p = 0.6, win = "street", lose = "street", loseEffects = { health = -15 }, boostItem = "belt", boost = 0.1 } },
			},
		},

		street = {
			fx = "calm",
			text = "The hatch bursts open and cold air and rain hit your face. You climb out onto a raised sidewalk. The street below is a river. Firefighters in orange suits are wading toward you with ropes.",
			choices = {
				{ text = "Help pull up the next person from the shaft.", next = "hero_ending", requires = { flags = { "helped_child" } }, hiddenIfLocked = true },
				{ text = "Look around for who is still down there.", next = "hero_ending", requires = { flags = { "helped_stranger" } }, hiddenIfLocked = true },
				{ text = "Collapse on the sidewalk and let the firefighters take over.", next = "street_ending" },
			},
		},

		hero_ending = {
			fx = "calm",
			text = "You lean back into the shaft and haul up the next person, then the next. By the time the firefighters reach you, nine people have climbed out of Exit C because you refused to leave them behind.\n\nThe news calls it a miracle. You call it a team effort.",
			ending = { kind = "hero", title = "Nine Out of Exit C" },
			lesson = "When it is safe, helping others during an evacuation saves more lives. Just never put yourself in the flood's path to do it.",
		},

		street_ending = {
			fx = "calm",
			text = "A firefighter drapes a blanket around your shoulders. You sit on the curb, soaked and shaking, watching the water pour into the station you left behind. You made it, and you will take the bus from now on.",
			ending = { kind = "survived", title = "Above the Waterline" },
			lesson = "Even six inches of moving water can knock you off your feet. Two feet can float a car. Turn around, do not drown.",
		},

		death = {
			fx = "dark",
			text = "The water, the dark, and the current were stronger than you. The underground station fills silently. It is one of the worst nights the city has ever had.",
			ending = { kind = "died", title = "Swept Under" },
			lesson = "Never enter floodwater or train tunnels. Floodwater hides debris and live electricity, and cannot be outswum.",
		},
	},
}
