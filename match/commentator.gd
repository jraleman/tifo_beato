extends RefCounted

## Captions only: telegraphs win, and a line never repeats within a match.

const LINES := {
	"perfect": ["A clap. Somewhere, a poet weeps.", "One bucket. An entire philosophy."],
	"combo": ["The scarves have formed a weather system.", "The terrace has found its heartbeat."],
	"death": ["The chant has died. Kevin checks his watch."],
	"rally": ["Four beats. A resurrection in work boots."],
	"tifo": ["Every fan a pixel. Every pixel a promise.", "Paint has become destiny."],
	"goal_home": ["The ball listened to the bucket.", "Somewhere, a keeper writes a sonnet."],
	"goal_away": ["The scoreboard asks a question. The curva must answer."],
	"keeper": ["His knees have discovered percussion."],
	"chaos": ["The terrace has negotiated with chaos."],
	"war": ["A scarf salute. Honour survives the biscuit tin."],
	"walkout": ["They have gone to the pie stand. The pies are not singing."],
}
var used: Array[String] = []
var last_time := -100.0
var cooldown := 6.0
var enabled := true

func line(event: String, time: float, telegraph := false) -> String:
	if not enabled or telegraph or time - last_time < cooldown:
		return ""
	var bank: Array = LINES.get(event, [])
	for text: String in bank:
		if text not in used:
			used.append(text)
			last_time = time
			return text
	return ""

func verdict(accuracy: float, deaths: int, walkout: bool) -> String:
	if walkout:
		return "The pies won. The bucket requests a rematch."
	if deaths > 0:
		return "It stumbled. It rose. Kevin brought the scarf home."
	return "An empire built from two spoons." if accuracy >= 0.85 \
		else "Eleven people believed. That is how it starts."
