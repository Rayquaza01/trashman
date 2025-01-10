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

--- Checks if a table includes an item
--- @param tbl table
--- @param term any
--- @return boolean
function includes(tbl, term)
	for i, item in ipairs(tbl) do
		if item == term then
			return true
		end
	end

	return false
end
