extends Node
## Firsthand memory + hash-seeded gossip. Not a hive mind.

var memories: Dictionary = {}

func hear(npc_id: String, fact: String) -> void:
	if not memories.has(npc_id):
		memories[npc_id] = []
	var list: Array = memories[npc_id]
	list.append(fact)
	if list.size() > 8:
		list.pop_front()
	memories[npc_id] = list

func greeting(npc_id: String, archetype: String) -> String:
	var list: Array = memories.get(npc_id, [])
	if list.size() > 0:
		return "I remember: %s" % str(list[list.size() - 1])
	match archetype:
		"barista":
			return "Need something warm before the next door?"
		"archivist":
			return "Layers keep records. People usually do not."
		"authority":
			return "Keep moving. Hidden things stay hidden."
		"lover":
			return "Come back when the apartment is quiet."
		_:
			return "You look like someone who just changed rooms."
