extends GutHookScript
## GUT post-run hook (post_run_script in .gutconfig.json). GUT fails a test only for errors raised
## in its body. Errors from before_all, before_each, after_each and after_all are tracked under
## GutUtils.NO_TEST and would leave the run green, so this hook fails the run on them. Errors that
## a hook asserts (assert_push_error() and the like) are marked handled and do not count.


func run() -> void:
	var tracker: GutErrorTracker = gut.error_tracker
	if tracker.should_test_fail_from_errors(GutUtils.NO_TEST):
		gut.logger.failed(
			str(
				"Unexpected errors outside test bodies (before_all, before_each, after_each",
				" or after_all):\n",
				tracker.get_fail_text_for_errors(GutUtils.NO_TEST)
			)
		)
		set_exit_code(1)
