--!nocheck
-- Scenario: missile alert, based on public civil-defence guidance
-- (get inside, stay inside, stay tuned).
return {
	id = "nuclear",
	title = "Flash Warning",
	place = "Office Tower",
	disaster = "Nuclear Missile",
	icon = "☢️",
	difficulty = "Hard",
	blurb = "Every phone in the office screams at once: missile inbound. You have minutes.",
	start = "start",
	deathNode = "death",
	lesson = "Official guidance after a nuclear alert: Get Inside, Stay Inside, Stay Tuned.",
	nodes = {
		start = {
			fx = "calm",
			text = "Tuesday, 10:14 a.m. Your office floor is full of keyboards clicking until every phone in the building shrieks at the same moment. The screen reads: BALLISTIC MISSILE THREAT INBOUND. SEEK IMMEDIATE SHELTER. THIS IS NOT A DRILL.\n\nPeople freeze, then split. Someone is shouting that it is a mistake. Someone else is already running for the doors.",
			choices = {
				{ text = "Check the news first. It might be a false alarm.", next = "doubt", effects = { calm = -5 } },
				{ text = "Head to the lower floors and basement right now.", next = "shelter_choice", effects = { calm = -5 } },
				{ text = "Run to your car. You need to get home to your family.", next = "car", effects = { calm = -10 } },
				{ text = "Go to the window to look for the missile.", next = "window", effects = { calm = -5 } },
			},
		},

		doubt = {
			fx = "calm",
			text = "The radio on the break room shelf confirms it: a real attack, a real warning. You lost two minutes you might not have. Every second counts now.",
			choices = {
				{ text = "Go to the basement. Now.", next = "shelter_choice", effects = { calm = -10 } },
			},
		},

		car = {
			fx = "dark",
			text = "The car park is chaos. The street outside is a solid wall of brake lights and horns. Nobody is going anywhere. A car window is a thin barrier against blast and radiation.",
			choices = {
				{ text = "Abandon the car and run back inside to shelter.", next = "shelter_choice", effects = { calm = -15, health = -10 } },
				{ text = "Stay in the car and hope the traffic clears.", next = "death", effects = { health = -100 }, note = "A car offers almost no protection." },
				{ text = "Run for the highway on foot.", next = "death", effects = { health = -100 }, note = "There is not enough time." },
			},
		},

		window = {
			fx = "dark",
			text = "You press your face to the glass. For a second you see nothing: the grey sky, the city. Then a light brighter than the sun swallows the horizon. Your eyes burn. The window shatters inward.",
			choices = {
				{ text = "Drop to the floor and crawl for the stairs.", next = "shelter_choice", effects = { health = -35, calm = -25 }, note = "You are blinded and cut by glass, but alive." },
			},
		},

		shelter_choice = {
			fx = "dark",
			text = "The stairwell echoes with feet. At the basement level, a heavy door stands open onto an underground car park. Two options: a concrete utility room deep in the building, or the open car park with its thin walls.\n\nIn the corridor, Mira from accounting is paralysed with fear, hands over her face.",
			choices = {
				{ text = "Take Mira's hand and bring her with you to the utility room.", next = "basement", effects = { calm = -5, set = { "helped_mira" } }, note = "Mira gives a small nod and follows." },
				{ text = "Go straight to the utility room.", next = "basement" },
				{ text = "Stay in the car park, close to the exit.", next = "death", effects = { health = -100 }, note = "The car park is too exposed." },
			},
		},

		basement = {
			fx = "dark",
			text = "The utility room is windowless and thick-walled. Pipes drip. You pull the door shut as the first tremor rolls through the building. Concrete dust trickles from the ceiling. Then a deep, endless roar, and the whole structure shudders.\n\nWhen it stops, the lights flicker out. In the dark you can hear your own breathing, and Mira's.",
			choices = {
				{ text = "Feel around the shelves for supplies.", next = "post_blast", effects = { give = { "radio" }, calm = 5 }, note = "Behind a box you find a battery radio." },
				{ text = "Sit tight and conserve energy.", next = "post_blast", effects = { calm = 5 } },
			},
		},

		post_blast = {
			fx = "dark",
			text = "Hours pass. The building groans but holds. Your head is ringing. Someone above is pounding on a pipe, an echo of something terrible. The dust is thick.\n\nThe urge to go up and look is almost unbearable.",
			choices = {
				{ text = "Stay inside. Wait for official word.", next = "wait", effects = { calm = -5 } },
				{ text = "Go upstairs to see what happened.", next = "outside", effects = { calm = -10 } },
			},
		},

		outside = {
			fx = "dark",
			text = "On the ground floor, the lobby is wrecked and a fine grey ash drifts through the broken doors. The sky is dim. You breathe in a mouthful of dust and cough hard. You realise the mistake: that air is not safe. Radioactive fallout is most dangerous in the first hours.",
			choices = {
				{ text = "Retreat to the basement and seal the door.", next = "wait", effects = { health = -25, calm = -15 }, note = "You will have to deal with the dust on your clothes." },
				{ text = "Walk out to find help.", next = "death", effects = { health = -100 }, note = "Fallout is lethal in the open." },
			},
		},

		wait = {
			fx = "dark",
			text = "Twelve hours in. Your mouth is dry. Without the battery radio, you would not have heard the emergency broadcast. With it, a calm voice repeats: \"Stay inside. Do not leave your shelter for at least 24 hours. Remove outer clothing. Wash exposed skin.\"",
			choices = {
				{ text = "Tune the radio and follow the instructions.", next = "decon", requires = { items = { "radio" } }, hiddenIfLocked = true, effects = { calm = 15 } },
				{ text = "Drink from your water bottle and wait.", next = "decon", requires = { items = { "water" } }, hiddenIfLocked = true, effects = { calm = 10 } },
				{ text = "Wait without any news.", next = "decon", effects = { health = -15, calm = -15 } },
			},
		},

		decon = {
			fx = "calm",
			text = "At the 24-hour mark, a faint voice on the radio, or just your own sense, says it is time. Rescue teams are sweeping the district. Dust still clings to your clothes and hair. Mira, if she is with you, is shivering.",
			choices = {
				{ text = "Remove your outer clothes, bag them, and wash off in the sink.", next = "rescue", effects = { calm = 10 }, note = "You wash your hair and face thoroughly." },
				{ text = "Leave everything as it is and walk out.", next = "rescue_sick", effects = { health = -40, calm = -10 } },
			},
		},

		rescue = {
			fx = "calm",
			text = "A team in protective suits finds you and checks you with a handheld detector. \"Clean,\" one of them says. \"You did everything right.\"",
			choices = {
				{ text = "Lead the others from the building to the evacuation point.", next = "hero_ending", requires = { flags = { "helped_mira" } }, hiddenIfLocked = true },
				{ text = "Follow the rescue team out.", next = "survived_ending" },
			},
		},

		rescue_sick = {
			fx = "calm",
			text = "The suited team finds you before you reach the street. Your clothes are still thick with dust. They hose you down, bag your clothes, and take you to a treatment centre. You will have weeks of treatment ahead, but you will live.",
			ending = { kind = "survived", title = "Weeks of Treatment" },
			lesson = "Removing outer clothing and washing can remove most radioactive dust. Do it as soon as it is safe.",
		},

		hero_ending = {
			fx = "calm",
			text = "You and Mira lead six others from the building, calling out for stragglers on the way. At the evacuation centre, the medic asks how you knew to stay in the basement. \"Get inside, stay inside, stay tuned,\" you say. \"Then help whoever you can.\"",
			ending = { kind = "hero", title = "Stay Tuned" },
			lesson = "Bringing others to shelter, and sharing the right information, saves more lives than acting alone.",
		},

		survived_ending = {
			fx = "calm",
			text = "You step out into a world turned grey. The wind carries the smell of smoke and wet concrete. The rescuers load you onto a truck with a hundred other survivors. You will never take an ordinary Tuesday for granted again.",
			ending = { kind = "survived", title = "The Quiet Morning" },
			lesson = "Shelter immediately and stay there for at least 24 hours unless authorities say otherwise.",
		},

		death = {
			fx = "dark",
			text = "There was never going to be enough time. A few minutes, and one wrong turn, made all the difference. Cities will rebuild, but you are not there to see it.",
			ending = { kind = "died", title = "Too Late" },
			lesson = "Civil-defence advice is blunt for a reason: get inside the nearest sturdy building immediately, move away from windows, and do not go outside until told it is safe.",
		},
	},
}
