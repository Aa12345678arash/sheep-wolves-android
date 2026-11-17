extends SceneTree

const ChainTimer = preload("res://scripts/chain_capture_timer.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = ChainTimer.advance(3.0, 2.5)
	assert(not bool(first.expired), "The 3-second chain window must remain open after 2.5 seconds")
	assert(is_equal_approx(float(first.remaining_seconds), 0.5))

	var second: Dictionary = ChainTimer.advance(float(first.remaining_seconds), 0.499)
	assert(not bool(second.expired), "The chain window must not expire before the full 3 seconds")
	assert(is_equal_approx(float(second.remaining_seconds), 0.001))

	var final: Dictionary = ChainTimer.advance(float(second.remaining_seconds), 0.001)
	assert(bool(final.expired), "The chain window must expire at the 3-second boundary")
	assert(is_zero_approx(float(final.remaining_seconds)))

	var idle: Dictionary = ChainTimer.advance(0.0, 10.0)
	assert(not bool(idle.expired), "An inactive timer must not create a chain-expiry event")
	assert(is_zero_approx(float(idle.remaining_seconds)))

	var negative_delta: Dictionary = ChainTimer.advance(1.0, -2.0)
	assert(not bool(negative_delta.expired), "A negative frame delta must not consume the timer")
	assert(is_equal_approx(float(negative_delta.remaining_seconds), 1.0))

	print("WOLF-DUSK-060 chain timer contract passed: 3.0 seconds, no early expiry, exact-boundary expiry, idle and negative-delta safety.")
	quit()
