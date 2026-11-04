extends RefCounted

## A reveal waits for the response, never covering a player's call.

const NAMES := ["", "Scarf wall", "Card mosaic", "The 50-metre banner",
	"Cartoon smoke bursts", "The Unholy Choreo"]
var tier := 0
var pending := false
var max_tier := 1
var streak_needed := 12
var revealed: Array[int] = []
var reveal_left := 0.0

func judge(perfect_streak: int) -> void:
	if not pending and tier < max_tier and perfect_streak >= streak_needed * (tier + 1):
		pending = true

func response() -> int:
	if not pending:
		return 0
	pending = false
	tier += 1
	revealed.append(tier)
	reveal_left = 8.0
	return tier

func advance(dt: float) -> void:
	reveal_left = maxf(0.0, reveal_left - dt)
