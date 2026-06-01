#!/usr/bin/env python

env = SConscript("godot-cpp/SConstruct")

env.Append(CPPPATH=["src/"])
dsources = Glob("src/*.cpp") + Glob("src/spring_bone/*.cpp") + Glob("src/constraints/*.cpp")

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
