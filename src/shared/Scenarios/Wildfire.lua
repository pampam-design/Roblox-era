--!nocheck
-- Scenario: wildfire reaches a lakeside campsite.
return {
	id = "wildfire",
	title = "Ember Night",
	place = "Campsite",
	disaster = "Wildfire",
	icon = "🔥",
	difficulty = "Hard",
	blurb = "Pine Lake Campground. Dry winds, an orange glow on the ridge, and one road out.",
	start = "start",
	deathNode = "death",
	lesson = "Wildfires move faster than you can run. Leave early, and choose a route away from fuel.",
	nodes = {
		start = {
			fx = "fire",
			text = "Day three of the camping trip. You, your friends Dani and Leo, and your older cousin Remy are playing cards when you notice the smell: smoke, thick and sharp. The sky to the west has turned a dirty orange.\n\nA ranger truck rolls through the campground with a loudspeaker: \"Evacuation order. Leave now by the south road.\"",
			choices = {
				{ text = "Leave right now. Grab the car keys and go.", next = "road", effects = { calm = -5 } },
				{ text = "Pack the tents and gear first, then go.", next = "packing", effects = { calm = -5 } },
				{ text = "Check the fire first. Climb the ridge for a view.", next = "ridge", effects = { calm = -5 } },
			},
		},

		packing = {
			fx = "fire",
			text = "Packing a tent takes longer than you think. Ten minutes later, the wind shifts and embers begin to fall around the campsite. Remy is shouting from the car. Dani is trying to roll up a sleeping bag with shaking hands.",
			choices = {
				{ text = "Drop everything and get in the car.", next = "road", effects = { calm = -10, health = -5 }, note = "You leave the tents burning behind you." },
				{ text = "Keep packing. It is expensive gear.", next = "trapped_camp", effects = { calm = -15 } },
			},
		},

		ridge = {
			fx = "fire",
			text = "From the ridge, you see it: a wall of fire racing across the hillside toward the campground and the road. It is moving far faster than you expected, and the wind is pushing it straight at you. You can hear it, like a freight train.\n\nYou run back to camp. Everyone is staring at you.",
			choices = {
				{ text = "Yell: \"Car, now! The road is the only way!\"", next = "road", effects = { calm = -15, health = -10 } },
				{ text = "Shout: \"Fire's too close, head for the lake!\"", next = "lake", effects = { calm = -10 } },
			},
		},

		road = {
			fx = "fire",
			text = "You pile into Remy's car. The south road is a single lane of gravel through the pines. Within a mile, you hit a line of brake lights. A truck has broken down ahead, and smoke is rolling across the road. Behind you, flames are leaping from tree to tree.",
			choices = {
				{ text = "Stay in the car, close the vents, and wait it out.", next = "car_wait", effects = { calm = -10 } },
				{ text = "Abandon the car and run back to the lake.", next = "lake", effects = { health = -15, calm = -15 } },
				{ text = "Help the stalled driver push the truck off the road.", next = "push_truck", effects = { calm = -5 } },
			},
		},

		push_truck = {
			fx = "fire",
			text = "You and Leo run to the truck. Together with three other people, you shove it into the ditch, bumper first. The line of cars lurches forward. Smoke stings your eyes and the heat is intense, but the road is clear.",
			choices = {
				{ text = "Jump back in and race out with the convoy.", next = "convoy", effects = { health = -10, set = { "cleared_road" } } },
			},
		},

		convoy = {
			fx = "fire",
			text = "The convoy crawls through the smoke, tail lights in front of you glowing like embers. The air inside the car is hot. Then the trees thin out and you reach an open meadow, and a fire crew with water trucks waving cars through.",
			ending = { kind = "hero", title = "Cleared the Road" },
			lesson = "Evacuating early by the designated route, and helping clear the way, can save a whole convoy. Always follow official evacuation orders.",
		},

		car_wait = {
			fx = "fire",
			text = "Heat shimmers on the windscreen. You can hear the fire crackling closer. Someone shouts that you have to get out of the cars. Then the front-most car's tyre bursts from the heat.",
			choices = {
				{ text = "Run for the lake on the far side of the field.", next = "lake", effects = { health = -20, calm = -10 } },
				{ text = "Stay put. The car is a metal box.", next = "death", effects = { health = -100 }, note = "The cars cannot withstand the fire front." },
			},
		},

		trapped_camp = {
			fx = "fire",
			text = "Ten more minutes and the wind shifts for the worst. A fireball roars into the campground. You flee on foot with nothing, and the car is blocked by burning trees.\n\nYou see the lake, a hundred metres away, glittering orange. It is your last chance.",
			choices = {
				{ text = "Sprint for the lake.", next = "lake", effects = { health = -35, calm = -20 } },
			},
		},

		lake = {
			fx = "fire",
			text = "The lake is cool and black and calm. You wade in up to your neck. Behind you the campsite is a wall of flame. Heat scorches your back, and the air is thick with smoke. A bandana and a water bottle would be good right now.",
			choices = {
				{ text = "Soak your shirt with your water bottle first, then wade in.", next = "lake_night", requires = { items = { "water" } }, hiddenIfLocked = true, effects = { give = { "wet cloth" }, calm = 10, health = 10 } },
				{ text = "Wet your shirt and breathe through it.", next = "lake_night", effects = { give = { "wet cloth" }, calm = 5 } },
				{ text = "Duck under whenever the heat surges.", next = "lake_night", effects = { calm = -5, health = -5 } },
				{ text = "Swim across to the far shore, away from the fire.", next = "far_shore", effects = { calm = -10 } },
			},
		},

		far_shore = {
			fx = "fire",
			text = "The swim is long, and the cold bites hard. On the far shore, a pebble beach with no trees nearby, a family has already gathered, huddled in towels. A little boy is crying, and a woman waves at you.",
			choices = {
				{ text = "Help the family into the water and keep them calm.", next = "lake_night", effects = { calm = -5, health = -10, set = { "helped_family" } } },
				{ text = "Collapse on the sand and rest.", next = "lake_night", effects = { calm = 10 } },
			},
		},

		lake_night = {
			fx = "fire",
			text = "The hours pass. The fire front sweeps by, leaving black skeletons of trees. Burning branches fall into the lake with a hiss. The air stays thick with smoke, but the water protects you.\n\nAt first light you hear a chopper.",
			choices = {
				{ text = "Wave your wet shirt, spread wide on the sand.", next = "helicopter", requires = { items = { "wet cloth" } } },
				{ text = "Wave your arms and shout.", next = "helicopter", chance = { p = 0.7, win = "helicopter", lose = "late_rescue" } },
			},
		},

		helicopter = {
			fx = "calm",
			text = "The helicopter circles, then drops a line. Crews haul out each survivor on the beach and fly you to a safe zone. At the evacuation centre, you find Dani, Leo and Remy, all of them safe. All the gear is gone, but you do not care.",
			ending = { kind = "survived", title = "Lifted from the Lake" },
			lesson = "Bodies of water and bare ground can protect you when the fire front passes. Stay low, cover your face, and signal clearly for rescue.",
		},

		late_rescue = {
			fx = "calm",
			text = "The chopper does not see you. You wait through the smoke-filled day, shivering in the water, until a ground crew finds you at dusk. You will have lung problems for months, but you are alive.",
			ending = { kind = "survived", title = "Long Wait" },
			lesson = "A bright, visible signal helps rescuers find you quickly. Do not rely on being noticed.",
		},

		death = {
			fx = "dark",
			text = "The fire moved faster than anyone could believe. Smoke, heat and panic closed every door. The park will rebuild, but you will not forget this night.",
			ending = { kind = "died", title = "Lost to the Fire" },
			lesson = "Most wildfire deaths happen when people delay leaving. Leave as soon as an evacuation order is issued.",
		},
	},
}
