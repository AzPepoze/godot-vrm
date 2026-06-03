# Contributing

Thank you for contributing!

## Workflow
1. Fork from the `dev` branch.
2. Submit your Pull Request targeting the `dev` branch.

## Prerequisites

To build and test the project, ensure you have the following installed:
- **C++ Compiler** (GCC, Clang, or MSVC)
- **`make`** and **[`scons`](https://scons.org/)** (for the build system)
- **[`clang-format`](https://clang.llvm.org/docs/ClangFormat.html)** (for C++ formatting and linting)
- **[`gdtoolkit`](https://github.com/Scony/godot-gdscript-toolkit)** (provides `gdformat` and `gdlint` for GDScript)
- **[Godot 4.3+](https://godotengine.org/)** (must be available in your PATH as `godot` for testing)

**Initialize submodules:**
Before building, make sure to fetch the required Git submodules (like godot-cpp):
```bash
git submodule update --init --recursive
```

## Building & Testing

We use a `Makefile` to automate builds and testing.

| Command | Description |
|---------|-------------|
| `make build-linux` | Compiles the C++ GDExtension for Linux (debug). |
| `make build-windows` | Compiles the C++ GDExtension for Windows (debug). |
| `make build-macos` | Compiles the C++ GDExtension for macOS (debug). |
| `make build` | Alias for `make build-linux`. |
| `make test` | Runs the GDScript test suite headlessly in Godot. |
| `make format` | Formats all C++ and GDScript files. |
| `make lint` | Runs the linter to check for formatting and code issues. |
| `make check` | Runs format, lint, build-linux, and test sequentially. |
| `make clean` | Removes all compiled binaries and object files. |

**To test your changes locally:** 
1. Run `make build` to compile the C++ backend.
2. Either run `make test` or open the project folder directly in Godot 4.3+.

> [!WARNING]
> The test suite is currently AI-generated. Be aware that it may not be perfectly accurate and can occasionally produce false positives. Evaluate test failures carefully.

## Folder Structure

- `src/` - C++ GDExtension source code for high-performance physics.
- `addons/` - GDScript and plugin assets for Godot.
  - `addons/vrm/` - Core VRM importer, exporter, and UI scripts.
  - `addons/mtoon/` - Standalone MToon shader implementation.

## Guidelines
- Keep PRs focused.
- Run `make check` before committing to ensure everything works properly.
