--!nocheck
-- Scenario: zombie outbreak in an apartment block.
return {
	id = "zombies",
	title = "Dead Hours",
	place = "Apartment Block",
	disaster = "Zombie Outbreak",
	icon = "🧟",
	difficulty = "Hard",
	blurb = "Day one of the outbreak. Third floor, one locked door, and something is pounding on it.",
	start = "start",
	deathNode = "death",
	lesson = "In any crisis: stay quiet, secure your space, gather food and water, and move only with a plan.",
	nodes = {
		start = {
			fx = "dark",
			text = "You wake to screaming. Not from the TV, from the corridor. Through the wall you hear glass breaking, a door slamming, and a wet, wrong sound you cannot place. Your phone shows forty missed alerts: ATTACKS REPORTED. STAY INDOORS. DO NOT APPROACH THE INFECTED.\n\nSomeone is thumping on your front door, slowly, over and over.",
			choices = {
				{ text = "Look through the peephole.", next = "peep", effects = { calm = -5 } },
				{ text = "Shove the sofa against the door.", next = "barricade", effects = { calm = 5 } },
				{ text = "Grab your bag and run for the stairwell.", next = "stairs", effects = { calm = -15 } },
			},
		},

		peep = {
			fx = "dark",
			text = "It is Mrs. Alvarez from 3C, the neighbour who feeds the cat. Her eyes are grey and her mouth is dark with blood. She does not blink. She keeps hitting the door with an open hand.",
			choices = {
				{ text = "Open it. Maybe she just needs help.", next = "barricade", chance = { p = 0.15, win = "barricade", lose = "barricade", loseEffects = { health = -45, calm = -20 }, winNote = "She stumbles past you into the stairwell. You slam the door.", loseNote = "She lunges and bites your forearm before you can shut the door." } },
				{ text = "Stay silent and back away.", next = "barricade", effects = { calm = -5 } },
				{ text = "Call your mum on the phone.", next = "phone" },
			},
		},

		phone = {
			fx = "dark",
			text = "Your mum picks up on the first ring. \"Listen. The radio says boats leave from Harbor Pier at dawn, and helicopters are taking people off the roof of Hartley Tower. I am at your aunt's. Do NOT come here. Get to one of them. Please.\"\n\nThe line cuts out.",
			choices = {
				{ text = "Write both places down and push the sofa against the door.", next = "barricade", effects = { calm = 5 } },
			},
		},

		barricade = {
			fx = "dark",
			text = "The sofa, the table and the bookcase make a decent wall. Whatever is outside keeps pounding, then slowly loses interest and shuffles off. It is quiet. Too quiet.\n\nYour stomach growls. You have maybe three days of food in the flat. Outside the window, smoke rises over the city.",
			choices = {
				{ text = "Search the kitchen for anything useful.", next = "plan", effects = { give = { "pan" }, calm = 5 }, note = "You find a heavy cast-iron pan." },
				{ text = "Check the fire escape outside the bedroom window.", next = "fire_escape" },
				{ text = "Raid the fridge and cupboards, then hunker down and wait for rescue.", next = "siege", effects = { give = { "food" }, calm = -5 } },
				{ text = "Hunker down with what you have and wait for rescue.", next = "siege", effects = { calm = -5 } },
			},
		},

		siege = {
			fx = "dark",
			text = "Day three. The pounding has stopped, but now it is the silence that hurts. Your food is nearly gone and the tap runs brown. Somewhere far off, an engine rumbles, a military convoy, you think. It is passing by your street.",
			choices = {
				{ text = "Ration your food and wait one more day.", next = "safe_ending", requires = { items = { "food" } }, hiddenIfLocked = true, effects = { calm = 10 } },
				{ text = "Go out now and flag the convoy down.", next = "stairs", effects = { health = -10, calm = -10 } },
				{ text = "Keep waiting. They will come.", next = "death", effects = { health = -100 }, note = "No one comes in time." },
			},
		},

		safe_ending = {
			fx = "calm",
			text = "You sip the last water and wait. On the fourth day, soldiers go door to door with loudhailers, clearing each building. They knock on your barricade and call out: \"Anyone alive in there? We are evacuating survivors.\"\n\nYou answer, your voice cracking.",
			ending = { kind = "survived", title = "The Long Siege" },
			lesson = "Sheltering in place only works if you have supplies. Food, water and a plan make waiting survivable.",
		},

		plan = {
			fx = "dark",
			text = "While searching, your portable radio crackles. \"...Harbor Pier. Boats at dawn. Helicopters from Hartley Tower roof, last flight at noon. All other routes are unsafe...\" You have to pick one.",
			choices = {
				{ text = "Head for Harbor Pier.", next = "stairs", effects = { set = { "goal_harbor" } } },
				{ text = "Head for Hartley Tower.", next = "stairs", effects = { set = { "goal_tower" } } },
			},
		},

		stairs = {
			fx = "dark",
			text = "The stairwell is dark. A body in a hoodie lies slumped on the landing. It lifts its head. Further down, two more shapes shuffle toward you, drawn by the noise.\n\nThere is no other way down.",
			choices = {
				{ text = "Fight through with your knife.", next = "street", requires = { items = { "knife" } }, hiddenIfLocked = true, effects = { health = -10, calm = 5 }, note = "You are fast and decisive, and the stairs are clear." },
				{ text = "Swing the pan at the first one.", next = "street", requires = { items = { "pan" } }, hiddenIfLocked = true, chance = { p = 0.5, win = "street", lose = "street", loseEffects = { health = -35, calm = -15 }, winNote = "The pan connects with a clang and you push through.", loseNote = "One of them grabs your arm and tears your sleeve before you break free." } },
				{ text = "Sneak past them, one step at a time.", next = "street", chance = { p = 0.4, win = "street", lose = "street", loseEffects = { health = -30, calm = -20 }, winNote = "They shuffle right past without noticing you.", loseNote = "A step creaks. You sprint down with them on your heels." } },
			},
		},

		fire_escape = {
			fx = "dark",
			text = "The iron fire escape clangs in the wind. Below, an alley full of dumpsters and wandering shapes. Above, a ladder leads to the roof of the building. Someone up there is waving a torch.",
			choices = {
				{ text = "Climb down into the alley.", next = "alley", effects = { health = -5, calm = -10 }, chance = { p = 0.6, win = "alley", lose = "alley", loseEffects = { health = -25 }, loseNote = "A rung gives way and you tumble the last few metres." } },
				{ text = "Climb up to the roof.", next = "roof", effects = { calm = 5 } },
			},
		},

		street = {
			fx = "dark",
			text = "The lobby doors burst open onto an empty street. Cars are abandoned with their doors hanging open. A figure drags itself across the road. A car sits with its keys still in the ignition, engine ticking.",
			choices = {
				{ text = "Try the car. It is the fastest way across the city.", next = "alley", chance = { p = 0.5, win = "alley", lose = "alley", loseEffects = { health = -20, calm = -15 }, winNote = "The engine catches and you roar away.", loseNote = "It stalls. You bolt on foot as the shapes close in." } },
				{ text = "Slip into the back alleys on foot.", next = "alley", effects = { calm = -5 } },
			},
		},

		alley = {
			fx = "dark",
			text = "The alley opens onto the main road. Straight ahead the city is a maze of burning cars and wandering silhouettes. You can see your goal in the distance. It is a long way.",
			choices = {
				{ text = "Eat your food, then sprint the whole way to the Pier.", next = "pier", requires = { items = { "food" }, notFlags = { "goal_tower" } }, hiddenIfLocked = true, effects = { calm = 5 } },
				{ text = "Dash between wrecked cars toward the Pier.", next = "pier", chance = { p = 0.55, win = "pier", lose = "death", loseEffects = { health = -70 } }, requires = { notFlags = { "goal_tower" } }, hiddenIfLocked = true },
				{ text = "Eat your food, then sprint the whole way to Hartley Tower.", next = "tower", requires = { items = { "food" }, flags = { "goal_tower" } }, hiddenIfLocked = true, effects = { calm = 5 } },
				{ text = "Dash between wrecked cars toward Hartley Tower.", next = "tower", chance = { p = 0.55, win = "tower", lose = "death", loseEffects = { health = -70 } }, requires = { flags = { "goal_tower" } }, hiddenIfLocked = true },
			},
		},

		pier = {
			fx = "calm",
			text = "Harbor Pier is a wall of floodlights and rifles. Soldiers hold back the infected at a barricade while boats take on passengers one by one. A family with two small children is stuck at the back of the line, pushed aside by the crowd.",
			choices = {
				{ text = "Help the family reach the front of the line.", next = "hero_pier", effects = { health = -10, calm = -5 } },
				{ text = "Get on the boat. You earned your place.", next = "boat_ending" },
			},
		},

		hero_pier = {
			fx = "calm",
			text = "You shout to the soldier at the gangway and wave the family forward. For a moment it looks like the barricade will break. Then the children are lifted aboard, and you follow. As the boat pulls away, the little girl hands you her stuffed rabbit.",
			ending = { kind = "hero", title = "The Last Boat" },
			lesson = "Teamwork and compassion keep communities alive after a collapse. Survivors who cooperate do better than those who go alone.",
		},

		boat_ending = {
			fx = "calm",
			text = "You squeeze onto the deck as the engines roar. Behind you, the city burns. A medic hands you a blanket and a bottle of water, and for the first time in two days you let yourself breathe.",
			ending = { kind = "survived", title = "Off the Pier" },
			lesson = "Evacuating early to a planned location, with supplies, is the best way out of any large-scale emergency.",
		},

		tower = {
			fx = "dark",
			text = "Hartley Tower's lobby is dark and the lifts are dead. The sign on the wall reads ROOF ACCESS - FLOOR 22. You take the emergency stairs, floor by floor, listening for movement above and below. Your legs burn.",
			choices = {
				{ text = "Keep climbing, one landing at a time.", next = "roof", effects = { calm = -10, health = -5 } },
			},
		},

		roof = {
			fx = "calm",
			text = "On the roof, a handful of survivors huddle around a flare. A man is lying injured by the air vent and his teenage son Theo is holding his hand. A distant thudding grows louder. A helicopter, circling in the dark.",
			choices = {
				{ text = "Signal the helicopter with a bright flare.", next = "heli", chance = { p = 0.65, win = "heli", lose = "heli", loseEffects = { calm = -15 }, winNote = "The pilot sees you at once.", loseNote = "It circles twice before it notices you." } },
				{ text = "Share your food with Theo and his dad first.", next = "heli", requires = { items = { "food" } }, hiddenIfLocked = true, effects = { calm = 10, take = { "food" }, set = { "helped_theo" } }, note = "Theo manages a smile." },
			},
		},

		heli = {
			fx = "calm",
			text = "The helicopter drops a rope ladder. There is only room for a few. Theo's dad cannot climb alone.",
			choices = {
				{ text = "Carry Theo's dad up the ladder.", next = "hero_roof", effects = { health = -15, calm = -10 } },
				{ text = "Climb up yourself while you can.", next = "heli_ending" },
			},
		},

		hero_roof = {
			fx = "calm",
			text = "You strap Theo's dad to your back and climb, step by step, with the rotor wash tearing at your clothes. When you pull him inside, Theo hugs you so hard you can barely breathe. \"I do not know your name,\" he says. \"But I will never forget it.\"",
			ending = { kind = "hero", title = "Rooftop Rescue" },
			lesson = "Putting others first is not just noble, it builds the trust and bonds that get people through disasters.",
		},

		heli_ending = {
			fx = "calm",
			text = "You are hauled up into the helicopter and strapped in. The roof falls away beneath you and the city stretches out like a map of fire. You are alive. You try not to look back.",
			ending = { kind = "survived", title = "Airlifted Out" },
			lesson = "Make yourself visible and wait for official rescue. Never rely only on being noticed.",
		},

		death = {
			fx = "dark",
			text = "The city falls silent. In the end it was the crowd, the dark, and the bite you could not stop. Maybe someone on the next block will hold out a little longer.",
			ending = { kind = "died", title = "Overrun" },
			lesson = "Panic and rushing are the biggest killers in any crisis. Stay calm, move deliberately, and keep supplies ready.",
		},
	},
}
