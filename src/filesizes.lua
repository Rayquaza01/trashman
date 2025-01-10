local prefix = "bi"
local conversions = {
	si = {
		prefixes = {"KB", "MB", "GB"},
		K = 1000,
		M = 1000000, -- 1000^2
		G = 1000000000 -- 1000^3
	},
	bi = {
		prefixes = {"KiB", "MiB", "GiB"},
		K = 1024,
		M = 1048576, -- 1024^2
		G = 1073741824 -- 1024^3
	}
}

--- Converts a number of bytes to a readable size
--- @param sz number
--- @return string
function sizeToReadable(sz)
	if prefix == "" then
		return tostr(sz) .. "B"
	end

	local ctable = prefix == "bi" and conversions.bi or conversions.si

	if sz >= ctable.G then
		return string.format("%.2f%s", sz / ctable.G, ctable.prefixes[3])
	elseif sz >= ctable.M then
		return string.format("%.2f%s", sz / ctable.M, ctable.prefixes[2])
	elseif sz >= ctable.K then
		return string.format("%.2f%s", sz / ctable.K, ctable.prefixes[1])
	end

	return tostr(sz) .. "B"
end
