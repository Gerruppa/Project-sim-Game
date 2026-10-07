class_name GameCalendar
extends RefCounted
## Time as the player reads it: a year has 12 months of 30 ticks ("Year 29,
## November"). Presentation only: the simulation counts ticks.

const TICKS_PER_YEAR := 360
const TICKS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12
const TICK_PREFIX := "[Tick "


static func year(tick: int) -> int:
	return floori(float(tick) / TICKS_PER_YEAR) + 1


## 0 (first month) to 11.
static func month_index(tick: int) -> int:
	return floori(float(tick % TICKS_PER_YEAR) / TICKS_PER_MONTH)


## "Year 29, November"; months: the 12 names in order.
static func date_text(tick: int, months: PackedStringArray) -> String:
	return "Year %d, %s" % [year(tick), months[month_index(tick)]]


## "5 mo.", "2 y." or "3 y. 3 mo.": a span of ticks in whole months.
static func duration_text(ticks: int) -> String:
	var total := floori(float(ticks) / TICKS_PER_MONTH)
	var years := floori(float(total) / MONTHS_PER_YEAR)
	var rest := total % MONTHS_PER_YEAR
	if years == 0:
		return "%d mo." % rest
	return "%d y." % years if rest == 0 else "%d y. %d mo." % [years, rest]


## "[Tick 10380] text" becomes "Year 29, November: text"; any other line stays.
static func localize_line(line: String, months: PackedStringArray) -> String:
	if not line.begins_with(TICK_PREFIX):
		return line
	var close := line.find("]")
	var number := line.substr(TICK_PREFIX.length(), close - TICK_PREFIX.length())
	if close == -1 or not number.is_valid_int():
		return line
	return "%s:%s" % [date_text(number.to_int(), months), line.substr(close + 1)]
