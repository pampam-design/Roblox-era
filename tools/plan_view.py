#!/usr/bin/env python3
"""Top-down floor plan of a world's geometry, markers and spawn spots.
Runs the real World.build with stubbed Roblox types. Usage: plan_view.py Classroom out.png"""
import sys, pathlib
from lupa import LuaRuntime
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

name, out = sys.argv[1], sys.argv[2]
root = pathlib.Path(__file__).resolve().parent.parent
lua = LuaRuntime(unpack_returned_tuples=True)
world = lua.eval("""function(src, n, parts)
  local any; any = setmetatable({}, {__index = function() return any end, __call = function() return any end})
  local V = {new = function(x, y, z) return {x = x, y = y, z = z} end}
  local env = setmetatable({game = {GetService = function() return any end}, Color3 = {fromRGB = function(r,g,b) return {r,g,b} end}, Enum = any, Vector3 = V, CFrame = any, Instance = {new = function() return any end}}, {__index = _G})
  return assert(load(src, n, "t", env))()
end""")((root / "src/server/Worlds" / f"{name}.lua").read_text(), name, None)
boxes = []
def part(d):
    boxes.append(d); return lua.eval("setmetatable({}, {__index=function() return nil end, __newindex=function() end})")
lua.eval("function(w, part) w.build({}, {}, part) end")(world, part)

fig, ax = plt.subplots(figsize=(15, 8))
for d in boxes:
    x, z, sx, sz, y, sy = d["pos"].x, d["pos"].z, d["size"].x, d["size"].z, d["pos"].y, d["size"].y
    c = d["color"]; col = (c[1] / 255, c[2] / 255, c[3] / 255) if c else (.8, .8, .8)
    nm = d["name"] or ""
    if nm.startswith(("Ceiling", "Lamp", "Windows")): continue
    low = nm in ("ClassFloor", "CorridorFloor", "Field")
    ax.add_patch(Rectangle((x - sx / 2, z - sz / 2), sx, sz, fc=col, ec="k" if not low else "none", lw=.4, alpha=.5 if low else .95, zorder=1 if low else 2))
for m, pos in world.markers.items():
    x, z = pos[1], pos[2]
    ax.plot(x, z, "o", c="gold", mec="k", ms=9, zorder=5); ax.annotate(world.labels[m], (x, z), (x + .6, z + 1.2), fontsize=7, zorder=6)
for s, pos in world.spots.items():
    x, z = pos[1], pos[2]
    ax.plot(x, z, "s", c="deepskyblue", mec="k", ms=8, zorder=5); ax.annotate("spawn:" + s, (x, z), (x + .6, z - 1.8), fontsize=7, color="navy", zorder=6)
ax.set_aspect("equal"); ax.invert_yaxis(); ax.set_xlim(-25, 135); ax.set_ylim(58, -20)
ax.set_title(f"{name}: top-down plan (yellow = action markers, blue = spawn spots)")
fig.savefig(out, dpi=110, bbox_inches="tight")
print("wrote", out)
