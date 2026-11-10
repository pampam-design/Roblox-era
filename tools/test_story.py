#!/usr/bin/env python3
"""Validates every scenario and fuzz-plays it with the real Lua engine.

Usage: pip install lupa && python3 tools/test_story.py
"""
import pathlib, random, sys
from lupa import LuaRuntime

root = pathlib.Path(__file__).resolve().parent.parent / "src" / "shared"
lua = LuaRuntime(unpack_returned_tuples=True)
load = lambda p: lua.execute("return function(src, name) return assert(loadstring and loadstring(src, name) or load(src, name))() end")(p.read_text(), p.name)

Engine = load(root / "Engine.lua")
names = ["Classroom", "Subway", "Wildfire", "Tsunami"]
scenarios = [load(root / "Scenarios" / f"{n}.lua") for n in names]

init = (root / "Scenarios" / "init.lua").read_text()
for n in names:
    assert f"script.{n}" in init, f"{n} missing from Scenarios/init.lua"

failed = False
for sc in scenarios:
    problems = list(Engine.validate(sc).values())
    for p in problems:
        print("PROBLEM", p); failed = True

    endings = {}
    rng = random.Random(1)
    for _ in range(20000):
        st = Engine.new(sc)
        for _step in range(200):
            v = Engine.view(sc, st)
            if v.ending:
                endings[v.nodeId] = v.ending.kind
                break
            opts = [c for c in v.choices.values() if not c.locked]
            if not opts:
                print("DEAD END (all locked)", sc.id, v.nodeId); failed = True; break
            c = rng.choice(opts)
            res = Engine.choose(sc, st, c.index, lambda: rng.random())
            if res is not True:
                print("choose failed", sc.id, v.nodeId, res); failed = True; break
        else:
            print("RUNAWAY (no ending in 200 steps)", sc.id); failed = True
    kinds = sorted(set(endings.values()))
    total = sum(1 for n in sc.nodes.values() if n.ending)
    print(f"{sc.id:10s} nodes={len(list(sc.nodes.keys())):3d} endings reached {len(endings)}/{total} kinds={kinds}")
    missing = [k for k, n in sc.nodes.items() if n.ending and k not in endings]
    if missing:
        print("  never reached by random play:", missing)
sys.exit(1 if failed else 0)
