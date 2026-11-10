--!nocheck
-- Scenario: earthquake during a maths lesson.
return {
	id = "classroom",
	title = "Shaking Ground",
	place = "Classroom",
	disaster = "Earthquake",
	icon = "🏫",
	difficulty = "Easy",
	blurb = "Second floor, Room 204. Period 3 maths. The floor starts to move.",
	world = "Classroom", -- 3D stage in src/server/Worlds/Classroom.lua
	start = "start",
	deathNode = "death",
	lesson = "In an earthquake: Drop, Cover, and Hold On. Stay put until the shaking stops.",
	nodes = {
		start = {
			fx = "calm",
			text = "Period 3, Room 204. Ms. Okafor is mid-sentence about quadratic equations when your pencil rolls off the desk. Then the lights sway. A low rumble rises through the floor and the windows begin to rattle.\n\n\"Is that a truck?\" someone whispers. Then the whole room lurches sideways.",
			choices = {
				{ text = "Drop under your desk, grab a leg and hold on.", next = "under_desk", hold = 3, effects = { calm = -5 } },
				{ text = "Sprint for the door before the roof comes down.", next = "run_door", effects = { health = -25, calm = -20 }, note = "You get knocked into the doorframe by the stampede." },
				{ text = "Stand in the doorway. You heard that's the safest spot.", next = "doorway", effects = { health = -15, calm = -10 }, note = "The door slams back and forth, hitting your shoulder." },
			},
		},

		under_desk = {
			fx = "quake",
			text = "Under the desk you can hear everything: books hitting the floor, a ceiling tile cracking, someone screaming. The desk skids across the room but you hold on tight.\n\nAcross the aisle, Jay is standing frozen with his hands over his ears. A light fixture swings above his head.",
			choices = {
				{ text = "Reach out and pull Jay under your desk.", next = "shaking_stops", effects = { health = -10, calm = -10 }, note = "A ceiling tile clips your arm, but Jay is under cover." },
				{ text = "Shout at Jay to get down, but stay put.", next = "shaking_stops", chance = { p = 0.5, win = "shaking_stops", lose = "shaking_stops", loseEffects = { calm = -15 }, winNote = "Jay snaps out of it and ducks under his own desk just in time.", loseNote = "Jay does not move. You watch the fixture fall near him and it is hard to look away." } },
				{ text = "Hold on and keep your head down. Survive first.", next = "shaking_stops", hold = 3, effects = { calm = -10 } },
			},
		},

		run_door = {
			fx = "quake",
			text = "You make it three steps before the floor throws you against a bookcase. The corridor is full of kids pushing the same way. Something heavy lands near your feet. Dust fills the air.\n\nThe shaking is easing off. Your ears are ringing.",
			choices = {
				{ text = "Crawl back into the classroom and get under a desk.", next = "shaking_stops", effects = { health = -5 } },
				{ text = "Keep pushing toward the stairwell.", next = "hallway_crush" },
			},
		},

		doorway = {
			fx = "quake",
			text = "You brace in the doorway. Modern doorframes are no stronger than the rest of the building, and the door keeps swinging. You get pinned for a moment, then freed when a classmate drags you down to the floor.\n\n\"Get DOWN!\" she yells. Shortly after, the shaking stops.",
			choices = {
				{ text = "Check yourself over, then look around the room.", next = "shaking_stops" },
			},
		},

		hallway_crush = {
			fx = "dark",
			text = "The stairwell door is jammed with people. Someone trips and the crowd surges. You are pinned against the wall, struggling to breathe, until a teacher's voice cuts through: \"STOP PUSHING. Everyone step back!\"",
			choices = {
				{ text = "Step back and help calm the people around you.", next = "shaking_stops", effects = { calm = 10, health = -5 }, note = "The crowd loosens a little. People can breathe again." },
				{ text = "Climb over the pile to get out first.", next = "death", effects = { health = -80 }, note = "You fall into the crush." },
			},
		},

		shaking_stops = {
			fx = "calm",
			text = "Silence. Then coughing, crying, a phone buzzing somewhere. The shaking has stopped. The lights are out, the fire alarm is howling, and dust hangs in the air.\n\nMs. Okafor stands by the whiteboard, pale but steady. \"Everyone listen. We are going to leave the building calmly. Take one thing each, but nothing heavy. Go.\"",
			choices = {
				{ text = "Grab the first-aid kit from the wall.", next = "corridor", effects = { give = { "first-aid kit" } } },
				{ text = "Grab your backpack: it has a torch and a water bottle.", next = "corridor", effects = { give = { "torch", "water" } } },
				{ text = "Take nothing and head for the door right now.", next = "corridor", effects = { calm = 5 } },
			},
		},

		corridor = {
			fx = "dark",
			text = "The corridor is half-dark and littered with ceiling tiles and glass. At one end the stairwell is blocked by a collapsed wall. At the other end, a back staircase is open but the emergency lighting is out. The lift is right in front of you with its call button still glowing.\n\nMs. Okafor is leading the main group toward the blocked stairs, hoping to clear a path.",
			choices = {
				{ text = "Take the lift. It's fastest and the button is lit.", next = "lift", chance = { p = 0.35, win = "outside_safe", lose = "lift_stuck" }, note = "You press the button..." },
				{ text = "Use the dark back stairs.", next = "back_stairs", requires = { items = { "torch" } }, effects = { calm = 5 }, note = "Your torch beam cuts through the dark." },
				{ text = "Feel your way down the back stairs without light.", next = "back_stairs_dark" },
				{ text = "Stay with the teacher's group at the blocked stairs.", next = "aftershock" },
			},
		},

		lift_stuck = {
			fx = "dark",
			text = "The lift jolts, drops half a floor, and stops dead. The lights go out. You are trapped in a metal box between floors with no signal. An aftershock rattles the cables. It takes rescue crews six hours to get you out.",
			ending = { kind = "survived", title = "Stuck Between Floors" },
			lesson = "Never use lifts during or after an earthquake. Power failures and aftershocks can trap you, and cables can be damaged.",
		},

		back_stairs = {
			fx = "dark",
			text = "With the torch you spot a gap where the staircase has pulled away from the wall, and you step carefully around it. Halfway down you hear shouting from the blocked group above.",
			choices = {
				{ text = "Go back up and guide them to the back stairs.", next = "rescue_group", effects = { calm = -10 } },
				{ text = "Keep going. Get outside and tell the rescuers.", next = "outside_safe" },
			},
		},

		back_stairs_dark = {
			fx = "dark",
			text = "You grip the rail and take it one step at a time. On the third landing, your foot finds a gap where the stairs have shifted. You stumble and wrench your ankle, but catch the rail.",
			choices = {
				{ text = "Grit your teeth and keep going.", next = "outside_safe", hold = 2.5, effects = { health = -20 }, note = "Your ankle throbs, but you make it down." },
				{ text = "Sit and wait for help.", next = "aftershock" },
			},
		},

		aftershock = {
			fx = "quake",
			text = "Twenty minutes later, an aftershock hits. Plaster rains down in the corridor. The group at the blocked stairs scatters.",
			choices = {
				{ text = "Drop, cover, and hold on right where you are.", next = "outside_safe", hold = 4, effects = { calm = -5 } },
				{ text = "Run toward the back stairs.", next = "outside_safe", chance = { p = 0.5, win = "outside_safe", lose = "death", loseEffects = { health = -60 } }, note = "Running during shaking is risky..." },
			},
		},

		rescue_group = {
			fx = "calm",
			text = "You climb back up and shout through the gap. \"The back stairs are open! Use my torch, come this way!\" Fifteen students and Ms. Okafor file past you in the dark. One of them is the kid who was too scared to move.",
			choices = {
				{ text = "Lead them down and out to the football field.", next = "hero_ending" },
			},
		},

		hero_ending = {
			fx = "calm",
			text = "On the field, teachers take a head count. When your name is called, Ms. Okafor squeezes your shoulder. \"You made sure everyone got out.\"\n\nYour class gets a new meeting point and a new fire drill, and you are the one who explains it to the Year 7s.",
			ending = { kind = "hero", title = "The Class Remembers" },
			lesson = "Calm leadership saves lives. In an emergency, helping others get out safely is the best use of what you know.",
		},

		outside_safe = {
			fx = "calm",
			text = "You step out into the cold air of the field. Sirens are far off. Teachers are counting heads. Power lines hang from a pole near the gate, so everyone is waved away from them.\n\nYou are safe. Your hands do not stop shaking for a long time.",
			ending = { kind = "survived", title = "On the Field" },
			lesson = "After the shaking stops: check for injuries, leave via stairs, stay clear of damaged buildings and power lines, and expect aftershocks.",
		},

		death = {
			fx = "dark",
			text = "The ceiling, the crowd, or the next aftershock. In the end the building took more than you could handle. Your classmates will never forget this day.",
			ending = { kind = "died", title = "Did Not Make It" },
			lesson = "Most earthquake injuries come from falling objects and panic. Drop, cover, and hold on, and move slowly and calmly afterwards.",
		},
	},
}
