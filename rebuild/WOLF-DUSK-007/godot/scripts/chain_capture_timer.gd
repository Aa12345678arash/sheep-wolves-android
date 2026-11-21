extends RefCounted
class_name WolfDuskChainTimer

# Pure timer arithmetic shared by the live meadow loop and deterministic tests.
# A zero/negative timer is idle; only a positive timer can expire a chain window.
# A tiny epsilon absorbs floating-point frame-delta drift at the exact deadline.
const EXPIRY_EPSILON_SECONDS := 0.000001

static func advance(remaining_seconds: float, delta: float) -> Dictionary:
	if remaining_seconds <= 0.0:
		return {"remaining_seconds": 0.0, "expired": false}
	var safe_delta := maxf(0.0, delta)
	var raw_remaining := remaining_seconds - safe_delta
	var expired := raw_remaining <= EXPIRY_EPSILON_SECONDS
	var next_remaining := 0.0 if expired else raw_remaining
	return {"remaining_seconds": next_remaining, "expired": expired}
