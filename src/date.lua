--- Converts a UTC timestamp to local time
--- @param ts string
--- @return string
function toLocalTime(ts)
	return date("%Y-%m-%d %H:%M:%S", ts)
end
