extends GutHookScript
## GUT pre-run hook (pre_run_script in .gutconfig.json): the tests keep the save in memory, and
## never read or write the player's save file (M5_PLAN.md L1). Nothing may read the save before
## this hook runs, so an autoload must not ask SaveService for data() in its _ready().


func run() -> void:
	if SaveService.is_loaded():
		gut.logger.failed("The save was read before the tests started: it may be the player's")
		set_exit_code(1)
		abort()
	SaveService.use_memory()
