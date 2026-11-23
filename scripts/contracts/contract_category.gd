class_name ContractCategory
extends RefCounted
## Category ids used by contract data. Always use these constants.

const FILE_RECOVERY: String = "file_recovery"
const SECURITY_AUDIT: String = "security_audit"
const MALWARE_INVESTIGATION: String = "malware_investigation"
const NETWORK_ANALYSIS: String = "network_analysis"
const SOFTWARE_DEBUGGING: String = "software_debugging"
const CRYPTOGRAPHY: String = "cryptography"
const INCIDENT_INVESTIGATION: String = "incident_investigation"

const ALL: PackedStringArray = [
	FILE_RECOVERY, SECURITY_AUDIT, MALWARE_INVESTIGATION, NETWORK_ANALYSIS,
	SOFTWARE_DEBUGGING, CRYPTOGRAPHY, INCIDENT_INVESTIGATION,
]

const DISPLAY_NAMES: Dictionary = {
	FILE_RECOVERY: "File Recovery",
	SECURITY_AUDIT: "Security Audit",
	MALWARE_INVESTIGATION: "Malware Investigation",
	NETWORK_ANALYSIS: "Network Analysis",
	SOFTWARE_DEBUGGING: "Software Debugging",
	CRYPTOGRAPHY: "Cryptography",
	INCIDENT_INVESTIGATION: "Incident Investigation",
}


static func is_valid(category: String) -> bool:
	return ALL.has(category)


static func get_display_name(category: String) -> String:
	return DISPLAY_NAMES.get(category, category.capitalize())
