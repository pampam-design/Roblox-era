--!nocheck
-- Scenario: strong coastal earthquake followed by a tsunami.
return {
	id = "tsunami",
	title = "The Sea Pulls Back",
	place = "Beach Resort",
	disaster = "Tsunami",
	icon = "🌊",
	difficulty = "Medium",
	blurb = "Sunny morning on the beach. The ground shakes for a full minute, and then the ocean disappears.",
	start = "start",
	deathNode = "death",
	lesson = "Strong shaking near the coast, or the sea suddenly draining away, is the warning. Do not wait for a siren.",
	nodes = {
		start = {
			fx = "calm",
			text = "You are on a sunbed outside the Palm Bay Resort with your little sister Mia, sipping a fruit drink, when the ground begins to roll. A glass shatters. Palm trees sway. The shaking lasts almost a full minute.\n\nWhen it stops, people laugh nervously and start filming. Mia grins: \"That was cool!\"",
			choices = {
				{ text = "Grab Mia and head inland, uphill. Now.", next = "inland", effects = { calm = -5, set = { "has_mia" } } },
				{ text = "Ask a lifeguard what is going on.", next = "lifeguard" },
				{ text = "Stay and wait for an official announcement.", next = "wait" },
			},
		},

		wait = {
			fx = "calm",
			text = "Five minutes pass. No sirens. Phones have no signal. A boy near you points at the water: \"Look! The sea is going out!\" Fish are flopping on the exposed sand, and the water has retreated hundreds of metres.\n\nPeople are walking out onto the wet seabed to take photos.",
			choices = {
				{ text = "Run. This is the warning sign.", next = "inland", effects = { calm = -15, set = { "has_mia" } }, note = "You grab Mia's hand and sprint." },
				{ text = "Walk out onto the seabed to see for yourself.", next = "seabed", effects = { calm = -5 } },
			},
		},

		lifeguard = {
			fx = "calm",
			text = "The lifeguard is already on the radio. \"Strong quake. Possible tsunami. Everyone to high ground, up the hill past the road or to the upper floors of the hotel. Go now. Do not wait for the siren.\"",
			choices = {
				{ text = "Grab Mia and run up the hill road.", next = "inland", effects = { calm = -5, set = { "has_mia" } } },
				{ text = "Take Mia into the hotel and go up the stairs.", next = "hotel", effects = { calm = -5, set = { "has_mia" } } },
				{ text = "Run back to your room to grab your passport and phone.", next = "room", effects = { calm = -10 } },
			},
		},

		room = {
			fx = "calm",
			text = "You race to your ground-floor room. The door is jammed from the quake and you waste minutes forcing it open. When you finally get out with your bag, the beach is deserted except for one thing: far out where the sea used to be, a long white line is rising on the horizon.",
			choices = {
				{ text = "Drop the bag and run for the hotel stairs.", next = "hotel", effects = { calm = -20, health = -10 } },
				{ text = "Run uphill. The road is closer to you than the hotel.", next = "inland", effects = { calm = -20, health = -10 } },
			},
		},

		seabed = {
			fx = "wave",
			text = "The sand is hard and wet and littered with stranded fish. You are fifty metres out when you hear screaming behind you. You turn around. A wall of water is racing across the bay, filled with boats, trees, and the remains of the pier.",
			choices = {
				{ text = "Run for the hotel as fast as you can.", next = "death", chance = { p = 0.1, win = "hotel", lose = "death" }, note = "It is too far..." },
			},
		},

		inland = {
			fx = "wave",
			text = "The coastal road is already jammed with cars. Horns, shouting, a motorbike on the pavement. Mia is panting but keeps up. The hill is a few hundred metres ahead. You can hear a deep roar from the beach, like a river.",
			choices = {
				{ text = "Leave the road and take the steep footpath uphill.", next = "footpath", effects = { health = -10, calm = -5 } },
				{ text = "Hop into a stranger's car crawling in traffic.", next = "car_trap", effects = { calm = -5 } },
				{ text = "Carry Mia on your back and sprint for the hotel instead.", next = "hotel", requires = { flags = { "has_mia" } }, effects = { health = -10, calm = -10 } },
			},
		},

		car_trap = {
			fx = "wave",
			text = "The car does not move. Traffic is solid. Behind you, the sea is a grey wall rushing through the streets. The driver is frozen.",
			choices = {
				{ text = "Jump out, grab Mia, and scramble up the embankment.", next = "footpath", chance = { p = 0.5, win = "footpath", lose = "death", loseEffects = { health = -60 } }, effects = { calm = -15 } },
			},
		},

		footpath = {
			fx = "wave",
			text = "The path is muddy and steep. Mia's sandals slide. You boost her up by the arms while a local man reaches down from above. The roar rises behind you. Water surges up the lower slope, swallowing the road and the car park.",
			choices = {
				{ text = "Keep climbing. Higher, higher.", next = "hilltop", hold = 3, effects = { health = -5 } },
				{ text = "Stop and look back to see how bad it is.", next = "hilltop_late", effects = { calm = -10 } },
			},
		},

		hilltop_late = {
			fx = "wave",
			text = "You look back and see the resort vanish into brown water. The hotel's ground floor is gone. A second wave rolls in, higher than the first, and its spray soaks you. The local man drags you up the slope by the shoulder.",
			choices = {
				{ text = "Scramble up the slope.", next = "hilltop", effects = { health = -15 } },
			},
		},

		hotel = {
			fx = "wave",
			text = "The Palm Bay is a concrete building, eight storeys tall. The stairwell is packed. On the third floor, an elderly woman has sat down on the landing, unable to climb further.",
			choices = {
				{ text = "Help her up the stairs, one step at a time.", next = "roof", effects = { health = -10, calm = -5, set = { "helped_woman" } } },
				{ text = "Keep climbing. The wave is coming.", next = "roof", effects = { calm = -10 } },
				{ text = "Eat your snack bar for energy and carry her up.", next = "roof", requires = { items = { "food" } }, hiddenIfLocked = true, effects = { calm = 5, set = { "helped_woman" } } },
				{ text = "Stop at the third floor. That is high enough.", next = "death", effects = { health = -100 }, note = "The wave tops three storeys." },
			},
		},

		roof = {
			fx = "wave",
			text = "On the roof of the resort, dozens of people are huddled together. Below, the wave crashes into the lower floors with a thunderous boom and the whole building shudders. Water surges through the lobby. The sea keeps rising for what feels like forever, then begins to drain.\n\nYou hold Mia tight and do not look down.",
			choices = {
				{ text = "Hold Mia tight and wait for rescue. More waves could come.", next = "roof_ending" },
			},
		},

		roof_ending = {
			fx = "calm",
			text = "Waves come in for hours. Rescue helicopters pick up survivors from the roof the next morning. The elderly woman, if you helped her, holds your hand tight on the flight out. Mia is quiet. Then she says: \"We should have listened to the ground.\"\n\nShe is right.",
			ending = { kind = "survived", title = "Vertical Evacuation" },
			lesson = "If you cannot reach high ground, go to the upper floors of a strong concrete building (at least 4 storeys up). Tsunamis come in several waves, so stay put until officials say it is safe.",
		},

		hilltop = {
			fx = "calm",
			text = "You reach the top of the hill, where dozens of survivors stand looking down at the bay. The resort is gone. The sea is brown and full of wreckage. Mia clings to your side.\n\nA man near you is searching the crowd and shouting a name over and over.",
			choices = {
				{ text = "Help organise the group and share your phone's signal.", next = "hero_ending", requires = { flags = { "has_mia" } }, hiddenIfLocked = true },
				{ text = "Sit with Mia and wait for news.", next = "hilltop_ending" },
			},
		},

		hero_ending = {
			fx = "calm",
			text = "You and a few others set up a list of names on the back of a map. Phones come back on one by one. By evening, you have reconnected eleven families. Mia hands out water bottles to the children.\n\nThe local news interviews you at the evacuation centre. \"I just ran,\" you say. \"And I made sure she ran too.\"",
			ending = { kind = "hero", title = "Higher Ground, Together" },
			lesson = "Acting on natural warning signs, rather than waiting for official alerts, gives you and the people around you the best chance.",
		},

		hilltop_ending = {
			fx = "calm",
			text = "You sit with Mia, wrapped in a stranger's blanket, until the sun goes down. Rescue crews arrive. You are alive, and so is she. The beach is gone, but you have each other.",
			ending = { kind = "survived", title = "Above the Wave" },
			lesson = "Move inland and uphill as soon as you feel a strong earthquake. A tsunami can reach shore in minutes.",
		},

		death = {
			fx = "dark",
			text = "The wave came faster than anyone could believe. By the time you understood the signs, it was too late. Palm Bay will be remembered as a place where the warning came from the earth itself.",
			ending = { kind = "died", title = "Swept Away" },
			lesson = "A receding sea is a tsunami warning. Never go to look at it. Run uphill.",
		},
	},
}
