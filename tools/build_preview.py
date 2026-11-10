#!/usr/bin/env python3
"""Builds preview/index.html: a browser mock of the game that plays the real
scenario files (same rules as Engine.lua). For previewing the story only; the
real UI is src/client/Main.client.lua."""
import json, pathlib
from lupa import LuaRuntime, lua_type

root = pathlib.Path(__file__).resolve().parent.parent
lua = LuaRuntime(unpack_returned_tuples=True)
load = lua.eval("function(src,n) return assert(load(src,n))() end")

def conv(o):
    if lua_type(o) == "table":
        keys = list(o.keys())
        if keys and all(isinstance(k, int) for k in keys):
            return [conv(o[k]) for k in sorted(keys)]
        return {k: conv(v) for k, v in o.items()}
    return o

names = ["Classroom", "Subway", "Wildfire", "Tsunami", "Zombies", "Nuclear"]
data = [conv(load((root / "src/shared/Scenarios" / f"{n}.lua").read_text(), n)) for n in names]
tpl = (root / "tools/preview_template.html").read_text()
out = root / "preview"; out.mkdir(exist_ok=True)
(out / "index.html").write_text(tpl.replace("__DATA__", json.dumps(data)))
print("wrote", out / "index.html")
