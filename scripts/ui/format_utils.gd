class_name FormatUtils
extends RefCounted
## Text formatting shared by all UI.


## 1234567 -> "$1,234,567"
static func money(amount: int) -> String:
	var digits: String = str(absi(amount))
	var grouped: String = ""
	var count: int = 0
	for index: int in range(digits.length() - 1, -1, -1):
		grouped = digits[index] + grouped
		count += 1
		if count % 3 == 0 and index > 0:
			grouped = "," + grouped
	return ("-$" if amount < 0 else "$") + grouped


## "+$500" / "-$200"
static func signed_money(amount: int) -> String:
	return ("+" if amount >= 0 else "") + money(amount)


## 3725.0 -> "01:02:05"
static func duration(total_seconds: float) -> String:
	var seconds: int = maxi(0, int(total_seconds))
	@warning_ignore("integer_division")
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds % 3600) / 60, seconds % 60]


## Unix time -> "2026-11-23 14:02" in the system's local time zone.
static func local_timestamp(unix_time: int) -> String:
	if unix_time <= 0:
		return "unknown"
	var bias_minutes: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var text: String = Time.get_datetime_string_from_unix_time(unix_time + bias_minutes * 60, true)
	return text.substr(0, 16)
