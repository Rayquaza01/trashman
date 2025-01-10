--- Creates a new array with the callback applied to each element
--- @param tbl table
--- @param cb function
function amap(tbl, cb)
	local res = {}

	for i, item in ipairs(tbl) do
		add(res, cb(item, i, tbl))
	end

	return res
end

--- Searches for a term in a table
--- If term is not found, return -1
--- @param tbl table
--- @param term any
--- @return integer
function search(tbl, term)
	for i, item in ipairs(tbl) do
		if item == term then
			return i
		end
	end

	return -1
end
