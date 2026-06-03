#!/usr/bin/env python

import os

env = SConscript("godot-cpp/SConstruct")

env.Append(CPPPATH=[
    "src/",
    "src/constraints",
    "src/spring_bone/core",
    "src/spring_bone/godot",
    "src/spring_bone/editor",
])
sources = []
for root, _, files in os.walk("src"):
    for file_name in files:
        if file_name.endswith(".cpp"):
            sources.append(os.path.join(root, file_name))

if env["platform"] == "macos":
    library = env.SharedLibrary(
        "addons/vrm/bin/libvrm_physics.{}.{}.framework/libvrm_physics.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
elif env["platform"] == "ios":
    if env["ios_simulator"]:
        library = env.StaticLibrary(
            "addons/vrm/bin/libvrm_physics.{}.{}.simulator.a".format(env["platform"], env["target"]),
            source=sources,
        )
    else:
        library = env.StaticLibrary(
            "addons/vrm/bin/libvrm_physics.{}.{}.a".format(env["platform"], env["target"]),
            source=sources,
        )
else:
    library = env.SharedLibrary(
        "addons/vrm/bin/libvrm_physics{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

env.NoCache(library)
Default(library)
