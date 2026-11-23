extends RefCounted
## Discovery codex: every upgrade, fusion, evolution and team-up in the game.
## An entry is "found" once a flight has shown it to the player (offered in a
## draft, formed, or switched on). Found keys live in profile.codex.

const Catalog = preload("res://scripts/catalog.gd")
const TABS := ["Upgrades", "Fusions", "Evolutions", "Team-ups"]

static var _content: Dictionary = {}

static func content() -> Dictionary:
	if _content.is_empty():
		_content = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	return _content

static func _name(id: String) -> String:
	var data := content()
	if data.abilities.has(id):
		return str(data.abilities[id].name)
	for card in data.cards:
		if str(card.id) == id:
			return str(card.name)
	return id.capitalize()

static func _names(ids: Array, joiner: String) -> String:
	return joiner.join(ids.map(func(i): return _name(str(i))))

## Entries for one tab: {key, name, detail, hint}.
static func entries(tab: String) -> Array:
	var data := content()
	var result: Array = []
	match tab:
		"Upgrades":
			for card in data.cards:
				var lines: Array = [str(card.description)]
				if card.has("rank5"):
					lines.append("Rank 5: " + str(card.rank5))
				if card.has("rank10"):
					lines.append("Rank 10: " + str(card.rank10))
				result.append({"key":"card:" + str(card.id), "name":str(card.name), "tag":str(card.tag).capitalize(), "detail":"\n".join(lines), "hint":"Not found yet. Shows up in drafts."})
			for mutation in Catalog.MUTATIONS:
				result.append({"key":"card:" + str(mutation.id), "name":str(mutation.name), "tag":"Mutation", "detail":"%s\nNeeds %s." % [str(mutation.description), _name(str(mutation.requires))], "hint":"Not found yet. A rare draft from World 2."})
		"Fusions":
			for fusion in data.fusions:
				result.append({"key":"fusion:" + str(fusion.id), "name":str(fusion.name), "tag":_names(fusion.parts, " + "), "detail":str(fusion.description), "hint":"Not found yet. Two abilities at rank 5 can fuse."})
		"Evolutions":
			for weapon in data.weapon_evolutions:
				for option in data.weapon_evolutions[weapon]:
					result.append({"key":"evolution:" + str(option.id), "name":str(option.name), "tag":"%s · %s" % [_name(str(weapon)), str(option.role)], "detail":str(option.description), "hint":"Not found yet. %s at rank 5, from World 2." % _name(str(weapon))})
		"Team-ups":
			for link in data.passive_links:
				result.append({"key":"link:" + str(link.id), "name":str(link.name), "tag":_names(link.requires, " + "), "detail":str(link.description), "hint":"Not found yet. Own two matching upgrades."})
			for synergy in data.synergies:
				var pair := "%s + %s" % [_names(synergy.first, " or "), _names(synergy.second, " or ")]
				if bool(synergy.get("any_two", false)):
					pair = "Any two of " + _names(synergy.first + synergy.second, ", ")
				result.append({"key":"synergy:" + str(synergy.id), "name":str(synergy.name).capitalize(), "tag":pair, "detail":str(synergy.description), "hint":"Not found yet. A pair of abilities."})
			for engine in data.get("build_engines", []):
				var third: String = _name(str(engine.third)) if engine.has("third") else _names(engine.get("third_any", []), " or ")
				result.append({"key":"engine:" + str(engine.id), "name":str(engine.name), "tag":"%s + %s + %s" % [_name(str(engine.primary)), _name(str(engine.secondary)), third], "detail":str(engine.description), "hint":"Not found yet. Three matching upgrades, from World 2."})
	return result

static func total() -> int:
	var count := 0
	for tab in TABS:
		count += entries(tab).size()
	return count

static func found_count(profile: Dictionary, tab: String = "") -> int:
	var found: Dictionary = profile.get("codex", {})
	var count := 0
	for name in ([tab] if not tab.is_empty() else TABS):
		for entry in entries(name):
			if found.has(str(entry.key)):
				count += 1
	return count

## Merge what a flight found into the profile. Returns how many are new.
static func record(profile: Dictionary, seen: Dictionary) -> int:
	if not profile.get("codex", {}) is Dictionary:
		profile.codex = {}
	if not profile.has("codex"):
		profile.codex = {}
	var added := 0
	for key in seen:
		if not profile.codex.has(key):
			profile.codex[key] = true
			added += 1
	return added
