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
