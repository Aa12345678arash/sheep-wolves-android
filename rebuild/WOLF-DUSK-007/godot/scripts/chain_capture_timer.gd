extends RefCounted
class_name WolfDuskChainTimer

# Pure timer arithmetic shared by the live meadow loop and deterministic tests.
# A zero/negative timer is idle; only a positive timer can expire a chain window.
static func advance(remaining_seconds: float, delta: float) -> Dictionary:
	if remaining_seconds <= 0.0:
		return {"remaining_seconds": 0.0, "expired": false}
	var safe_delta := maxf(0.0, delta)
	var next_remaining := maxf(0.0, remaining_seconds - safe_delta)
	return {"remaining_seconds": next_remaining, "expired": next_remaining <= 0.0}
