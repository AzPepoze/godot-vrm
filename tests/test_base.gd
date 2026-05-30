extends RefCounted

var runner = null
var current_test_name: String = ""


func assert_eq(got, expected, msg: String = ""):
	if str(got) != str(expected):
		runner.fail_test(
			current_test_name, "Expected %s, but got %s. %s" % [str(expected), str(got), msg]
		)
	else:
		runner.pass_assertion()


func assert_true(val: bool, msg: String = ""):
	if not val:
		runner.fail_test(current_test_name, "Expected true, but got false. %s" % msg)
	else:
		runner.pass_assertion()


func assert_not_null(val, msg: String = ""):
	if val == null:
		runner.fail_test(current_test_name, "Expected not null. %s" % msg)
	else:
		runner.pass_assertion()


func assert_false(val: bool, msg: String = ""):
	if val:
		runner.fail_test(current_test_name, "Expected false, but got true. %s" % msg)
	else:
		runner.pass_assertion()


func assert_null(val, msg: String = ""):
	if val != null:
		runner.fail_test(current_test_name, "Expected null, got %s. %s" % [str(val), msg])
	else:
		runner.pass_assertion()


func assert_ge(got, expected, msg: String = ""):
	if not (got >= expected):
		runner.fail_test(
			current_test_name, "Expected >= %s, but got %s. %s" % [str(expected), str(got), msg]
		)
	else:
		runner.pass_assertion()


func assert_gt(got, expected, msg: String = ""):
	if not (got > expected):
		runner.fail_test(
			current_test_name, "Expected > %s, but got %s. %s" % [str(expected), str(got), msg]
		)
	else:
		runner.pass_assertion()


func assert_lt(got, expected, msg: String = ""):
	if not (got < expected):
		runner.fail_test(
			current_test_name, "Expected < %s, but got %s. %s" % [str(expected), str(got), msg]
		)
	else:
		runner.pass_assertion()
