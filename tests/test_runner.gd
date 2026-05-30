extends SceneTree

var passed_tests = 0
var failed_tests = 0
var assertions_passed = 0
var current_failed = false
var current_error_message = ""


func _init():
	print("=========================================")
	print("Running Godot-VRM Test Suite")
	print("=========================================")

	var dir = DirAccess.open("res://tests")
	if not dir:
		printerr("Failed to open res://tests directory")
		quit(1)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var test_files = []
	while file_name != "":
		if (
			not dir.current_is_dir()
			and file_name.begins_with("test_")
			and file_name.ends_with(".gd")
			and file_name != "test_runner.gd"
			and file_name != "test_base.gd"
		):
			test_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	test_files.sort()

	for file in test_files:
		await run_test_file("res://tests/" + file)

	print("=========================================")
	print("Execution finished.")
	print("Passed tests: %d, Failed tests: %d" % [passed_tests, failed_tests])
	print("Total assertions passed: %d" % assertions_passed)
	print("=========================================")

	if failed_tests > 0:
		quit(1)
	else:
		quit(0)


func run_test_file(path: String):
	print("Running suite: %s" % path.get_file())
	var script = load(path)
	if not script:
		printerr("  [ERROR] Failed to load test script: ", path)
		failed_tests += 1
		return

	var test_obj = script.new()
	test_obj.runner = self

	var methods = test_obj.get_method_list()
	var has_tests = false
	for method in methods:
		var name = method["name"]
		if name.begins_with("test_"):
			has_tests = true
			current_failed = false
			current_error_message = ""
			test_obj.current_test_name = name

			# Run optional setup
			if test_obj.has_method("before_each"):
				await test_obj.before_each()

			await test_obj.call(name)

			# Run optional teardown
			if test_obj.has_method("after_each"):
				await test_obj.after_each()

			if current_failed:
				failed_tests += 1
				print("  [FAIL] %s: %s" % [name, current_error_message])
			else:
				passed_tests += 1
				print("  [PASS] %s" % name)

	if not has_tests:
		print("  [WARN] No test methods starting with 'test_' found.")


func fail_test(_test_name: String, message: String):
	current_failed = true
	current_error_message = message


func pass_assertion():
	assertions_passed += 1


func wait_frame():
	await process_frame
