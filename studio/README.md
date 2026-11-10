# Installing in Roblox Studio (no Rojo)

## Quick way: one paste
1. Open Roblox Studio, create a new **Baseplate** place.
2. **View > Command Bar** (opens a text box at the bottom).
3. Open `install_game.lua`, copy everything, paste it into the Command Bar, press **Enter**.
   It prints `Survive the Disaster installed. Press Play!`
4. Press **Play** (F5).

Re-running the installer replaces `ReplicatedStorage.Shared`,
`ServerScriptService.Server` and `StarterPlayerScripts.Client` (it only touches
those three).

To save endings: Game Settings > Security > enable *Studio Access to API Services*.

## If the paste is too big for the Command Bar
Create the scripts by hand (right-click > Insert Object), name them exactly, and
paste each file's contents:

| Create this | Type | Paste from |
|---|---|---|
| ReplicatedStorage / Shared (Folder) | Folder | |
| Shared / Engine | ModuleScript | src/shared/Engine.lua |
| Shared / Config | ModuleScript | src/shared/Config.lua |
| Shared / Shop | ModuleScript | src/shared/Shop.lua |
| Shared / Scenarios | ModuleScript | src/shared/Scenarios/init.lua |
| Scenarios / Classroom, Subway, Wildfire, Tsunami, Zombies, Nuclear | ModuleScript (children of Scenarios) | src/shared/Scenarios/<Name>.lua |
| ServerScriptService / Server (Folder) | Folder | |
| Server / Main | **Script** | src/server/Main.server.lua |
| Server / Stage | ModuleScript | src/server/Stage.lua |
| Server / Worlds (Folder) / Classroom | ModuleScript | src/server/Worlds/Classroom.lua |
| StarterPlayer / StarterPlayerScripts / Client (Folder) / Main | **LocalScript** | src/client/Main.client.lua |

Regenerate the installer after editing `src/`: `python3 tools/build_studio_installer.py`
