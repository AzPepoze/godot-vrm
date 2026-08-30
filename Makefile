.PHONY: build build-release test clean format lint build-linux build-windows build-macos build-android build-all build-release-all

build: build-linux

build-release: build-release-linux

build-linux:
	scons platform=linux target=template_debug -j$(shell nproc)

build-release-linux:
	scons platform=linux target=template_release -j$(shell nproc)

build-windows:
	-scons platform=windows target=template_debug -j$(shell nproc)

build-release-windows:
	-scons platform=windows target=template_release -j$(shell nproc)

build-macos:
	-scons platform=macos target=template_debug -j$(shell nproc)

build-android:
	-scons platform=android target=template_debug arch=arm64 -j$(shell nproc)

build-release-macos:
	-scons platform=macos target=template_release -j$(shell nproc)

build-release-android:
	-scons platform=android target=template_release arch=arm64 -j$(shell nproc)

build: build-linux build-windows build-macos

release: build-release-linux build-release-windows build-release-macos

test:
	godot --headless -s tests/test_runner.gd

clean:
	find src/ -name "*.o" -o -name "*.os" -o -name "*.obj" | xargs -r rm -f
	rm -rf .sconsign.dblite
	rm -f addons/vrm/bin/libvrm_physics.*

format:
	find src/ -name "*.cpp" -o -name "*.h" | xargs -r clang-format -i
	find addons/ tests/ -name "*.gd" | xargs -r gdformat --use-spaces=4

lint:
	find src/ -name "*.cpp" -o -name "*.h" | xargs -r clang-format --dry-run --Werror
	find addons/ tests/ -name "*.gd" | xargs -r gdformat --check
	gdlint addons/ tests/

check: format lint build-linux test