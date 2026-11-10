#!/usr/bin/env python3
"""Generates studio/install_game.lua: one script to paste into Roblox Studio's
Command Bar (View > Command Bar). It creates every script in the same places
default.project.json (Rojo) would. No Rojo needed."""
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent
src = root / "src"

def read(rel):
    text = (src / rel).read_text()
    assert "]=====]" not in text, rel
    return text

# (container path, class, name, file)
S = "ReplicatedStorage.Shared"
items = [
    (S, "ModuleScript", "Engine", "shared/Engine.lua"),
    (S, "ModuleScript", "Config", "shared/Config.lua"),
    (S, "ModuleScript", "Shop", "shared/Shop.lua"),
    (S, "ModuleScript", "Scenarios", "shared/Scenarios/init.lua"),
]
for n in ["Classroom", "Subway", "Wildfire", "Tsunami", "Zombies", "Nuclear"]:
    items.append((S + ".Scenarios", "ModuleScript", n, f"shared/Scenarios/{n}.lua"))
items += [
    ("ServerScriptService.Server", "Script", "Main", "server/Main.server.lua"),
    ("ServerScriptService.Server", "ModuleScript", "Stage", "server/Stage.lua"),
    ("ServerScriptService.Server.Worlds", "ModuleScript", "Classroom", "server/Worlds/Classroom.lua"),
    ("StarterPlayer.StarterPlayerScripts.Client", "LocalScript", "Main", "client/Main.client.lua"),
]

out = ['''-- SURVIVE THE DISASTER: one-time installer.
-- In Roblox Studio: View > Command Bar, paste this whole script, press Enter.
-- It (re)creates: ReplicatedStorage.Shared, ServerScriptService.Server and
-- StarterPlayerScripts.Client. Re-running replaces those three folders.
-- Then press Play. (Studio only: Game Settings > Security > "Enable Studio
-- Access to API Services" if you want endings to save.)

local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then return f end
	f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- wipe any previous install
for _, spec in ipairs({
	{ game:GetService("ReplicatedStorage"), "Shared" },
	{ game:GetService("ServerScriptService"), "Server" },
	{ game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"), "Client" },
}) do
	local old = spec[1]:FindFirstChild(spec[2])
	if old then old:Destroy() end
end

local function make(class, name, parent, source)
	local inst = Instance.new(class)
	inst.Name = name
	inst.Source = source
	inst.Parent = parent
	return inst
end

local Lighting = game:GetService("Lighting")
Lighting.ClockTime = 14
Lighting.Brightness = 2

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local Shared = folder(RS, "Shared")
local Server = folder(SSS, "Server")
local Worlds = folder(Server, "Worlds")
local Client = folder(SPS, "Client")
''']

# explicit creation in order (modules first, Scenarios children after Scenarios)
var = {
    "ReplicatedStorage.Shared": "Shared",
    "ServerScriptService.Server": "Server",
    "ServerScriptService.Server.Worlds": "Worlds",
    "StarterPlayer.StarterPlayerScripts.Client": "Client",
}
for path, cls, name, f in items:
    code = read(f)
    if path == S + ".Scenarios":
        parent = "scenarios"
    else:
        parent = var[path]
    out.append(f'{"scenarios = " if name == "Scenarios" else "local _ = "}make("{cls}", "{name}", {parent}, [=====[\n{code}]=====])\n')
    if name == "Scenarios":
        pass
out.append('print("Survive the Disaster installed. Press Play!")\n')
text = "\n".join(out)
# 'scenarios' must be declared before first assignment
text = text.replace("local Client = folder(SPS, \"Client\")\n", "local Client = folder(SPS, \"Client\")\nlocal scenarios\n", 1)
(root / "studio").mkdir(exist_ok=True)
(root / "studio/install_game.lua").write_text(text)
print("wrote studio/install_game.lua", len(text), "bytes")
