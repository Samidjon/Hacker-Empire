class_name SkillBranch
extends RefCounted
## Skill tree branch ids, in display order.

const PROGRAMMING: String = "programming"
const NETWORKING: String = "networking"
const CYBERSECURITY: String = "cybersecurity"
const CRYPTOGRAPHY: String = "cryptography"
const REVERSE_ENGINEERING: String = "reverse_engineering"
const AI_RESEARCH: String = "ai_research"

const ALL: PackedStringArray = [
	PROGRAMMING, NETWORKING, CYBERSECURITY, CRYPTOGRAPHY, REVERSE_ENGINEERING, AI_RESEARCH,
]

const DISPLAY_NAMES: Dictionary = {
	PROGRAMMING: "Programming",
	NETWORKING: "Networking",
	CYBERSECURITY: "Cybersecurity",
	CRYPTOGRAPHY: "Cryptography",
	REVERSE_ENGINEERING: "Reverse Engineering",
	AI_RESEARCH: "AI Research",
}


static func is_valid(branch: String) -> bool:
	return ALL.has(branch)


static func get_display_name(branch: String) -> String:
	return DISPLAY_NAMES.get(branch, branch.capitalize())
